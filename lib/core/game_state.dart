import 'models.dart';
import 'board.dart';
import 'rules_engine.dart';
import 'audio_service.dart';

enum GameStatus { playing, whiteWon, blackWon, draw }

class GameState {
  final DynamoBoard board;
  PlayerColor turn;
  GameStatus status;
  List<Position> validMoves;
  Position? selectedPosition;
  
  // History
  final List<MoveRecord> history = [];
  
  // Online Last Move Sync
  Position? lastMoveStart;
  Position? lastMoveEnd;
  
  // Promotion state
  Position? pendingPromotionPos;
  
  // Game Settings (Time Control)
  GameSettings currentSettings = GameSettings.blitz3; // Default

  // Advanced Draw Logic
  final Map<String, int> repetitionHistory = {};
  int fiftyMoveCounter = 0;

  // Timers & State
  Duration whiteTime = const Duration(minutes: 3);
  Duration blackTime = const Duration(minutes: 3);
  String gameResult = "";

  // Castling Rights
  bool whiteCanCastleKingside = true;
  bool whiteCanCastleQueenside = true;
  bool blackCanCastleKingside = true;
  bool blackCanCastleQueenside = true;

  GameState({
    required this.board,
    this.turn = PlayerColor.white,
    this.status = GameStatus.playing,
    this.selectedPosition,
    this.validMoves = const [],
    GameSettings? settings,
  }) {
    if (settings != null) {
      currentSettings = settings;
      whiteTime = settings.timeLimit;
      blackTime = settings.timeLimit;
    }
  }

  void handleSquareTap(Position pos, Function(String) onNotification, Function(Position) onPromotionRequired, {void Function()? onMoveMade}) {
    if (status != GameStatus.playing) return;
    if (pendingPromotionPos != null) return; // Wait for promotion selection

    if (validMoves.contains(pos) && selectedPosition != null) {
      _executeMove(selectedPosition!, pos, onNotification, onPromotionRequired, onMoveMade: onMoveMade);
      return;
    }

    final piece = board.getPiece(pos);
    if (piece != null && piece.color == turn) {
      selectedPosition = pos;
      final canKingside = turn == PlayerColor.white ? whiteCanCastleKingside : blackCanCastleKingside;
      final canQueenside = turn == PlayerColor.white ? whiteCanCastleQueenside : blackCanCastleQueenside;

      MoveRecord? effectiveLastMove;
      if (history.isNotEmpty) {
        effectiveLastMove = history.last;
      } else if (lastMoveStart != null && lastMoveEnd != null) {
        effectiveLastMove = MoveRecord(
          start: lastMoveStart!,
          end: lastMoveEnd!,
          pieceType: board.getPiece(lastMoveEnd!)?.type ?? PieceType.pawn,
          isCapture: false,
        );
      }

      validMoves = RulesEngine.getLegalMoves(
        pos, 
        board, 
        lastMove: effectiveLastMove,
        canCastleKingside: canKingside,
        canCastleQueenside: canQueenside,
      );
    } else {
      selectedPosition = null;
      validMoves = [];
    }
  }

