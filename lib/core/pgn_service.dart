import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'board.dart';
import 'rules_engine.dart';
import 'fen_converter.dart';

class PgnService {
  /// Converts a single move into Dynamo Chess algebraic notation (fallback without board context)
  static String moveToString(MoveRecord move) {
    if (move.pieceType == PieceType.king && (move.end.x - move.start.x).abs() >= 2) {
      return move.end.x > move.start.x ? "0-0" : "0-0-0";
    }

    final endFile = String.fromCharCode(97 + move.end.x);
    final endRank = 10 - move.end.y;

    String piecePrefix = _getPiecePrefix(move.pieceType);

    if (move.isCapture) {
      if (move.pieceType == PieceType.pawn) {
        final startFile = String.fromCharCode(97 + move.start.x);
        return "${startFile}x$endFile$endRank";
      } else {
        return "${piecePrefix}x$endFile$endRank";
      }
    } else {
      return "$piecePrefix$endFile$endRank";
    }
  }

  static String _getPiecePrefix(PieceType type) {
    switch (type) {
      case PieceType.king:
        return 'K';
      case PieceType.queen:
        return 'Q';
      case PieceType.missile:
        return 'M';
      case PieceType.rook:
        return 'R';
      case PieceType.bishop:
        return 'B';
      case PieceType.knight:
        return 'N';
      case PieceType.pawn:
        return '';
    }
  }

