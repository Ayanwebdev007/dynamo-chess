import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsController _settings = SettingsController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.4),
                radius: 1.2,
                colors: [
                  Color(0xFF1E3A20),
                  Color(0xFF0A0E0A),
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Text(
                            "SETTINGS",
                            style: GoogleFonts.cinzel(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFD4AF37),
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Settings List
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        children: [
                          _buildSettingsSection("AUDIO"),
                          _buildSettingsTile(
                            "Sound Effects",
                            "Play sounds during moves and captures",
                            Icons.volume_up,
                            _settings.isSoundEnabled,
                            (value) => setState(() => _settings.toggleSound(value)),
                          ),
                          
                          const SizedBox(height: 24),
                          _buildSettingsSection("GAMEPLAY"),
                          _buildSettingsTile(
                            "Highlight Legal Moves",
                            "Show available squares for selected piece",
                            Icons.tips_and_updates_outlined,
                            _settings.showLegalMoves,
                            (value) => setState(() => _settings.toggleLegalMoves(value)),
                          ),
                          _buildSettingsTile(
                            "Show Last Move",
                            "Highlight opponent's previous move",
                            Icons.history,
                            _settings.showLastMove,
                            (value) => setState(() => _settings.toggleLastMove(value)),
                          ),
                          _buildSettingsTile(
                            "Auto-Promote to Queen",
                            "Save time by bypassing piece selection",
                            Icons.auto_awesome,
                            _settings.autoPromote,
                            (value) => setState(() => _settings.toggleAutoPromote(value)),
                          ),
                          
                          const SizedBox(height: 24),
                          _buildSettingsSection("VISUALS"),
                          _buildSettingsTile(
                            "Show Coordinates",
                            "Display board letters and numbers",
                            Icons.grid_4x4,
                            _settings.showCoordinates,
                            (value) => setState(() => _settings.toggleCoordinates(value)),
                          ),
                          
                          const SizedBox(height: 12),
                          _buildThemeSelector(),
                          
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          color: const Color(0xFFD4AF37).withOpacity(0.7),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(String title, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFD4AF37), size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.montserrat(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFFD4AF37),
          activeTrackColor: const Color(0xFFD4AF37).withOpacity(0.3),
          inactiveThumbColor: Colors.white24,
          inactiveTrackColor: Colors.white10,
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.montserrat(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector() {
    final themes = [
      {'id': 'onyx', 'name': 'Onyx', 'color': const Color(0xFF0A0E0A)},
      {'id': 'classic', 'name': 'Classic', 'color': const Color(0xFF2E5A27)},
      {'id': 'wood', 'name': 'Wood', 'color': const Color(0xFF5D4037)},
      {'id': 'emerald', 'name': 'Emerald', 'color': const Color(0xFF004D40)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            "BOARD THEME",
            style: GoogleFonts.montserrat(
              color: const Color(0xFFD4AF37).withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: themes.map((theme) {
            bool isSelected = _settings.boardTheme == theme['id'];
            return GestureDetector(
              onTap: () => setState(() => _settings.setBoardTheme(theme['id'] as String)),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: theme['color'] as Color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFD4AF37) : Colors.white10,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.3), blurRadius: 10)
                      ] : [],
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Color(0xFFD4AF37)) : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    theme['name'] as String,
                    style: GoogleFonts.montserrat(
                      color: isSelected ? const Color(0xFFD4AF37) : Colors.white54,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
