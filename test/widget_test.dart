import 'package:flutter_test/flutter_test.dart';
import 'package:dynamo_chess/core/models.dart';
import 'package:dynamo_chess/core/board.dart';
import 'package:dynamo_chess/core/rules_engine.dart';

void main() {
  group('En-passant Rules Tests', () {
    test('White captures Black en-passant after a 3-step jump', () {
      final board = DynamoBoard();
      
      // White pawn at (3, 3)
      final whitePawn = const DynamoPiece(type: PieceType.pawn, color: PlayerColor.white);
      board.setPiece(const Position(3, 3), whitePawn);
      
      // Black pawn at (4, 4)
      final blackPawn = const DynamoPiece(type: PieceType.pawn, color: PlayerColor.black);
      board.setPiece(const Position(4, 4), blackPawn);
      
      // Black pawn jumped from (4, 1) to (4, 4)
      final lastMove = MoveRecord(
        start: const Position(4, 1),
        end: const Position(4, 4),
        pieceType: PieceType.pawn,
        isCapture: false,
      );
      
      final moves = RulesEngine.getValidMoves(const Position(3, 3), board, lastMove: lastMove);
      
      // The target square of the capture should be (4, 2) (one step forward diagonally for White)
      expect(moves, contains(const Position(4, 2)));
      expect(moves, isNot(contains(const Position(4, 4))));
    });

    test('Black captures White en-passant after a 3-step jump', () {
      final board = DynamoBoard();
      
      // Black pawn at (3, 6)
      final blackPawn = const DynamoPiece(type: PieceType.pawn, color: PlayerColor.black);
      board.setPiece(const Position(3, 6), blackPawn);
      
      // White pawn at (4, 5)
      final whitePawn = const DynamoPiece(type: PieceType.pawn, color: PlayerColor.white);
      board.setPiece(const Position(4, 5), whitePawn);
      
      // White pawn jumped from (4, 8) to (4, 5)
      final lastMove = MoveRecord(
        start: const Position(4, 8),
        end: const Position(4, 5),
        pieceType: PieceType.pawn,
        isCapture: false,
      );
      
      final moves = RulesEngine.getValidMoves(const Position(3, 6), board, lastMove: lastMove);
      
      // The target square of the capture should be (4, 7) (one step forward diagonally for Black)
      expect(moves, contains(const Position(4, 7)));
      expect(moves, isNot(contains(const Position(4, 5))));
    });
  });
}
