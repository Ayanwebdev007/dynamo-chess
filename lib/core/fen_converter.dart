import '../core/models.dart';

class FenConverter {
  static String toFen(List<List<DynamoPiece?>> board, PlayerColor turn) {
    StringBuffer buffer = StringBuffer();
    
    for (int y = 0; y < 10; y++) {
      int emptyCount = 0;
      for (int x = 0; x < 10; x++) {
        final piece = board[y][x];
        if (piece == null) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            // Write empty squares. Split if > 9 to avoid ambiguity if we only parse 1 digit.
            // But since we are writing our own parser, we can handle '10'.
            // However, typical FEN parsers expect single digit.
            // Let's write '9' + '1' if it's 10.
            while (emptyCount > 9) {
               buffer.write('9');
               emptyCount -= 9;
            }
            buffer.write(emptyCount);
            emptyCount = 0;
          }
          buffer.write(_pieceToChar(piece));
        }
      }
      if (emptyCount > 0) {
        while (emptyCount > 9) {
           buffer.write('9');
           emptyCount -= 9;
        }
        buffer.write(emptyCount);
      }
      if (y < 9) {
        buffer.write('/');
      }
    }

    buffer.write(turn == PlayerColor.white ? ' w' : ' b');
    buffer.write(' - -'); 
    return buffer.toString();
  }

  static List<List<DynamoPiece?>> fromFen(String fen) {
    List<List<DynamoPiece?>> board = List.generate(
      10, 
      (i) => List.generate(10, (j) => null),
    );

    final parts = fen.split(' ');
    final rows = parts[0].split('/');

    for (int y = 0; y < rows.length && y < 10; y++) {
      final row = rows[y];
      int x = 0;
      for (int i = 0; i < row.length; i++) {
        final char = row[i];
        final digit = int.tryParse(char);
        
        if (digit != null) {
          x += digit;
        } else {
          if (x < 10) {
             board[y][x] = _charToPiece(char);
             x++;
          }
        }
      }
    }
    return board;
  }
  
  static PlayerColor getTurn(String fen) {
    final parts = fen.split(' ');
    if (parts.length > 1) {
      return parts[1] == 'w' ? PlayerColor.white : PlayerColor.black;
    }
    return PlayerColor.white;
  }

  static String _pieceToChar(DynamoPiece piece) {
    String char;
    switch (piece.type) {
      case PieceType.king: char = 'k'; break;
      case PieceType.queen: char = 'q'; break;
      case PieceType.rook: char = 'r'; break;
      case PieceType.bishop: char = 'b'; break;
      case PieceType.knight: char = 'n'; break;
      case PieceType.pawn: char = 'p'; break;
      case PieceType.missile: char = 'm'; break;
    }
    return piece.color == PlayerColor.white ? char.toUpperCase() : char;
  }

  static DynamoPiece _charToPiece(String char) {
    final isWhite = char == char.toUpperCase();
    final typeChar = char.toLowerCase();
    
    PieceType type;
    switch (typeChar) {
      case 'k': type = PieceType.king; break;
      case 'q': type = PieceType.queen; break;
      case 'r': type = PieceType.rook; break;
      case 'b': type = PieceType.bishop; break;
      case 'n': type = PieceType.knight; break;
      case 'p': type = PieceType.pawn; break;
      case 'm': type = PieceType.missile; break;
      default: type = PieceType.pawn;
    }
    return DynamoPiece(type: type, color: isWhite ? PlayerColor.white : PlayerColor.black);
  }
}
