import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InvitationDialog extends StatelessWidget {
  final String fromUserName;
  final int timeControl;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const InvitationDialog({
    super.key,
    required this.fromUserName,
    required this.timeControl,
    required this.onAccept,
    required this.onDecline,
  });

  String get _timeControlLabel {
    if (timeControl == 60) return 'Bullet (1 min)';
    if (timeControl == 180) return 'Blitz (3 min)';
    if (timeControl == 600) return 'Rapid (10 min)';
    return '$timeControl seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD4AF37), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events,
                color: Color(0xFFD4AF37),
                size: 48,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Title
            Text(
              'Game Challenge!',
              style: GoogleFonts.cinzel(
                color: const Color(0xFFD4AF37),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Message
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16),
                children: [
                  TextSpan(
                    text: fromUserName,
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(text: ' challenges you to a game!'),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Time Control
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, color: Color(0xFFD4AF37), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _timeControlLabel,
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.white38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Decline',
                      style: GoogleFonts.montserrat(
                        color: Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Accept',
                      style: GoogleFonts.montserrat(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
