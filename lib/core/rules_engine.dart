import 'models.dart';
import 'board.dart';

class RulesEngine {
  static List<Position> getValidMoves(Position start, DynamoBoard board, {
    MoveRecord? lastMove,
    bool canCastleKingside = false,
    bool canCastleQueenside = false,
  }) {
    final piece = board.getPiece(start);
    if (piece == null) return [];

    switch (piece.type) {
      case PieceType.pawn:
        return _getPawnMoves(start, piece.color, board, lastMove);
      case PieceType.rook:
        return _getStraightMoves(start, board);
      case PieceType.bishop:
        return _getDiagonalMoves(start, board);
      case PieceType.knight:
        return _getKnightMoves(start, board);
      case PieceType.queen:
        return [..._getStraightMoves(start, board), ..._getDiagonalMoves(start, board)];
      case PieceType.missile:
        // Missile = Bishop + Knight
        return [..._getDiagonalMoves(start, board), ..._getKnightMoves(start, board)];
      case PieceType.king:
        return _getKingMoves(start, board, canCastleKingside, canCastleQueenside);
    }
  }

  static List<Position> getLegalMoves(Position start, DynamoBoard board, {
    MoveRecord? lastMove,
    bool canCastleKingside = false,
    bool canCastleQueenside = false,
  }) {
    final piece = board.getPiece(start);
    if (piece == null) return [];
    
    final potentialMoves = getValidMoves(start, board, 
      lastMove: lastMove,
      canCastleKingside: canCastleKingside,
      canCastleQueenside: canCastleQueenside,
    );
    final legalMoves = <Position>[];

    for (final end in potentialMoves) {
      // Simulate
      final originalPieceAtEnd = board.getPiece(end);
      board.setPiece(end, piece);
      board.setPiece(start, null);
      
      if (!isCheck(piece.color, board)) {
        legalMoves.add(end);
      }
      
      // Revert
      board.setPiece(start, piece);
      board.setPiece(end, originalPieceAtEnd);
    }
    return legalMoves;
  }

  static List<Position> _getPawnMoves(Position start, PlayerColor color, DynamoBoard board, MoveRecord? lastMove) {
    final moves = <Position>[];
    final dy = (color == PlayerColor.white) ? -1 : 1;

    // Forward 1
    var next = Position(start.x, start.y + dy);
    if (next.isValid && board.getPiece(next) == null) {
      moves.add(next);

      // Forward 2 (Initial)
      bool isInitial = (color == PlayerColor.white && start.y == 8) ||
                       (color == PlayerColor.black && start.y == 1);
      if (isInitial) {
        next = Position(start.x, start.y + 2 * dy);
        if (next.isValid && board.getPiece(next) == null) {
          moves.add(next);

          // Forward 3 (Initial - Dynamo Chess Rule)
          next = Position(start.x, start.y + 3 * dy);
          if (next.isValid && board.getPiece(next) == null) {
            moves.add(next);
          }
        }
      }
    }

    // Standard Captures (Diagonal)
    for (int dx in [-1, 1]) {
      next = Position(start.x + dx, start.y + dy);
      if (next.isValid) {
        final target = board.getPiece(next);
        if (target != null && target.color != color) {
          moves.add(next);
        }
      }
    }

    // En-passant (Rule 7 & 13)
    // Supports "two types" of en-passant: captures after 2-step or 3-step jumps.
    if (lastMove != null && lastMove.pieceType == PieceType.pawn && lastMove.distanceY >= 2) {
      // Must be in an adjacent file
      if ((start.x - lastMove.end.x).abs() == 1) {
        final jumpStart = lastMove.start.y;
        final jumpEnd = lastMove.end.y;
        final dyJump = (jumpEnd - jumpStart).sign;

        // Passed ranks include jumpEnd and everything between jumpStart and jumpEnd
        // A capture is possible if our pawn is at 'jumpEnd' (standard) 
        // OR if it's at one of the skipped ranks (jumpEnd - dyJump, etc.)
        
        bool isAtCorrectRank = false;
        // Check if our current rank matches where the opponent pawn jumped past or landed
        if (start.y == jumpEnd || start.y == jumpEnd - dyJump || (lastMove.distanceY == 3 && start.y == jumpEnd - 2 * dyJump)) {
           isAtCorrectRank = true;
        }

        if (isAtCorrectRank) {
          // Rule: capture and move diagonally to the rank 'ahead' in the jump direction
          // Target square is the rank the opponent pawn jumped into or past, relative to our current rank
          moves.add(Position(lastMove.end.x, start.y + dyJump));
        }
      }
    }

    return moves;
  }

  static List<Position> _getStraightMoves(Position start, DynamoBoard board) {
    final moves = <Position>[];
    final color = board.getPiece(start)?.color;
    final directions = [const Position(0, 1), const Position(0, -1), const Position(1, 0), const Position(-1, 0)];

    for (var dir in directions) {
      for (int i = 1; i < 10; i++) {
        final next = Position(start.x + dir.x * i, start.y + dir.y * i);
        if (!next.isValid) break;
        final piece = board.getPiece(next);
        if (piece == null) {
          moves.add(next);
        } else {
          if (piece.color != color) moves.add(next);
          break;
        }
      }
    }
    return moves;
  }

  static List<Position> _getDiagonalMoves(Position start, DynamoBoard board) {
    final moves = <Position>[];
    final color = board.getPiece(start)?.color;
    final directions = [const Position(1, 1), const Position(1, -1), const Position(-1, 1), const Position(-1, -1)];

    for (var dir in directions) {
      for (int i = 1; i < 10; i++) {
        final next = Position(start.x + dir.x * i, start.y + dir.y * i);
        if (!next.isValid) break;
        final piece = board.getPiece(next);
        if (piece == null) {
          moves.add(next);
        } else {
          if (piece.color != color) moves.add(next);
          break;
        }
      }
    }
    return moves;
  }

