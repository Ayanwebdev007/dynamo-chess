import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/models.dart';
import 'board_screen.dart';
import 'online_menu.dart';
import 'platform_asset_image.dart';
import 'puzzle/puzzle_list_screen.dart';
import 'saved_positions_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../core/auth_service.dart';
import '../core/online_service.dart';
import 'auth/login_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'invitation_dialog.dart';
import '../core/notification_service.dart';
import '../core/audio_service.dart';
import 'ruleset_screen.dart';
import 'tournament_list_screen.dart';
import 'store_screen.dart';
import '../core/navigation_helper.dart';
import 'package:url_launcher/url_launcher.dart';


enum ColorSelection { white, black, random, alternate }

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {

  GameSettings _selectedSettings = GameSettings.blitz3;
  double _customTimeMinutes = 10.0;
  double _customIncrementSeconds = 0.0;
  bool _isVsComputer = false;
  ColorSelection _selectedColor = ColorSelection.white;
  bool _lastPlayedWasWhite = false;
  User? _currentUser;
  late StreamSubscription<User?> _authSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _invitationListener;
  final OnlineService _onlineService = OnlineService();
  static final Set<String> _seenInviteIds = {};
  List<Map<String, dynamic>> _pendingInvites = [];
  
  @override
  void initState() {
    super.initState();
    _authSubscription = AuthService().authStateChanges.listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
        if (user != null) {
          _setupInvitationListener(user.uid);
          NotificationService().saveTokenForUser(user.uid);
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
          if (!_seenInviteIds.contains(inviteId)) {
            _seenInviteIds.add(inviteId);
            if (_seenInviteIds.length > 50) _seenInviteIds.clear();
            AudioService().playChallenge();
            NotificationService().showNotification(
              "Game Challenge!",
              "${invite['fromUserName']} has challenged you to a game!"
            );
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
            Navigator.pop(context);
            final roomId = await _onlineService.acceptInvitation(invite['id']);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BoardScreen(
                  settings: GameSettings(timeLimit: Duration(seconds: invite['timeControl'] ?? 180)),
                  onlineRoomId: roomId,
                  onlineService: _onlineService,
                  isWhite: false,
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
      backgroundColor: const Color(0xFF0A0E0A),
      body: _buildResponsiveLayout(),
    );
  }

  Widget _buildResponsiveLayout() {
    return Stack(
      children: [
          // Background Animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(seconds: 10),
            builder: (context, value, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      0.4 * math.sin(value * 2 * math.pi),
                      -0.3 + 0.2 * math.cos(value * 2 * math.pi),
                    ),
                    radius: 2.0,
                    colors: const [
                      Color(0xFF142B16),
                      Color(0xFF0A0E0A),
                    ],
                  ),
                ),
              );
            },
          ),

          LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth > 1000;
              
              if (isWide) {
                return _buildDesktopDashboard(constraints);
              } else {
                return _buildMobileLayout(constraints);
              }
            },
          ),

          Builder(
            builder: (context) {
              final bool isWideScreen = MediaQuery.of(context).size.width > 1000;
              return Positioned(
                top: isWideScreen ? 24 : 12,
                left: isWideScreen ? 24 : 12,
                right: isWideScreen ? 24 : 12,
                child: SafeArea(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: math.max(320.0, MediaQuery.of(context).size.width - (isWideScreen ? 48 : 24)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _buildProfileAvatar(),
                              SizedBox(width: isWideScreen ? 8 : 4),
                              IconButton(
                                icon: Icon(Icons.help_outline, color: const Color(0xFFD4AF37), size: isWideScreen ? 28 : 24),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RulesetScreen())),
                                tooltip: "How to Play / Rules",
                              ),
                              SizedBox(width: isWideScreen ? 4 : 2),
                              IconButton(
                                icon: Icon(Icons.storefront, color: const Color(0xFFD4AF37), size: isWideScreen ? 28 : 24),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StoreScreen())),
                                tooltip: "Store",
                              ),
                              SizedBox(width: isWideScreen ? 4 : 2),
                              IconButton(
                                icon: Icon(Icons.bookmark_outline, color: const Color(0xFFD4AF37), size: isWideScreen ? 28 : 24),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedPositionsScreen())),
                                tooltip: "Saved Positions",
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildNotificationBell(),
                              SizedBox(width: isWideScreen ? 8 : 4),
                              IconButton(
                                icon: Icon(Icons.settings, color: Colors.white70, size: isWideScreen ? 28 : 24),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
  }

  Widget _buildDesktopDashboard(BoxConstraints constraints) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1100),
        height: constraints.maxHeight * 0.8,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Row(
          children: [
            // Left: Hero Section
            Expanded(
              flex: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'game_logo',
                    child: SizedBox(
                      width: 140,
                      height: 140,
                      child: const PlatformAssetImage(
                        assetPath: 'assets/dynamo_logo.png',
                        viewType: 'dynamo_logo',
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "DYNAMO\nCHESS",
                    style: GoogleFonts.cinzel(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFD4AF37),
                      height: 1.0,
                      letterSpacing: 10.0,
                      shadows: [
                        BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 10)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 100,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "STRATEGY REIMAGINED.\nEXPERIENCE THE ELITE STANDARD.",
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      color: Colors.white38,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 4.0,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 36),
                  _buildGooglePlayBadge(),
                ],
              ),
            ),

            const SizedBox(width: 60),

            // Right: Selection Panel
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                clipBehavior: Clip.antiAlias,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("SELECT GAME MODE"),
                        const SizedBox(height: 24),
                         Row(
                          children: [
                            Expanded(
                              child: _buildGlassModeButton(
                                _currentUser == null ? "LOGIN TO ONLINE" : "ONLINE", 
                                Icons.public, 
                                false, 
                                () {
                                  if (_currentUser == null) {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                                  } else {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const OnlineMenuScreen()));
                                  }
                                }
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(child: _buildGlassModeButton("OFFLINE", Icons.person_outline, !_isVsComputer, () => setState(() => _isVsComputer = false))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildGlassModeButton("WITH AI", Icons.smart_toy_outlined, _isVsComputer, () => setState(() => _isVsComputer = true))),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildGlassModeButton(
                                "PUZZLES", 
                                Icons.extension_outlined, 
                                false, 
                                () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PuzzleListScreen()))
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: FractionallySizedBox(
                            widthFactor: 0.6,
                            child: _buildGlassModeButton(
                              "TOURNAMENT", 
                              Icons.emoji_events_outlined, 
                              false, 
                              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TournamentListScreen())),
                              centerContent: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),

                        _buildSectionHeader("TIME CONTROL"),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildTimeChip("BULLET", GameSettings.bullet1, "1m"),
                            _buildTimeChip("BULLET", GameSettings.bullet2_1, "2+1"),
                            _buildTimeChip("BLITZ", GameSettings.blitz3, "3m"),
                            _buildTimeChip("BLITZ", GameSettings.blitz5, "5m"),
                            _buildTimeChip("RAPID", GameSettings.rapid10, "10m"),
                            _buildCustomChip(),
                          ],
                        ),
                        if (_selectedSettings.isCustom) ...[
                          const SizedBox(height: 32),
                          _buildSettingsSlider("TIME", "${_customTimeMinutes.toInt()} min", _customTimeMinutes, 1, 60, (val) {
                            setState(() {
                              _customTimeMinutes = val;
                              _updateCustomSettings();
                            });
                          }),
                          const SizedBox(height: 16),
                          _buildSettingsSlider("INCREMENT", "${_customIncrementSeconds.toInt()} sec", _customIncrementSeconds, 0, 60, (val) {
                            setState(() {
                              _customIncrementSeconds = val;
                              _updateCustomSettings();
                            });
                          }),
                        ],
                        const SizedBox(height: 48),
                        _buildStartButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BoxConstraints constraints) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
          child: Column(
            children: [
              Hero(
                tag: 'game_logo',
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: const PlatformAssetImage(
                    assetPath: 'assets/dynamo_logo.png',
                    viewType: 'dynamo_logo',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "DYNAMO CHESS",
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: GoogleFonts.cinzel(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFD4AF37),
                    letterSpacing: 4.0,
                  ),
                ),
              ),
              const SizedBox(height: 60),
              _buildSectionHeader("SELECT GAME MODE"),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildGlassModeButton(
                      "ONLINE", 
                      Icons.public, 
                      false, 
                      () {
                        if (_currentUser == null) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const OnlineMenuScreen()));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildGlassModeButton("OFFLINE", Icons.person_outline, !_isVsComputer, () => setState(() => _isVsComputer = false)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildGlassModeButton("WITH AI", Icons.smart_toy_outlined, _isVsComputer, () => setState(() => _isVsComputer = true)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildGlassModeButton(
                      "PUZZLES", 
                      Icons.extension_outlined, 
                      false, 
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PuzzleListScreen()))
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: FractionallySizedBox(
                  widthFactor: 0.6,
                  child: _buildGlassModeButton(
                    "TOURNAMENT", 
                    Icons.emoji_events_outlined, 
                    false, 
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TournamentListScreen())),
                    centerContent: true,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              _buildSectionHeader("TIME CONTROL"),
              const SizedBox(height: 16),
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
              const SizedBox(height: 40),
              _buildStartButton(),
            ],
          ),
        ),
      ),
    );
  }

  void _openPlayStore() {
    openExternalUrl('https://play.google.com/store/apps/details?id=in.advancedchess');
  }

  Widget _buildGooglePlayBadge() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openPlayStore,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Image.asset(
              'assets/google_play_badge.png',
              height: 60,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFC5A028)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => _showMatchSetupDialog(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        ),
        child: Text(
          "START MATCH",
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }

  void _showMatchSetupDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF141914),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
          ),
          title: Text(
            "MATCH SETUP",
            style: GoogleFonts.cinzel(
              color: const Color(0xFFD4AF37),
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isVsComputer ? "VS DYNAMO AI" : "LOCAL OFFLINE MATCH",
                style: GoogleFonts.montserrat(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                "${_selectedSettings.timeLimit.inMinutes} MIN (${_selectedSettings.increment.inSeconds}s inc)",
                style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontSize: 11),
              ),
              const SizedBox(height: 24),
              Text(
                "CHOOSE YOUR COLOR",
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildModalColorChoice("WHITE", Icons.wb_sunny_outlined, ColorSelection.white, setModalState),
                  _buildModalColorChoice("BLACK", Icons.nightlight_round, ColorSelection.black, setModalState),
                  _buildModalColorChoice("RANDOM", Icons.shuffle, ColorSelection.random, setModalState),
                ],
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);

                bool chosenIsWhite = true;
                if (_selectedColor == ColorSelection.white) {
                  chosenIsWhite = true;
                } else if (_selectedColor == ColorSelection.black) {
                  chosenIsWhite = false;
                } else if (_selectedColor == ColorSelection.random) {
                  chosenIsWhite = math.Random().nextBool();
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BoardScreen(
                      settings: _selectedSettings,
                      isVsComputer: _isVsComputer,
                      aiDifficulty: 1,
                      isWhite: chosenIsWhite,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              child: Text(
                "PLAY MATCH ➔",
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalColorChoice(String label, IconData icon, ColorSelection choice, StateSetter setModalState) {
    final isSelected = _selectedColor == choice;
    return InkWell(
      onTap: () {
        setState(() => _selectedColor = choice);
        setModalState(() {});
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 65,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37) : Colors.white10,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? Colors.black : Colors.white70,
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: GoogleFonts.montserrat(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return InkWell(
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
                radius: 20,
                backgroundColor: const Color(0xFFD4AF37),
                child: Text(
                  _currentUser!.displayName?.substring(0, 1).toUpperCase() ?? "U",
                  style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              )
            : const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white10,
                child: Icon(Icons.person_outline, color: Colors.white70, size: 24),
              ),
      ),
    );
  }



  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            color: const Color(0xFFD4AF37),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.0,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
      ],
    );
  }

  Widget _buildGlassModeButton(String label, IconData icon, bool isSelected, void Function() onTap, {bool centerContent = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.1) : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.5) : Colors.white10,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: centerContent ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            if (!centerContent || !isSelected) ...[
              Icon(icon, color: isSelected ? const Color(0xFFD4AF37) : Colors.white38, size: 20),
              const SizedBox(width: 8),
            ],
            if (centerContent && isSelected) ...[
              const Icon(Icons.check_circle, color: Color(0xFFD4AF37), size: 16),
              const SizedBox(width: 8),
            ],
            if (centerContent)
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: GoogleFonts.montserrat(
                      color: isSelected ? Colors.white : Colors.white38,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: GoogleFonts.montserrat(
                      color: isSelected ? Colors.white : Colors.white38,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            if (!centerContent && isSelected) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_circle, color: Color(0xFFD4AF37), size: 16),
            ],
            if (centerContent && !isSelected) ...[
              const SizedBox(width: 8),
              Icon(icon, color: Colors.transparent, size: 20), // Balance visual weight
            ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(minWidth: 70),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37) : Colors.white10,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.montserrat(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              category,
              style: GoogleFonts.montserrat(
                color: isSelected ? Colors.black54 : Colors.white30,
                fontSize: 8,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(minWidth: 70),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37) : Colors.white10,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              "CUSTOM",
              style: GoogleFonts.montserrat(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Icon(Icons.tune, size: 10, color: isSelected ? Colors.black54 : Colors.white30),
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
            Text(label, style: GoogleFonts.montserrat(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            Text(value, style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFFD4AF37),
            inactiveTrackColor: Colors.white10,
            thumbColor: const Color(0xFFD4AF37),
            trackHeight: 2,
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
              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$pendingCount',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
            Text("Notifications", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 300,
          child: _pendingInvites.isEmpty 
            ? Center(child: Text("No notifications", style: GoogleFonts.montserrat(color: Colors.white38)))
            : ListView.separated(
                itemCount: _pendingInvites.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                itemBuilder: (context, index) {
                  final invite = _pendingInvites[index];
                  final status = invite['status'];
                  final isPending = status == 'pending';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(invite['fromUserName'], style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(isPending ? "Challenged you" : "Challenge $status", style: GoogleFonts.montserrat(color: isPending ? const Color(0xFFD4AF37) : Colors.white38, fontSize: 12)),
                    trailing: isPending 
                      ? ElevatedButton(
                          onPressed: () { Navigator.pop(context); _showInvitationDialog(invite); },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), minimumSize: const Size(60, 30)),
                          child: const Text("VIEW", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      : Text(status.toUpperCase(), style: GoogleFonts.robotoMono(color: Colors.white24, fontSize: 10)),
                  );
                },
              ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("CLOSE", style: GoogleFonts.montserrat(color: Colors.white54)))],
      ),
    );
  }
}