  void _executeMove(Position start, Position end, Function(String) onNotification, Function(Position) onPromotionRequired, {void Function()? onMoveMade}) {
    final piece = board.getPiece(start);
    final target = board.getPiece(end);

    if (piece == null) return;

    // 50-Move Rule & Repetition Logic Updates
    bool isPawnMove = piece.type == PieceType.pawn;
    bool isCapture = target != null;
    
    if (isPawnMove || isCapture) {
      fiftyMoveCounter = 0;
      repetitionHistory.clear();
    } else {
      fiftyMoveCounter++;
    }


    if (isCapture) {
      AudioService().playCapture();
    } else {
      AudioService().playMove();
    }

    // Move piece
    _handleSpecialMoves(start, end, piece, target?.type);
    board.setPiece(end, piece);
    board.setPiece(start, null);

    // Update Castling Rights
    if (piece.type == PieceType.king) {
      if (piece.color == PlayerColor.white) {
        whiteCanCastleKingside = false;
        whiteCanCastleQueenside = false;
      } else {
        blackCanCastleKingside = false;
        blackCanCastleQueenside = false;
      }
    } else if (piece.type == PieceType.rook) {
      if (piece.color == PlayerColor.white) {
        if (start.x == 0 && start.y == 9) whiteCanCastleQueenside = false;
        if (start.x == 9 && start.y == 9) whiteCanCastleKingside = false;
      } else {
        if (start.x == 0 && start.y == 0) blackCanCastleQueenside = false;
        if (start.x == 9 && start.y == 0) blackCanCastleKingside = false;
      }
    }
    
    // If a Rook is captured, the opponent loses castling rights on that side
    if (target?.type == PieceType.rook) {
      if (target?.color == PlayerColor.white) {
        if (end.x == 0 && end.y == 9) whiteCanCastleQueenside = false;
        if (end.x == 9 && end.y == 9) whiteCanCastleKingside = false;
      } else {
        if (end.x == 0 && end.y == 0) blackCanCastleQueenside = false;
        if (end.x == 9 && end.y == 0) blackCanCastleKingside = false;
      }
    }

    // Promotion Check
    if (piece.type == PieceType.pawn) {
      if ((piece.color == PlayerColor.white && end.y == 0) ||
          (piece.color == PlayerColor.black && end.y == 9)) {
        pendingPromotionPos = end;
        onPromotionRequired(end);
        return; // Don't end turn yet
      }
    }

    _finalizeMove(onNotification, onMoveMade: onMoveMade);
  }

  void finalizePromotion(PieceType type) {
    if (pendingPromotionPos == null) return;
    
    final color = board.getPiece(pendingPromotionPos!)?.color ?? turn;
    board.setPiece(pendingPromotionPos!, DynamoPiece(type: type, color: color));
    pendingPromotionPos = null;
    
    _finalizeMove((_) {}, onMoveMade: null);
  }

  void _handleSpecialMoves(Position start, Position end, DynamoPiece piece, PieceType? targetType) {
    if (piece.type == PieceType.king) {
      // Castling detection (King moves 3 squares)
      if ((end.x - start.x).abs() == 3) {
        final isKingside = end.x > start.x;
        final rookStart = Position(isKingside ? 9 : 0, start.y);
        final rookEnd = Position(isKingside ? 7 : 3, start.y);
        
        final rook = board.getPiece(rookStart);
        if (rook != null) {
          board.setPiece(rookEnd, rook);
          board.setPiece(rookStart, null);
        }
      }
    }

    // En-passant capture detection
    PieceType? finalTargetType = targetType;
    if (piece.type == PieceType.pawn) {
      if (start.x != end.x && board.getPiece(end) == null) {
        // In Dynamo en-passant, we remove the pawn that just jumped 2 or 3 squares.
        final lastMove = history.isNotEmpty
            ? history.last
            : (lastMoveStart != null && lastMoveEnd != null
                ? MoveRecord(
                    start: lastMoveStart!,
                    end: lastMoveEnd!,
                    pieceType: PieceType.pawn,
                    isCapture: false,
                  )
                : null);
        if (lastMove != null) {
          finalTargetType = lastMove.pieceType; // It was a pawn
          board.setPiece(lastMove.end, null);
        }
      }
    }

    history.add(MoveRecord(
      start: start,
      end: end,
      pieceType: piece.type,
      isCapture: finalTargetType != null,
      capturedPieceType: finalTargetType,
    ));
  }


