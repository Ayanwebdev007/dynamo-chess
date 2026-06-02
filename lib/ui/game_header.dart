import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/models.dart';
import 'platform_asset_image.dart';

class GameHeader extends StatelessWidget implements PreferredSizeWidget {
  final GameSettings settings;
  
  const GameHeader({
    super.key,
    this.settings = GameSettings.blitz3,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF0F150F), // Darker, matching menu
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: 'game_logo',
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: PlatformAssetImage(
                    assetPath: 'assets/dynamo_logo.png',
                    viewType: 'dynamo_logo',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "DYNAMO CHESS",
                style: GoogleFonts.cinzel(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold, 
                  color: const Color(0xFFD4AF37),
                  letterSpacing: 2.0
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getSettingsLabel(),
                  style: GoogleFonts.montserrat(
                    fontSize: 10, 
                    color: Colors.white70, 
                    letterSpacing: 1.0, 
                    fontWeight: FontWeight.w600
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.verified, color: Colors.blueAccent, size: 10),
              ],
            ),
          ),
        ],
      ),
      actions: const [
        SizedBox(width: 48), // Spacer to keep title centered
      ],
    );
  }

  String _getSettingsLabel() {
    String label = "${settings.timeLimit.inMinutes} MIN";
    if (settings.increment.inSeconds > 0) {
      label += " + ${settings.increment.inSeconds}";
    }
    return label;
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);
}
