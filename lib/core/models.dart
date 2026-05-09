enum PieceType {
  king,
  queen,
  missile, // bishop + knight
  rook,
  bishop,
  knight,
  pawn
}

enum PlayerColor { white, black }

class DynamoPiece {
  final PieceType type;
  final PlayerColor color;

  const DynamoPiece({required this.type, required this.color});
}

class Position {
  final int x; // 0-9
  final int y; // 0-9

  const Position(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  bool get isValid => x >= 0 && x < 10 && y >= 0 && y < 10;
}

class GameSettings {
  final Duration timeLimit;
  final Duration increment;
  final bool isCustom;

  const GameSettings({
    required this.timeLimit,
    this.increment = Duration.zero,
    this.isCustom = false,
  });

  static const bullet1 = GameSettings(timeLimit: Duration(minutes: 1));
  static const bullet1_1 = GameSettings(timeLimit: Duration(minutes: 1), increment: Duration(seconds: 1));
  static const bullet2_1 = GameSettings(timeLimit: Duration(minutes: 2), increment: Duration(seconds: 1));
  
  static const blitz3 = GameSettings(timeLimit: Duration(minutes: 3));
  static const blitz3_2 = GameSettings(timeLimit: Duration(minutes: 3), increment: Duration(seconds: 2));
  static const blitz5 = GameSettings(timeLimit: Duration(minutes: 5));
  
  static const rapid10 = GameSettings(timeLimit: Duration(minutes: 10));
  static const rapid15_10 = GameSettings(timeLimit: Duration(minutes: 15), increment: Duration(seconds: 10));

  @override
  String toString() {
    String twoDigits(int n) => n.toString();
    String min = twoDigits(timeLimit.inMinutes);
    String sec = (increment.inSeconds > 0) ? "+${increment.inSeconds}" : "";
    return "$min$sec";
  }
}

class MoveRecord {
  final Position start;
  final Position end;
  final PieceType pieceType;
  final bool isCapture;
  final PieceType? capturedPieceType;

  MoveRecord({
    required this.start,
    required this.end,
    required this.pieceType,
    required this.isCapture,
    this.capturedPieceType,
  });
  
  int get distanceY => (end.y - start.y).abs();
}


