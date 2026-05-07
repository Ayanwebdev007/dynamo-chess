import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/models.dart';

class PlayerProfileWidget extends StatelessWidget {
  final String name;
  final String flagAsset;
  final String avatarUrl;
  final String time;
  final bool isOpponent;
  final bool isActive;
  final List<PieceType>? capturedPieces;
  final int? scoreAdvantage;
  final PlayerColor capturedPiecesColor;

  const PlayerProfileWidget({
    super.key,
    required this.name,
    required this.flagAsset,
    required this.avatarUrl,
    required this.time,
    this.isOpponent = true,
    this.isActive = false,
    this.capturedPieces,
    this.scoreAdvantage,
    this.capturedPiecesColor = PlayerColor.black,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [
      // Avatar
      Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? const Color(0xFFD4AF37) : Colors.white12, 
                width: isActive ? 3 : 2
              ),
              color: const Color(0xFF2A2A2A),
              image: avatarUrl.isNotEmpty ? DecorationImage(
                image: NetworkImage(avatarUrl),
                fit: BoxFit.cover,
              ) : null,
              boxShadow: isActive ? [
                BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.5), blurRadius: 15, spreadRadius: 2),
              ] : [],
            ),
            child: avatarUrl.isEmpty ? Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : "?",
                style: GoogleFonts.cinzel(
                  color: Colors.white24,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ) : null,
          ),
          Positioned(
            right: -4,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10, width: 1),
              ),
              child: ClipOval(
                child: Image.asset(
                  flagAsset,
                  width: 16,
                  height: 16,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(width: 12),
      
      // Name and Timer
      Expanded(
        child: Column(
          crossAxisAlignment: isOpponent ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isActive ? Colors.white : Colors.white54,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFD4AF37).withOpacity(0.1) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? const Color(0xFFD4AF37).withOpacity(0.5) : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 12, color: isActive ? const Color(0xFFD4AF37) : Colors.white38),
                  const SizedBox(width: 6),
                  Text(
                    time,
                    style: GoogleFonts.robotoMono(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isActive ? const Color(0xFFD4AF37) : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            if (capturedPieces != null && capturedPieces!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var piece in capturedPieces!)
                      Image.asset(
                        'assets/pieces/${piece.toString().split('.').last}_${capturedPiecesColor == PlayerColor.white ? 'w' : 'b'}.png',
                        width: 14,
                        height: 14,
                      ),
                    if (scoreAdvantage != null && scoreAdvantage! > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          '+$scoreAdvantage',
                          style: GoogleFonts.montserrat(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];

    if (!isOpponent) {
      children = children.reversed.toList();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }
}

