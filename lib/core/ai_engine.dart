import 'dart:math';
import 'models.dart';
import 'board.dart';
import 'rules_engine.dart';

class AIEngine {
  static const int _infinity = 1000000;
  
  // Enhanced Piece Values
  static const Map<PieceType, int> _pieceValues = {
    PieceType.pawn: 100,
    PieceType.knight: 320,
    PieceType.bishop: 330,
    PieceType.rook: 500,
    PieceType.missile: 600, // Very powerful in Dynamo
    PieceType.queen: 900,
    PieceType.king: 20000,
  };

  // Piece-Square Tables (Simplified for 10x10)
  // Higher values encourage pieces to move to those squares
  static const List<List<int>> _pawnPST = [
    [0,  0,  0,  0,  0,  0,  0,  0,  0,  0],
    [50, 50, 50, 50, 50, 50, 50, 50, 50, 50],
    [10, 10, 20, 30, 30, 30, 30, 20, 10, 10],
    [5,  5, 10, 25, 25, 25, 25, 10,  5,  5],
    [0,  0,  0, 20, 20, 20, 20,  0,  0,  0],
    [5, -5,-10,  0,  0,  0,  0,-10, -5,  5],
    [5, 10, 10,-20,-20,-20,-20, 10, 10,  5],
    [0,  0,  0,  0,  0,  0,  0,  0,  0,  0],
    [0,  0,  0,  0,  0,  0,  0,  0,  0,  0],
    [0,  0,  0,  0,  0,  0,  0,  0,  0,  0],
  ];

  static DynamoBoard _cloneBoard(DynamoBoard board) {
    DynamoBoard clone = DynamoBoard();
    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 10; x++) {
        final p = board.grid[y][x];
        clone.grid[y][x] = p != null ? DynamoPiece(type: p.type, color: p.color) : null;
      }
    }
    return clone;
  }

  /// Main entry point for the AI to pick a move
  static Future<Move?> getBestMove(DynamoBoard board, PlayerColor aiColor, int depth) async {
    Move? bestMove;
    int bestValue = -_infinity;
    
    final allMoves = _getAllLegalMoves(board, aiColor);
    if (allMoves.isEmpty) return null;

    // Move Ordering: Evaluate captures first to improve pruning
    allMoves.sort((a, b) {
      final aTarget = board.getPiece(a.end);
      final bTarget = board.getPiece(b.end);
      if (aTarget != null && bTarget == null) return -1;
      if (aTarget == null && bTarget != null) return 1;
      return 0;
    });

    // Clone board so UI doesn't render simulated states
    DynamoBoard simBoard = _cloneBoard(board);

    for (var move in allMoves) {
      // Simulate move
      final originalEndPiece = simBoard.getPiece(move.end);
      simBoard.setPiece(move.end, simBoard.getPiece(move.start));
      simBoard.setPiece(move.start, null);
      
      // Calculate without async overhead to keep it blazing fast
      int boardValue = _minimax(simBoard, depth - 1, -_infinity, _infinity, false, aiColor);
      
      // Yield to UI thread ONLY at the top level to prevent freezing the clock
      await Future.delayed(Duration.zero);
      
      // Revert move
      simBoard.setPiece(move.start, simBoard.getPiece(move.end));
      simBoard.setPiece(move.end, originalEndPiece);
      
      if (boardValue > bestValue) {
        bestValue = boardValue;
        bestMove = move;
      }
    }
    
    return bestMove;
  }

  static int _minimax(DynamoBoard board, int depth, int alpha, int beta, bool isMaximizing, PlayerColor aiColor) {
    if (depth == 0) {
      return _evaluateBoard(board, aiColor);
    }

    final currentPlayerColor = isMaximizing ? aiColor : (aiColor == PlayerColor.white ? PlayerColor.black : PlayerColor.white);
    final moves = _getAllLegalMoves(board, currentPlayerColor);

    if (moves.isEmpty) {
      if (RulesEngine.isCheck(currentPlayerColor, board)) {
        return isMaximizing ? -(_infinity + depth) : (_infinity + depth); // Checkmate
      }
      return 0; // Stalemate
    }

    if (isMaximizing) {
      int maxEval = -_infinity;
      for (var move in moves) {
        final originalEndPiece = board.getPiece(move.end);
        board.setPiece(move.end, board.getPiece(move.start));
        board.setPiece(move.start, null);
        
        int eval = _minimax(board, depth - 1, alpha, beta, false, aiColor);
        
        board.setPiece(move.start, board.getPiece(move.end));
        board.setPiece(move.end, originalEndPiece);
        
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) break;
      }
      return maxEval;
    } else {
      int minEval = _infinity;
      for (var move in moves) {
        final originalEndPiece = board.getPiece(move.end);
        board.setPiece(move.end, board.getPiece(move.start));
        board.setPiece(move.start, null);
        
        int eval = _minimax(board, depth - 1, alpha, beta, true, aiColor);
        
        board.setPiece(move.start, board.getPiece(move.end));
        board.setPiece(move.end, originalEndPiece);
        
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) break;
      }
      return minEval;
    }
  }

  static int _evaluateBoard(DynamoBoard board, PlayerColor aiColor) {
    int totalEvaluation = 0;
    
    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 10; x++) {
        final pos = Position(x, y);
        final piece = board.getPiece(pos);
        if (piece != null) {
          int val = _pieceValues[piece.type] ?? 0;
          
          // PST Bonuses
          if (piece.type == PieceType.pawn) {
            val += piece.color == PlayerColor.white ? _pawnPST[y][x] : _pawnPST[9-y][x];
          }

          // Center Control
          double dist = sqrt(pow(x - 4.5, 2) + pow(y - 4.5, 2));
          val += (10 * (7 - dist)).toInt(); 

          if (piece.color == aiColor) {
            totalEvaluation += val;
          } else {
            totalEvaluation -= val;
          }
        }
      }
    }
    
    // Add Mobility Bonus
    totalEvaluation += _getAllLegalMoves(board, aiColor).length;
    totalEvaluation -= _getAllLegalMoves(board, aiColor == PlayerColor.white ? PlayerColor.black : PlayerColor.white).length;

    return totalEvaluation;
  }

  static List<Move> _getAllLegalMoves(DynamoBoard board, PlayerColor color) {
    final List<Move> moves = [];
    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 10; x++) {
        final start = Position(x, y);
        final piece = board.getPiece(start);
        if (piece != null && piece.color == color) {
          final legalEnds = RulesEngine.getLegalMoves(start, board);
          for (var end in legalEnds) {
            moves.add(Move(start: start, end: end));
          }
        }
      }
    }
    return moves;
  }
}

class Move {
  final Position start;
  final Position end;
  Move({required this.start, required this.end});
}
