import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/models.dart';
import 'board_screen.dart'; // Import for BoardScreen navigation
import 'online_menu.dart';
import 'platform_asset_image.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../core/auth_service.dart';
import '../core/online_service.dart';
import 'auth/login_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'invitation_dialog.dart';
import '../core/notification_service.dart';
import '../core/audio_service.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  GameSettings _selectedSettings = GameSettings.blitz3; // Default
  double _customTimeMinutes = 10.0;
  double _customIncrementSeconds = 0.0;
  bool _isVsComputer = false;
  User? _currentUser;
  late StreamSubscription<User?> _authSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _invitationListener;
  final OnlineService _onlineService = OnlineService();
  static final Set<String> _seenInviteIds = {}; // Persistent across menu rebuilds
  List<Map<String, dynamic>> _pendingInvites = [];

  @override
  void initState() {
    super.initState();
    _authSubscription = AuthService().authStateChanges.listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
        
        // Setup invitation listener when user logs in
        if (user != null) {
          _setupInvitationListener(user.uid);
        } else {
          _invitationListener?.cancel();
          _invitationListener = null;
        }
      }
    });
  }
  
  void _setupInvitationListener(String userId) {
    _invitationListener?.cancel();
    _invitationListener = _onlineService.listenForInvitations(userId).listen((invites) {
      if (mounted) {
        setState(() {
          _pendingInvites = invites;
        });
        
        final pending = invites.where((i) => i['status'] == 'pending').toList();
        
        if (pending.isNotEmpty) {
          final invite = pending.first;
          final inviteId = invite['id'] as String;
          
          // Only trigger if it's a new invite that hasn't been seen in this session
          if (!_seenInviteIds.contains(inviteId)) {
            _seenInviteIds.add(inviteId);
            
            // Limit set size to prevent memory leak
            if (_seenInviteIds.length > 50) _seenInviteIds.clear();
            
            // 1. Play Sound
            AudioService().playChallenge();
            
            // 2. Show Browser Notification
            NotificationService().showNotification(
              "Game Challenge!",
              "${invite['fromUserName']} has challenged you to a game!"
            );
            
            // 3. Show In-App Dialog
            _showInvitationDialog(invite);
          }
        }
      }
    });
  }
  
  void _showInvitationDialog(Map<String, dynamic> invite) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => InvitationDialog(
        fromUserName: invite['fromUserName'],
        timeControl: invite['timeControl'],
        onAccept: () async {
          try {
            Navigator.pop(context); // Close dialog
            final roomId = await _onlineService.acceptInvitation(invite['id']);
            
            // Navigate to game
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BoardScreen(
                  settings: GameSettings(timeLimit: Duration(seconds: invite['timeControl'] ?? 180)),
                  onlineRoomId: roomId,
                  onlineService: _onlineService,
                  isWhite: false, // Joiner is black
                ),
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error joining game: $e')),
            );
          }
        },
        onDecline: () async {
          await _onlineService.declineInvitation(invite['id']);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _invitationListener?.cancel();
    super.dispose();
  }

  void _updateCustomSettings() {
    _selectedSettings = GameSettings(
      timeLimit: Duration(minutes: _customTimeMinutes.toInt()),
      increment: Duration(seconds: _customIncrementSeconds.toInt()),
      isCustom: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A), // Deepest Dark
      body: Stack(
        children: [
          // Dynamic Animated Background
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(seconds: 8),
            builder: (context, value, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      0.3 * math.sin(value * 2 * math.pi),
                      -0.4 + 0.1 * math.cos(value * 2 * math.pi),
                    ),
                    radius: 1.5,
                    colors: const [
                      Color(0xFF1E3A20), // Dark Green Glow
                      Color(0xFF0A0E0A), // Black corners
                    ],
                  ),
                ),
              );
            },
          ),
          
          
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1200),
                  builder: (context, opacity, child) {
                    return Opacity(
                      opacity: opacity,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - opacity)),
                        child: child,
                      ),
                    );
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        // Logo
                        Hero(
                          tag: 'game_logo',
                          child: const SizedBox(
                            width: 100,
                            height: 100,
                            child: PlatformAssetImage(
                              assetPath: 'assets/dynamo_logo.png',
                              viewType: 'dynamo_logo',
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "DYNAMO CHESS",
                          style: GoogleFonts.cinzel(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFD4AF37),
                            letterSpacing: 4.0,
                            shadows: [
                              BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 15, offset: const Offset(0, 4)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "STRATEGY REIMAGINED",
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: Colors.white60,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 6.0,
                          ),
                        ),
                        const SizedBox(height: 50),

                        // Section: Game Mode
                        _buildSectionHeader("SELECT MISSION"),
                        const SizedBox(height: 16),
                        _buildGlassModeButton("PLAYER VS PLAYER", Icons.person_outline, !_isVsComputer, () {
                          setState(() => _isVsComputer = false);
                        }),
                        const SizedBox(height: 12),
                        _buildGlassModeButton("PLAY WITH AI", Icons.smart_toy_outlined, _isVsComputer, () {
                          setState(() => _isVsComputer = true);
                        }),
                        const SizedBox(height: 12),
                        _buildGlassModeButton(
                          _currentUser == null ? "LOGIN TO PLAY ONLINE" : "PLAY ONLINE", 
                          Icons.public, 
                          false, 
                          () {
                           if (_currentUser == null) {
                             Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                           } else {
                             Navigator.push(
                               context, 
                               MaterialPageRoute(builder: (context) => const OnlineMenuScreen()),
                             );
                           }
                        }),
                        
                        const SizedBox(height: 40),

                        // Section: Time Control
                        _buildSectionHeader("TIME CONTROL"),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildTimeChip("BULLET", GameSettings.bullet1, "1 min"),
                            _buildTimeChip("BULLET", GameSettings.bullet2_1, "2+1"),
                            _buildTimeChip("BLITZ", GameSettings.blitz3, "3 min"),
                            _buildTimeChip("BLITZ", GameSettings.blitz5, "5 min"),
                            _buildTimeChip("RAPID", GameSettings.rapid10, "10 min"),
                            _buildCustomChip(),
                          ],
                        ),
                        
                        if (_selectedSettings.isCustom) ...[
                          const SizedBox(height: 24),
                          _buildSettingsSlider("TIME", "${_customTimeMinutes.toInt()} min", _customTimeMinutes, 1, 60, (val) {
                            setState(() {
                              _customTimeMinutes = val;
                              _updateCustomSettings();
                            });
                          }),
                          const SizedBox(height: 12),
                          _buildSettingsSlider("INCREMENT", "${_customIncrementSeconds.toInt()} sec", _customIncrementSeconds, 0, 60, (val) {
                            setState(() {
                              _customIncrementSeconds = val;
                              _updateCustomSettings();
                            });
                          }),
                        ],

                        const SizedBox(height: 30),

                        // Start Button
                        Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD4AF37), Color(0xFFC5A028)], // Gold Gradient
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD4AF37).withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BoardScreen(
                                    settings: _selectedSettings,
                                    isVsComputer: _isVsComputer,
                                    aiDifficulty: 1, // Always easy
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            child: Text(
                              "START MATCH",
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Icons Area (Top Left & Top Right) - Moved to top of Stack for touch priority
          Positioned(
            top: 20, // Adjusted for mobile SafeArea
            left: 16,
            right: 16,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Profile Icon (Top Left)
                  InkWell(
                    onTap: () {
                      if (_currentUser == null) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5), width: 1.5),
                      ),
                      child: _currentUser != null
                          ? CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFD4AF37),
                              child: Text(
                                _currentUser!.displayName?.substring(0, 1).toUpperCase() ?? "U",
                                style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            )
                          : const CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white10,
                              child: Icon(Icons.person_outline, color: Colors.white70, size: 20),
                            ),
                    ),
                  ),
                  
                  // Top Right Icons
                  Row(
                    children: [
                      _buildNotificationBell(),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white70, size: 28),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfile() {
    if (_currentUser == null) {
      return InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.login, color: Color(0xFFD4AF37), size: 20),
              const SizedBox(width: 10),
              Text(
                "LOGIN / SIGN UP",
                style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFD4AF37),
              radius: 20,
              child: Text(
                _currentUser!.displayName?.substring(0, 1).toUpperCase() ?? "U",
                style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentUser!.displayName ?? "Player",
                    style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    "Online Status: Active",
                    style: GoogleFonts.montserrat(color: Colors.greenAccent, fontSize: 10),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white54),
              onPressed: () {
                AuthService().signOut();
              },
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.1), endIndent: 12)),
        Text(
          title,
          style: GoogleFonts.montserrat(
            color: const Color(0xFFD4AF37).withOpacity(0.8),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.0,
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.1), indent: 12)),
      ],
    );
  }

  Widget _buildGlassModeButton(String label, IconData icon, bool isSelected, void Function() onTap) {
    final color = isSelected ? const Color(0xFFD4AF37) : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(
            colors: [
              const Color(0xFFD4AF37).withOpacity(0.2),
              const Color(0xFFD4AF37).withOpacity(0.05),
            ],
          ) : null,
          color: isSelected ? null : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.5) : Colors.white10,
            width: 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFFD4AF37).withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFD4AF37) : Colors.white54, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.montserrat(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              const Icon(Icons.chevron_right, color: Color(0xFFD4AF37), size: 18),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(String category, GameSettings settings, String label) {
    final isSelected = !_selectedSettings.isCustom && _selectedSettings == settings;
    return InkWell(
      onTap: () => setState(() => _selectedSettings = settings),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37) : Colors.white12,
            width: 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))
          ] : [],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.montserrat(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Text(
              category,
              style: GoogleFonts.montserrat(
                color: isSelected ? Colors.black54 : Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomChip() {
    final isSelected = _selectedSettings.isCustom;
    return InkWell(
      onTap: () => setState(() => _updateCustomSettings()),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37) : Colors.white12,
            width: 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))
          ] : [],
        ),
        child: Column(
          children: [
            Text(
              "CUSTOM",
              style: GoogleFonts.montserrat(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
             Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Icon(Icons.tune, size: 10, color: isSelected ? Colors.black54 : Colors.white38),
                 const SizedBox(width: 4),
                 Text(
                   "SETUP",
                   style: GoogleFonts.montserrat(
                     color: isSelected ? Colors.black54 : Colors.white38,
                     fontSize: 9,
                     fontWeight: FontWeight.w600,
                   ),
                 ),
               ],
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSlider(String label, String value, double current, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            Text(value, style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFFD4AF37),
            inactiveTrackColor: Colors.white12,
            thumbColor: const Color(0xFFD4AF37),
            overlayColor: const Color(0xFFD4AF37).withOpacity(0.2),
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: current,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationBell() {
    final pendingCount = _pendingInvites.where((i) => i['status'] == 'pending').length;
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.white70, size: 28),
          onPressed: _showNotificationHistory,
        ),
        if (pendingCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                '$pendingCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _showNotificationHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.5))),
        title: Row(
          children: [
            const Icon(Icons.history, color: Color(0xFFD4AF37)),
            const SizedBox(width: 12),
            Text("Notification History", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _pendingInvites.isEmpty 
            ? Center(child: Text("No notifications yet", style: GoogleFonts.montserrat(color: Colors.white38)))
            : ListView.separated(
                itemCount: _pendingInvites.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                itemBuilder: (context, index) {
                  final invite = _pendingInvites[index];
                  final status = invite['status'];
                  final isPending = status == 'pending';
                  
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      invite['fromUserName'],
                      style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isPending ? "Challenged you" : "Challenge $status",
                      style: GoogleFonts.montserrat(color: isPending ? const Color(0xFFD4AF37) : Colors.white38, fontSize: 12),
                    ),
                    trailing: isPending 
                      ? ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showInvitationDialog(invite);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(60, 30),
                          ),
                          child: const Text("VIEW", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      : Text(
                          status.toUpperCase(),
                          style: GoogleFonts.robotoMono(color: Colors.white24, fontSize: 10),
                        ),
                  );
                },
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CLOSE", style: GoogleFonts.montserrat(color: Colors.white54)),
          )
        ],
      ),
    );
  }
}