  void _finalizeMove(Function(String) onNotification, {void Function()? onMoveMade}) {
    // Apply Increment
    if (turn == PlayerColor.white) {
      whiteTime += currentSettings.increment;
    } else {
      blackTime += currentSettings.increment;
    }

    // Repetition check (after move)
    String fen = board.toFen() + turn.toString();
    repetitionHistory[fen] = (repetitionHistory[fen] ?? 0) + 1;

    turn = (turn == PlayerColor.white) ? PlayerColor.black : PlayerColor.white;
    selectedPosition = null;
    validMoves = [];
    _checkGameOver(onNotification);
    onMoveMade?.call();
  }

  void _checkGameOver(Function(String) onNotification) {
    if (status != GameStatus.playing) return;

    // Check 50-move rule
    if (fiftyMoveCounter >= 100) {
      status = GameStatus.draw;
      gameResult = "Draw by 50-Move Rule!";
      AudioService().playGameOver();
      onNotification(gameResult);
      return;
    }

    // Check 3-fold repetition
    if (repetitionHistory.values.any((count) => count >= 3)) {
      status = GameStatus.draw;
      gameResult = "Draw by Repetition!";
      AudioService().playGameOver();
      onNotification(gameResult);
      return;
    }

    final lastMove = history.isNotEmpty ? history.last : null;
    final inCheck = RulesEngine.isCheck(turn, board);
    
    final canKingside = turn == PlayerColor.white ? whiteCanCastleKingside : blackCanCastleKingside;
    final canQueenside = turn == PlayerColor.white ? whiteCanCastleQueenside : blackCanCastleQueenside;
    
    final hasMoves = RulesEngine.hasLegalMoves(
      turn, 
      board, 
      lastMove: lastMove,
      canCastleKingside: canKingside,
      canCastleQueenside: canQueenside,
    );

    if (!hasMoves) {
      if (inCheck) {
        status = (turn == PlayerColor.white) ? GameStatus.blackWon : GameStatus.whiteWon;
        gameResult = "CHECKMATE! ${turn == PlayerColor.white ? 'Black' : 'White'} wins!";
        AudioService().playGameOver();
        onNotification(gameResult);
      } else {
        status = GameStatus.draw;
        gameResult = "STALEMATE!";
        AudioService().playGameOver();
        onNotification(gameResult);
      }
    } else if (inCheck) {
      AudioService().playCheck();
      onNotification("CHECK!");
    }
  }

  void decrementTime(Duration amount) {
    if (turn == PlayerColor.white) {
      whiteTime -= amount;
      if (whiteTime.isNegative) {
        whiteTime = Duration.zero;
        status = GameStatus.blackWon;
        gameResult = "Black wins on time!";
        AudioService().playGameOver();
      }
    } else {
      blackTime -= amount;
      if (blackTime.isNegative) {
        blackTime = Duration.zero;
        status = GameStatus.whiteWon;
        gameResult = "White wins on time!";
        AudioService().playGameOver();
      }
    }
  }

  void claimDraw() {
    if (status == GameStatus.playing) {
      status = GameStatus.draw;
      gameResult = "Draw Agreement";
    }
  }

  void resign(PlayerColor resigningPlayer) {
    if (status != GameStatus.playing) return;
    
    if (resigningPlayer == PlayerColor.white) {
      status = GameStatus.blackWon;
      gameResult = "White Resigned. Black Wins!";
      AudioService().playGameOver();
    } else {
      status = GameStatus.whiteWon;
      gameResult = "Black Resigned. White Wins!";
      AudioService().playGameOver();
    }
  }

  void reset({GameSettings? newSettings}) {
    board.initializeBoard();
    turn = PlayerColor.white;
    status = GameStatus.playing;
    selectedPosition = null;
    validMoves = [];
    
    if (newSettings != null) {
      currentSettings = newSettings;
    }
    
    whiteTime = currentSettings.timeLimit;
    blackTime = currentSettings.timeLimit;
    
    gameResult = "";
    history.clear();
    repetitionHistory.clear();
    fiftyMoveCounter = 0;
    
    whiteCanCastleKingside = true;
    whiteCanCastleQueenside = true;
    blackCanCastleKingside = true;
    blackCanCastleQueenside = true;
  }
}
