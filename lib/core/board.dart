import 'models.dart';

class DynamoBoard {
  List<List<DynamoPiece?>> grid;

  DynamoBoard()
      : grid = List.generate(
          10,
          (_) => List.generate(10, (_) => null),
        );

  void setPiece(Position pos, DynamoPiece? piece) {
    if (pos.isValid) {
      grid[pos.y][pos.x] = piece;
    }
  }

  DynamoPiece? getPiece(Position pos) {
    if (!pos.isValid) return null;
    return grid[pos.y][pos.x];
  }

  DynamoBoard clone() {
    final copy = DynamoBoard();
    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 10; x++) {
        copy.grid[y][x] = grid[y][x];
      }
    }
    return copy;
  }

  void initializeBoard() {
    // Fill Pawns
    for (int x = 0; x < 10; x++) {
      setPiece(Position(x, 1), const DynamoPiece(type: PieceType.pawn, color: PlayerColor.black));
      setPiece(Position(x, 8), const DynamoPiece(type: PieceType.pawn, color: PlayerColor.white));
    }

    // Black Pieces (Rank 0)
    _setupBackRank(0, PlayerColor.black);
    // White Pieces (Rank 9)
    _setupBackRank(9, PlayerColor.white);
  }

  void _setupBackRank(int y, PlayerColor color) {
    // Standard: Rook, Knight, Bishop, Queen, Missile, King, Missile, Bishop, Knight, Rook
    final pieces = [
      PieceType.rook,
      PieceType.knight,
      PieceType.bishop,
      PieceType.missile, // Dynamo flanking Queen
      PieceType.queen,   // Queen
      PieceType.king,    // King (Side by side with Queen)
      PieceType.missile, // Dynamo flanking King
      PieceType.bishop,
      PieceType.knight,
      PieceType.rook,
    ];

    for (int x = 0; x < 10; x++) {
      setPiece(Position(x, y), DynamoPiece(type: pieces[x], color: color));
    }
  }
  String toFen() {
    String fen = "";
    for (int y = 0; y < 10; y++) {
      int emptyCount = 0;
      for (int x = 0; x < 10; x++) {
        final piece = grid[y][x];
        if (piece == null) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            fen += emptyCount.toString();
            emptyCount = 0;
          }
          String char = _pieceToChar(piece);
          fen += char;
        }
      }
      if (emptyCount > 0) {
        fen += emptyCount.toString();
      }
      if (y < 9) fen += "/";
    }
    return fen;
  }

  String _pieceToChar(DynamoPiece piece) {
    String p = "";
    switch (piece.type) {
      case PieceType.pawn: p = "p"; break;
      case PieceType.rook: p = "r"; break;
      case PieceType.knight: p = "n"; break;
      case PieceType.bishop: p = "b"; break;
      case PieceType.queen: p = "q"; break;
      case PieceType.king: p = "k"; break;
      case PieceType.missile: p = "m"; break;
    }
    return piece.color == PlayerColor.white ? p.toUpperCase() : p;
  }
}