  static List<Position> _getKnightMoves(Position start, DynamoBoard board) {
    final moves = <Position>[];
    final color = board.getPiece(start)?.color;
    final offsets = [
      [1, 2], [1, -2], [-1, 2], [-1, -2],
      [2, 1], [2, -1], [-2, 1], [-2, -1]
    ];

    for (var off in offsets) {
      final next = Position(start.x + off[0], start.y + off[1]);
      if (next.isValid) {
        final piece = board.getPiece(next);
        if (piece == null || piece.color != color) {
          moves.add(next);
        }
      }
    }
    return moves;
  }

  static List<Position> _getKingMoves(Position start, DynamoBoard board, bool canKingside, bool canQueenside) {
    final moves = <Position>[];
    final piece = board.getPiece(start);
    final color = piece?.color;
    if (color == null) return [];

    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        if (dx == 0 && dy == 0) continue;
        final next = Position(start.x + dx, start.y + dy);
        if (next.isValid) {
          // Standard Rule: King cannot be adjacent to another King
          bool adjacentToOpponentKing = false;
          for (int ox = -1; ox <= 1; ox++) {
            for (int oy = -1; oy <= 1; oy++) {
               final checkPos = Position(next.x + ox, next.y + oy);
               if (checkPos.isValid) {
                  final p = board.getPiece(checkPos);
                  if (p != null && p.type == PieceType.king && p.color != color) {
                    adjacentToOpponentKing = true;
                    break;
                  }
               }
            }
            if (adjacentToOpponentKing) break;
          }
          
          if (!adjacentToOpponentKing) {
            final target = board.getPiece(next);
            if (target == null || target.color != color) {
              moves.add(next);
            }
          }
        }
      }
    }

    if (canQueenside && _canCastle(start, Position(0, start.y), board)) moves.add(Position(2, start.y));
    if (canKingside && _canCastle(start, Position(9, start.y), board)) moves.add(Position(8, start.y));

    return moves;
  }

  static bool _canCastle(Position kingPos, Position rookPos, DynamoBoard board) {
    if (kingPos.y != rookPos.y) return false;
    final king = board.getPiece(kingPos);
    final rook = board.getPiece(rookPos);
    if (king?.type != PieceType.king || rook?.type != PieceType.rook) return false;
    if (king?.color != rook?.color) return false;

    // Standard Chess Rule: Cannot castle while in check
    if (isCheck(king!.color, board)) return false;

    int step = rookPos.x > kingPos.x ? 1 : -1;
    
    // Check if squares between King and Rook are empty
    // AND if squares the King passes through are attacked
    for (int x = kingPos.x + step; x != rookPos.x; x += step) {
      if (board.getPiece(Position(x, kingPos.y)) != null) return false;
      
      // King only moves 2 squares in standard, but here it might move more?
      // In Dynamo 10x10, King moves to x=2 or x=8. 
      // We check all squares between start and end (inclusive of end) for attacks.
      int kingTargetX = rookPos.x == 9 ? 8 : 2;
      bool isPathSquare = (x <= kingTargetX && x >= kingPos.x) || (x >= kingTargetX && x <= kingPos.x);
      
      if (isPathSquare) {
        if (_isSquareAttacked(Position(x, kingPos.y), king.color, board)) return false;
      }
    }
    return true;
  }

  static bool _isSquareAttacked(Position pos, PlayerColor myColor, DynamoBoard board) {
    final opponentColor = (myColor == PlayerColor.white) ? PlayerColor.black : PlayerColor.white;
    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 10; x++) {
        final p = board.getPiece(Position(x, y));
        if (p != null && p.color == opponentColor) {
          // Use getValidMoves without castling check to avoid recursion
          if (getValidMoves(Position(x, y), board).contains(pos)) return true;
        }
      }
    }
    return false;
  }

  static bool isCheck(PlayerColor color, DynamoBoard board) {
    Position? kingPos;
    // Optimization: Usually the King is near where it was last seen. 
    // For now, just find it once per check.
    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 10; x++) {
        final p = board.grid[y][x];
        if (p != null && p.type == PieceType.king && p.color == color) {
          kingPos = Position(x, y);
          break;
        }
      }
      if (kingPos != null) break;
    }
    
    if (kingPos == null) return false;

    final opponentColor = (color == PlayerColor.white) ? PlayerColor.black : PlayerColor.white;
    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 10; x++) {
        final p = board.grid[y][x];
        if (p != null && p.color == opponentColor) {
          // Check if this piece can move to the king's position
          // Using getValidMoves (non-legal) is correct here
          if (getValidMoves(Position(x, y), board).contains(kingPos)) return true;
        }
      }
    }
    return false;
  }

  static bool hasLegalMoves(PlayerColor color, DynamoBoard board, {
    MoveRecord? lastMove,
    bool canCastleKingside = false,
    bool canCastleQueenside = false,
  }) {
    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 10; x++) {
        final start = Position(x, y);
        final piece = board.getPiece(start);
        if (piece != null && piece.color == color) {
          final legal = getLegalMoves(start, board, 
            lastMove: lastMove,
            canCastleKingside: canCastleKingside,
            canCastleQueenside: canCastleQueenside,
          );
          if (legal.isNotEmpty) return true;
        }
      }
    }
    return false;
  }
}
