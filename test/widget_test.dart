import 'package:flutter_test/flutter_test.dart';
import 'package:dynamo_chess/core/models.dart';
import 'package:dynamo_chess/core/board.dart';
import 'package:dynamo_chess/core/rules_engine.dart';
import 'package:dynamo_chess/core/puzzle_service.dart';
import 'package:dynamo_chess/core/fen_converter.dart';

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

  group('Puzzle Promotion Tests', () {
    test('PuzzleMove serializes and deserializes promotionPiece correctly', () {
      final moveWithPromo = PuzzleMove(
        start: const Position(4, 1),
        end: const Position(4, 0),
        promotionPiece: PieceType.missile,
      );

      final json = moveWithPromo.toJson();
      expect(json['startX'], equals(4));
      expect(json['startY'], equals(1));
      expect(json['endX'], equals(4));
      expect(json['endY'], equals(0));
      expect(json['promotionPiece'], equals('missile'));

      final restored = PuzzleMove.fromJson(json);
      expect(restored.start, equals(const Position(4, 1)));
      expect(restored.end, equals(const Position(4, 0)));
      expect(restored.promotionPiece, equals(PieceType.missile));
    });

    test('PuzzleMove handles legacy JSON without promotionPiece for backward compatibility', () {
      final legacyJson = {
        'startX': 4,
        'startY': 1,
        'endX': 4,
        'endY': 0,
      };

      final restored = PuzzleMove.fromJson(legacyJson);
      expect(restored.start, equals(const Position(4, 1)));
      expect(restored.end, equals(const Position(4, 0)));
      expect(restored.promotionPiece, isNull);
    });
  });

  group('Multiple Solution Lines Tests', () {
    test('Puzzle serializes and deserializes alternativeSolutions correctly', () {
      final mainLine = [
        PuzzleMove(start: const Position(1, 1), end: const Position(1, 2)),
      ];
      final altLine1 = [
        PuzzleMove(start: const Position(2, 2), end: const Position(2, 4)),
      ];
      final altLine2 = [
        PuzzleMove(start: const Position(3, 3), end: const Position(3, 5)),
      ];

      final puzzle = Puzzle(
        id: 'p1',
        title: 'Multi Line Puzzle',
        description: 'Test puzzle with variations',
        initialFen: 'w standard FEN',
        movesToWin: 1,
        startTurn: PlayerColor.white,
        solutionMoves: mainLine,
        alternativeSolutions: [altLine1, altLine2],
      );

      expect(puzzle.allSolutions.length, equals(3));

      final json = puzzle.toJson();
      expect(json['alternativeSolutions'], isNotNull);
      expect((json['alternativeSolutions'] as List).length, equals(2));

      final restored = Puzzle.fromJson(json);
      expect(restored.solutionMoves.length, equals(1));
      expect(restored.alternativeSolutions.length, equals(2));
      expect(restored.allSolutions.length, equals(3));
      expect(restored.allSolutions[1][0].start, equals(const Position(2, 2)));
      expect(restored.allSolutions[2][0].start, equals(const Position(3, 3)));
    });
  });

  group('Custom Position Promoted Pieces Tests', () {
    test('DynamoBoard handles custom positions with extra promoted pieces (3+ Knights, 2 Queens)', () {
      final board = DynamoBoard();
      board.setPiece(const Position(4, 9), const DynamoPiece(type: PieceType.king, color: PlayerColor.white));
      board.setPiece(const Position(4, 0), const DynamoPiece(type: PieceType.king, color: PlayerColor.black));

      // 3 White Knights (created via promotion in custom puzzle position)
      board.setPiece(const Position(1, 8), const DynamoPiece(type: PieceType.knight, color: PlayerColor.white));
      board.setPiece(const Position(2, 8), const DynamoPiece(type: PieceType.knight, color: PlayerColor.white));
      board.setPiece(const Position(3, 8), const DynamoPiece(type: PieceType.knight, color: PlayerColor.white));

      // 2 White Queens
      board.setPiece(const Position(5, 8), const DynamoPiece(type: PieceType.queen, color: PlayerColor.white));
      board.setPiece(const Position(6, 8), const DynamoPiece(type: PieceType.queen, color: PlayerColor.white));

      final fen = FenConverter.toFen(board.grid, PlayerColor.white);
      final restoredGrid = FenConverter.fromFen(fen);

      int whiteKnightCount = 0;
      int whiteQueenCount = 0;
      for (int y = 0; y < 10; y++) {
        for (int x = 0; x < 10; x++) {
          final p = restoredGrid[y][x];
          if (p != null && p.color == PlayerColor.white) {
            if (p.type == PieceType.knight) whiteKnightCount++;
            if (p.type == PieceType.queen) whiteQueenCount++;
          }
        }
      }

      expect(whiteKnightCount, equals(3));
      expect(whiteQueenCount, equals(2));
    });
  });

  group('Show Previous Move Tests', () {
    test('Puzzle serializes and deserializes previousMove correctly', () {
      final prevMove = PuzzleMove(start: const Position(4, 3), end: const Position(4, 5));
      final mainMove = PuzzleMove(start: const Position(5, 8), end: const Position(5, 7));

      final puzzle = Puzzle(
        id: 'p_prev',
        title: 'Previous Move Puzzle',
        description: 'Test puzzle with previous move',
        initialFen: 'w standard FEN',
        movesToWin: 1,
        startTurn: PlayerColor.white,
        solutionMoves: [mainMove],
        previousMove: prevMove,
      );

      final json = puzzle.toJson();
      expect(json['previousMove'], isNotNull);
      expect(json['previousMove']['startX'], equals(4));
      expect(json['previousMove']['startY'], equals(3));
      expect(json['previousMove']['endX'], equals(4));
      expect(json['previousMove']['endY'], equals(5));

      final restored = Puzzle.fromJson(json);
      expect(restored.previousMove, isNotNull);
      expect(restored.previousMove!.start, equals(const Position(4, 3)));
      expect(restored.previousMove!.end, equals(const Position(4, 5)));
    });
  });

  group('Long Sequence Puzzle Tests', () {
    test('Puzzle supports 10 moves to win (19 plies total)', () {
      final moves = List.generate(19, (i) {
        return PuzzleMove(start: Position(0, i % 10), end: Position(1, i % 10));
      });

      final puzzle = Puzzle(
        id: 'p_long',
        title: 'Long 10-Move Puzzle',
        description: 'Deep tactical puzzle sequence',
        initialFen: 'w standard FEN',
        movesToWin: 10,
        startTurn: PlayerColor.white,
        solutionMoves: moves,
      );

      expect(puzzle.movesToWin, equals(10));
      expect(puzzle.solutionMoves.length, equals(19));

      final json = puzzle.toJson();
      final restored = Puzzle.fromJson(json);
      expect(restored.movesToWin, equals(10));
      expect(restored.solutionMoves.length, equals(19));
    });
  });

  group('Edit Existing Puzzle Tests', () {
    test('Updating an existing puzzle preserves ID and updates title and description', () {
      final original = Puzzle(
        id: 'puzzle_123',
        title: 'Original Title',
        description: 'Original Description',
        initialFen: 'w standard FEN',
        movesToWin: 1,
        startTurn: PlayerColor.white,
        solutionMoves: [PuzzleMove(start: const Position(1, 1), end: const Position(1, 2))],
      );

      // Edit action: reuse original ID and update title/description
      final updated = Puzzle(
        id: original.id,
        title: 'Edited Title',
        description: 'Edited Description',
        initialFen: original.initialFen,
        movesToWin: original.movesToWin,
        startTurn: original.startTurn,
        solutionMoves: original.solutionMoves,
      );

      expect(updated.id, equals('puzzle_123'));
      expect(updated.title, equals('Edited Title'));
      expect(updated.description, equals('Edited Description'));
    });
  });
}