  /// Formats a move with proper SAN disambiguation, check (+), and checkmate (#)
  static String formatMoveWithDisambiguation({
    required MoveRecord move,
    required DynamoBoard boardBeforeMove,
    required PlayerColor playerColor,
    MoveRecord? lastMove,
  }) {
    // Castling
    if (move.pieceType == PieceType.king && (move.end.x - move.start.x).abs() >= 2) {
      final isCheckOrMate = _getCheckSuffix(move, boardBeforeMove, playerColor, lastMove);
      return (move.end.x > move.start.x ? "0-0" : "0-0-0") + isCheckOrMate;
    }

    final endFile = String.fromCharCode(97 + move.end.x);
    final endRank = 10 - move.end.y;

    // Pawn Moves
    if (move.pieceType == PieceType.pawn) {
      String pawnText;
      if (move.isCapture || move.start.x != move.end.x) {
        final startFile = String.fromCharCode(97 + move.start.x);
        pawnText = "${startFile}x$endFile$endRank";
      } else {
        pawnText = "$endFile$endRank";
      }
      final suffix = _getCheckSuffix(move, boardBeforeMove, playerColor, lastMove);
      return "$pawnText$suffix";
    }

    final piecePrefix = _getPiecePrefix(move.pieceType);

    // Find all other identical pieces of the same color that can legally move to move.end
    final otherCandidates = <Position>[];
    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 10; x++) {
        final pos = Position(x, y);
        if (pos == move.start) continue;
        final otherPiece = boardBeforeMove.getPiece(pos);
        if (otherPiece != null &&
            otherPiece.color == playerColor &&
            otherPiece.type == move.pieceType) {
          final legal = RulesEngine.getLegalMoves(pos, boardBeforeMove, lastMove: lastMove);
          if (legal.contains(move.end)) {
            otherCandidates.add(pos);
          }
        }
      }
    }

    String disambiguation = '';
    if (otherCandidates.isNotEmpty) {
      final sameFile = otherCandidates.any((c) => c.x == move.start.x);
      final sameRank = otherCandidates.any((c) => c.y == move.start.y);

      final startFile = String.fromCharCode(97 + move.start.x);
      final startRank = (10 - move.start.y).toString();

      if (!sameFile) {
        // File is unique: e.g. Rae4, Nbd7, Mfe5
        disambiguation = startFile;
      } else if (!sameRank) {
        // Rank is unique: e.g. R1e4, N3d2, M5e5
        disambiguation = startRank;
      } else {
        // Both file and rank are shared by other candidates: e.g. Ra1e4, Qh4e1
        disambiguation = "$startFile$startRank";
      }
    }

    final isCapture = move.isCapture || boardBeforeMove.getPiece(move.end) != null;
    final captureStr = isCapture ? 'x' : '';
    final suffix = _getCheckSuffix(move, boardBeforeMove, playerColor, lastMove);

    return "$piecePrefix$disambiguation$captureStr$endFile$endRank$suffix";
  }

  static String _getCheckSuffix(
    MoveRecord move,
    DynamoBoard boardBeforeMove,
    PlayerColor playerColor,
    MoveRecord? lastMove,
  ) {
    final simBoard = boardBeforeMove.clone();
    final movingPiece = simBoard.getPiece(move.start) ?? DynamoPiece(type: move.pieceType, color: playerColor);

    // Castling simulation
    if (move.pieceType == PieceType.king && (move.end.x - move.start.x).abs() >= 2) {
      final isKingside = move.end.x > move.start.x;
      final rookStartX = isKingside ? 9 : 0;
      final rookEndX = isKingside ? move.end.x - 1 : move.end.x + 1;
      final rook = simBoard.getPiece(Position(rookStartX, move.start.y));
      simBoard.setPiece(Position(rookStartX, move.start.y), null);
      simBoard.setPiece(Position(rookEndX, move.start.y), rook);
    }

    // En passant simulation
    final isEnPassant = move.pieceType == PieceType.pawn &&
        move.start.x != move.end.x &&
        simBoard.getPiece(move.end) == null &&
        lastMove != null &&
        lastMove.pieceType == PieceType.pawn &&
        lastMove.distanceY >= 2 &&
        move.end.x == lastMove.end.x;
    if (isEnPassant) {
      simBoard.setPiece(lastMove.end, null);
    }

    simBoard.setPiece(move.start, null);
    simBoard.setPiece(move.end, movingPiece);

    final opponentColor = playerColor == PlayerColor.white ? PlayerColor.black : PlayerColor.white;
    if (RulesEngine.isCheck(opponentColor, simBoard)) {
      final hasMoves = RulesEngine.hasLegalMoves(opponentColor, simBoard, lastMove: move);
      return hasMoves ? "+" : "#";
    }
    return "";
  }

  static void _applyMoveToBoard(
    DynamoBoard board,
    MoveRecord move,
    PlayerColor playerColor,
    MoveRecord? lastMove,
  ) {
    final movingPiece = board.getPiece(move.start) ?? DynamoPiece(type: move.pieceType, color: playerColor);

    // Castling
    if (move.pieceType == PieceType.king && (move.end.x - move.start.x).abs() >= 2) {
      final isKingside = move.end.x > move.start.x;
      final rookStartX = isKingside ? 9 : 0;
      final rookEndX = isKingside ? move.end.x - 1 : move.end.x + 1;
      final rook = board.getPiece(Position(rookStartX, move.start.y));
      board.setPiece(Position(rookStartX, move.start.y), null);
      board.setPiece(Position(rookEndX, move.start.y), rook);
    }

    // En passant
    final isEnPassant = move.pieceType == PieceType.pawn &&
        move.start.x != move.end.x &&
        board.getPiece(move.end) == null &&
        lastMove != null &&
        lastMove.pieceType == PieceType.pawn &&
        lastMove.distanceY >= 2 &&
        move.end.x == lastMove.end.x;
    if (isEnPassant) {
      board.setPiece(lastMove.end, null);
    }

    board.setPiece(move.start, null);
    board.setPiece(move.end, movingPiece);
  }

  /// Generates a list of disambiguated move notation strings for a move history
  static List<String> getFormattedMovesList(List<MoveRecord> history, {String? initialFen}) {
    final simBoard = DynamoBoard();
    if (initialFen != null && initialFen.isNotEmpty) {
      simBoard.grid = FenConverter.fromFen(initialFen);
    } else {
      simBoard.initializeBoard();
    }

    final formattedMoves = <String>[];
    MoveRecord? lastMove;
    for (int i = 0; i < history.length; i++) {
      final move = history[i];
      final color = (i % 2 == 0) ? PlayerColor.white : PlayerColor.black;
      final moveStr = formatMoveWithDisambiguation(
        move: move,
        boardBeforeMove: simBoard,
        playerColor: color,
        lastMove: lastMove,
      );
      formattedMoves.add(moveStr);
      _applyMoveToBoard(simBoard, move, color, lastMove);
      lastMove = move;
    }
    return formattedMoves;
  }

  /// Generates a standard RFC-compliant PGN file content for Dynamo Chess
  static String generatePgn({
    required String whitePlayer,
    required String blackPlayer,
    required String result,
    required List<MoveRecord> history,
    String event = "Dynamo Chess Match",
    String site = "Dynamo Chess App",
    DateTime? date,
    String? timeControl,
    String? termination,
    String? initialFen,
  }) {
    final gameDate = date ?? DateTime.now();
    final dateStr = "${gameDate.year}.${gameDate.month.toString().padLeft(2, '0')}.${gameDate.day.toString().padLeft(2, '0')}";

    String pgnResult;
    final rLower = result.toLowerCase();
    if (rLower.contains('white') || rLower == '1-0' || rLower == 'white_won') {
      pgnResult = '1-0';
    } else if (rLower.contains('black') || rLower == '0-1' || rLower == 'black_won') {
      pgnResult = '0-1';
    } else if (rLower.contains('draw') || rLower == '1/2-1/2') {
      pgnResult = '1/2-1/2';
    } else {
      pgnResult = '*';
    }

    final buffer = StringBuffer();
    buffer.writeln('[Event "$event"]');
    buffer.writeln('[Site "$site"]');
    buffer.writeln('[Date "$dateStr"]');
    buffer.writeln('[Round "1"]');
    buffer.writeln('[White "$whitePlayer"]');
    buffer.writeln('[Black "$blackPlayer"]');
    buffer.writeln('[Result "$pgnResult"]');
    buffer.writeln('[Variant "Dynamo Chess 10x10"]');
    if (timeControl != null && timeControl.isNotEmpty) {
      buffer.writeln('[TimeControl "$timeControl"]');
    }
    if (termination != null && termination.isNotEmpty) {
      buffer.writeln('[Termination "$termination"]');
    }

    final fen = (initialFen != null && initialFen.isNotEmpty)
        ? initialFen
        : 'rnbmqkmbnr/pppppppppp/10/10/10/10/10/10/PPPPPPPPPP/RNBMQKMBNR w - - 0 1';
    buffer.writeln('[SetUp "1"]');
    buffer.writeln('[FEN "$fen"]');
    buffer.writeln();

    // Format moves with disambiguation
    final formattedMoves = getFormattedMovesList(history, initialFen: initialFen);
    final movesBuffer = StringBuffer();
    for (int i = 0; i < formattedMoves.length; i++) {
      if (i % 2 == 0) {
        final moveNum = (i ~/ 2) + 1;
        movesBuffer.write("$moveNum. ");
      }
      movesBuffer.write(formattedMoves[i]);
      movesBuffer.write(" ");
    }
    movesBuffer.write(pgnResult);

    buffer.writeln(movesBuffer.toString().trim());
    return buffer.toString();
  }

  /// Downloads / exports the PGN file
  static Future<bool> downloadPgnFile(String pgnContent, String fileName) async {
    try {
      final bytes = utf8.encode(pgnContent);
      final base64Data = base64Encode(bytes);
      final uri = Uri.parse('data:application/x-chess-pgn;base64,$base64Data');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error downloading PGN file: $e");
      return false;
    }
  }
}
