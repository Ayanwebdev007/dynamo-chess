import 'board.dart';
import 'models.dart';

class ScoreCalculator {
  static const Map<PieceType, int> startingPieces = {
    PieceType.pawn: 10,
    PieceType.knight: 2,
    PieceType.bishop: 2,
    PieceType.rook: 2,
    PieceType.missile: 2,
    PieceType.queen: 1,
    PieceType.king: 1, // Kings are usually ignored but tracked for completeness
  };

  static const Map<PieceType, int> pieceValues = {
    PieceType.pawn: 1,
    PieceType.knight: 3,
    PieceType.bishop: 3,
    PieceType.rook: 5,
    PieceType.missile: 7,
    PieceType.queen: 9,
    PieceType.king: 0,
  };

  static List<PieceType> getCapturedPieces(List<MoveRecord> history, PlayerColor capturedBy) {
    List<PieceType> captured = [];
    
    // We only care about moves made by 'capturedBy' (who did the capturing)
    // Actually, in our game history, even indices are White moves, odd are Black.
    // But it's safer to check the piece color if we had it. 
    // Since MoveRecord doesn't have piece color, we use the history index logic 
    // or we can pass a more specific list.
    
    // BETTER: The caller knows which moves are white and which are black.
    // For simplicity, let's assume history[0, 2, 4...] are White's captures if they have isCapture=true.
    
    for (int i = 0; i < history.length; i++) {
       final move = history[i];
       if (move.isCapture && move.capturedPieceType != null) {
          final moveByWhite = i % 2 == 0;
          if (capturedBy == PlayerColor.white && moveByWhite) {
            captured.add(move.capturedPieceType!);
          } else if (capturedBy == PlayerColor.black && !moveByWhite) {
            captured.add(move.capturedPieceType!);
          }
       }
    }

    // Sort captured pieces by value descending
    captured.sort((a, b) => (pieceValues[b] ?? 0).compareTo(pieceValues[a] ?? 0));
    
    return captured;
  }

  static int computeScore(List<PieceType> captured) {
    int score = 0;
    for (var piece in captured) {
      score += pieceValues[piece] ?? 0;
    }
    return score;
  }

  static Map<PlayerColor, int> getScoreAdvantage(List<MoveRecord> history) {
    final whiteCaptured = getCapturedPieces(history, PlayerColor.white); 
    final blackCaptured = getCapturedPieces(history, PlayerColor.black); 
    
    final whiteScore = computeScore(whiteCaptured);
    final blackScore = computeScore(blackCaptured);
    
    if (whiteScore > blackScore) {
      return {PlayerColor.white: whiteScore - blackScore};
    } else if (blackScore > whiteScore) {
      return {PlayerColor.black: blackScore - whiteScore};
    }
    
    return {};
  }
}
