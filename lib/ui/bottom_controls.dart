import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BottomControls extends StatelessWidget {
  final VoidCallback? onDrawClaim;
  final bool canClaimDraw;
  final VoidCallback? onChat;
  final VoidCallback? onResign;
  final bool showChatBadge;

  const BottomControls({
    super.key,
    this.onDrawClaim,
    this.onChat,
    this.onResign,
    this.canClaimDraw = false,
    this.showChatBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Chat Button
          Stack(
            children: [
              _buildActionButton(Icons.chat_bubble_outline, onChat),
              if (showChatBadge)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                  ),
                ),
            ],
          ),
          
          const SizedBox(width: 20),
          
          // Draw Button
          _buildActionButton(
            Icons.handshake_outlined, 
            canClaimDraw ? onDrawClaim : null,
            isActive: canClaimDraw
          ),
          
          const SizedBox(width: 20),
          
          // Resign Button
          _buildActionButton(Icons.flag_outlined, onResign),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback? onPressed, {bool isActive = false}) {
    // Make non-active buttons slightly visible but clickable if onPressed is not null
    final isEnabled = onPressed != null;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFD4AF37) : (isEnabled ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.02)),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? Colors.transparent : Colors.white10,
          width: 1,
        ),
        boxShadow: isActive ? [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ] : [],
      ),
      child: IconButton(
        icon: Icon(icon, color: isActive ? Colors.black : Colors.white70, size: 24),
        onPressed: onPressed,
      ),
    );
  }
}

