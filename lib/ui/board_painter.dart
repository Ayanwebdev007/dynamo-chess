import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../core/models.dart';
import '../core/board.dart';

class BoardHighlightPainter extends CustomPainter {
  final DynamoBoard board;
  final Position? selectedPosition;
  // validMoves removed (moved to ForegroundPainter)
  final MoveRecord? lastMove;
  final Position? lastMoveStart;
  final Position? lastMoveEnd;
  final Position? checkPos;
  final bool isWhite;
  final bool showLastMove;

  BoardHighlightPainter({
    required this.board,
    this.selectedPosition,
    this.lastMove,
    this.lastMoveStart,
    this.lastMoveEnd,
    this.checkPos,
    this.isWhite = true,
    this.showLastMove = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final squareSize = size.width / 10;

    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 10; x++) {
        final drawX = isWhite ? x : 9 - x;
        final drawY = isWhite ? y : 9 - y;
        final rect = Rect.fromLTWH(drawX * squareSize, drawY * squareSize, squareSize, squareSize);
        final pos = Position(x, y);

        // --- BACKGROUND HIGHLIGHTS (Below Pieces) ---

        // Last Move Highlight
        bool isLastMove = false;
        if (lastMoveStart != null && lastMoveEnd != null) {
          isLastMove = (pos == lastMoveStart || pos == lastMoveEnd);
        } else if (lastMove != null) {
          isLastMove = (lastMove!.start == pos || lastMove!.end == pos);
        }
        if (isLastMove && showLastMove) {
          canvas.drawRect(rect, Paint()..color = const Color(0xFFF7F769).withOpacity(0.5)); // Yellowish
        }

        // Selection Highlight
        if (selectedPosition != null && selectedPosition == pos) {
          canvas.drawRect(rect, Paint()..color = const Color(0xFF64B5F6).withOpacity(0.6)); // Blueish
        }

        // Check Highlight
        if (checkPos != null && checkPos == pos) {
          canvas.drawRect(rect, Paint()..color = const Color(0xFFEF5350).withOpacity(0.6)); // Reddish
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BoardForegroundPainter extends CustomPainter {
  final DynamoBoard board;
  final List<Position> validMoves; // Only needed here
  final bool isWhite;

  BoardForegroundPainter({
    required this.board,
    this.validMoves = const [],
    this.isWhite = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final squareSize = size.width / 10;

    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 10; x++) {
        final drawX = isWhite ? x : 9 - x;
        final drawY = isWhite ? y : 9 - y;
        final rect = Rect.fromLTWH(drawX * squareSize, drawY * squareSize, squareSize, squareSize);
        final pos = Position(x, y);

        // --- FOREGROUND HINTS (Above Pieces) ---

        // Valid Move Hint
        if (validMoves.contains(pos)) {
          final isCapture = board.getPiece(pos) != null;
          
          if (isCapture) {
             // Ring for capture
             canvas.drawCircle(rect.center, squareSize * 0.4, 
                Paint()
                  ..color = Colors.black.withOpacity(0.3)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 4);
          } else {
             // Dot for move
             canvas.drawCircle(rect.center, squareSize * 0.15, 
                Paint()..color = Colors.black.withOpacity(0.2));
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
