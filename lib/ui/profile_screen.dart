import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/online_service.dart';
import 'auth/login_screen.dart';
import 'game_review_screen.dart';
import 'full_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? targetUserId;
  final String? targetPlayerName;

  const ProfileScreen({
    super.key,
    this.targetUserId,
    this.targetPlayerName,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _gameHistory = [];
  bool _isLoading = true;
  final OnlineService _onlineService = OnlineService();

  String _getRankName(int rating) {
    if (rating < 1100) return 'NOVICE';
    if (rating < 1400) return 'WARRIOR';
    if (rating < 1800) return 'MASTER';
    if (rating < 2200) return 'GRANDMASTER';
    return 'DYNAMO LEGEND';
  }

  Color _getRankColor(int rating) {
    if (rating < 1100) return Colors.grey;
    if (rating < 1400) return Colors.greenAccent;
    if (rating < 1800) return Colors.blueAccent;
    if (rating < 2200) return Colors.deepPurpleAccent;
    return const Color(0xFFD4AF37); // Gold
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = widget.targetUserId ?? user?.uid;
    
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final stats = await _onlineService.getUserStats(uid);
      final history = await _onlineService.getGameHistory(uid, limit: 100);
      
      setState(() {
        _stats = stats;
        _gameHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading profile: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(int timestamp) {
    if (timestamp == 0) return 'Unknown';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.5,
            colors: [
              Color(0xFF1E3A20),
              Color(0xFF0A0E0A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'PROFILE',
                      style: GoogleFonts.cinzel(
                        color: const Color(0xFFD4AF37),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: user == null
                    ? _buildLoginPrompt()
                    : _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                        : _buildProfileContent(user),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline, size: 64, color: Color(0xFFD4AF37)),
            const SizedBox(height: 20),
            Text(
              'Login Required',
              style: GoogleFonts.cinzel(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please log in to view your profile and game history.',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text('LOGIN', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveCard(User user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD4AF37), // Primary Gold
            Color(0xFFF3E5AB), // Light Gold
            Color(0xFFB8860B), // Dark Gold
            Color(0xFFD4AF37), // Back to Gold
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white30, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DYNAMO CHESS',
                style: GoogleFonts.cinzel(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: 3,
                ),
              ),
              const Icon(Icons.shield, color: Colors.black, size: 32),
            ],
          ),
          const SizedBox(height: 50),
          Text(
            user.displayName?.toUpperCase() ?? 'UNKNOWN PLAYER',
            style: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: 2,
            ),
          ),
          Text(
            _getRankName(_stats['rating'] ?? 1200),
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MEMBER SINCE',
                    style: GoogleFonts.montserrat(fontSize: 10, color: Colors.black54, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '2026', 
                    style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'ELO RATING',
                    style: GoogleFonts.montserrat(fontSize: 12, color: Colors.black54, letterSpacing: 2, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_stats['rating'] ?? 1200}',
                    style: GoogleFonts.cinzel(fontSize: 44, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(User user) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // The Executive Card
            _buildExecutiveCard(user),

            const SizedBox(height: 40),

            // Statistics (Borderless)
            _buildExecutiveStats(),

            const SizedBox(height: 40),

            // Match History
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _gameHistory.isEmpty ? 'ACTIVITY LOG' : 'ACTIVITY LOG (${_gameHistory.length})',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD4AF37),
                    letterSpacing: 3,
                  ),
                ),
                if (_gameHistory.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      final uid = widget.targetUserId ?? user.uid;
                      final name = widget.targetPlayerName ?? user.displayName;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullHistoryScreen(
                            userId: uid,
                            playerName: name,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history, color: Color(0xFFD4AF37), size: 16),
                    label: Text(
                      'VIEW ALL',
                      style: GoogleFonts.montserrat(
                        color: const Color(0xFFD4AF37),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildExecutiveHistory(user),

            const SizedBox(height: 40),

            // Settings
            _buildExecutiveSettings(user),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveStats() {
    final totalGames = _stats['totalGames'] ?? 0;
    final wins = _stats['wins'] ?? 0;
    final losses = _stats['losses'] ?? 0;
    final winRate = totalGames > 0 ? (wins / totalGames) : 0.0;
    final winRateText = (winRate * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('GAMES', totalGames.toString(), Icons.sports_esports),
          _buildStatItem('WINS', wins.toString(), Icons.emoji_events),
          _buildStatItem('LOSSES', losses.toString(), Icons.close),
          _buildWinRateItem(winRate, winRateText),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFD4AF37), size: 28),
        const SizedBox(height: 12),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildWinRateItem(double value, String text) {
    return Column(
      children: [
        SizedBox(
          width: 32, height: 32,
          child: CircularProgressIndicator(
            value: value,
            backgroundColor: Colors.white10,
            color: const Color(0xFFD4AF37),
            strokeWidth: 3.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '$text%',
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'WIN RATE',
          style: GoogleFonts.montserrat(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildExecutiveHistory(User user) {
    if (_gameHistory.isEmpty) {
      return Center(
        child: Text(
          'NO MATCH DATA RECORDED',
          style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white24, letterSpacing: 2),
        ),
      );
    }

    final recentGames = _gameHistory.take(7).toList();

    return Column(
      children: [
        ...recentGames.map((game) {
          final isLast = recentGames.indexOf(game) == recentGames.length - 1;
          return _buildExecutiveHistoryRow(game, isLast: isLast);
        }).toList(),
        if (_gameHistory.length > 7) ...[
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              final uid = widget.targetUserId ?? user.uid;
              final name = widget.targetPlayerName ?? user.displayName;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullHistoryScreen(
                    userId: uid,
                    playerName: name,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'VIEW ALL ${_gameHistory.length} MATCHES',
                    style: GoogleFonts.montserrat(
                      color: const Color(0xFFD4AF37),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, color: Color(0xFFD4AF37), size: 14),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExecutiveHistoryRow(Map<String, dynamic> game, {required bool isLast}) {
    final result = game['result'] as String;
    final opponent = game['opponent'] as String;
    final timestamp = game['finishedAt'] as int;
    final method = game['method'] as String;
    
    final resultColor = result == 'win' ? const Color(0xFFD4AF37) : (result == 'loss' ? const Color(0xFFDC143C) : Colors.white54);
    final resultText = result.toUpperCase().substring(0, 1);

    return InkWell(
      onTap: () => _showGameDetailsDialog(game),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white10, width: isLast ? 0 : 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: resultColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: resultColor.withOpacity(0.3)),
              ),
              child: Text(
                resultText,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: resultColor,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opponent.toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '${_formatDate(timestamp).toUpperCase()} • $method',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      color: Colors.white38,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (result == 'win' && method.toLowerCase() == 'capture')
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.rocket_launch, color: Color(0xFFD4AF37), size: 14),
              ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 12),
          ],
        ),
      ),
    );
  }

  void _showGameDetailsDialog(Map<String, dynamic> game) {
    final result = game['result'] as String;
    final opponent = game['opponent'] as String;
    final method = game['method'] as String;
    final color = game['myColor'] as String;
    final opponentRating = game['opponentRating'] ?? 1200;
    final timestamp = game['finishedAt'] as int;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0E0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
        ),
        title: Text(
          'MATCH SUMMARY',
          textAlign: TextAlign.center,
          style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('RESULT', result.toUpperCase(), valueColor: result == 'win' ? const Color(0xFFD4AF37) : Colors.red),
            const Divider(color: Colors.white10),
            _buildDetailRow('OPPONENT', opponent),
            _buildDetailRow('RANK', _getRankName(opponentRating)),
            _buildDetailRow('RATING', opponentRating.toString()),
            const Divider(color: Colors.white10),
            _buildDetailRow('METHOD', method.toUpperCase()),
            _buildDetailRow('YOUR COLOR', color.toUpperCase()),
            _buildDetailRow('DATE', _formatDate(timestamp)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => GameReviewScreen(
                    gameData: game, 
                    opponentName: opponent, 
                    myColor: color
                  )
                )
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('MATCH REVIEW', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE', style: GoogleFonts.montserrat(color: Colors.white54, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color valueColor = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(fontSize: 12, color: valueColor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveSettings(User user) {
    return Column(
      children: [
        _buildSettingsAction('EDIT PROFILE', Icons.edit, () => _showEditProfileDialog(user)),
        const SizedBox(height: 12),
        _buildSettingsAction('SIGN OUT', Icons.logout, () => _showLogoutConfirmationDialog(), isDestructive: true),
        const SizedBox(height: 12),
        _buildSettingsAction('DELETE ACCOUNT', Icons.delete_forever, () => _showDeleteAccountDialog(), isDestructive: true),
      ],
    );
  }

  Widget _buildSettingsAction(String title, IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.withOpacity(0.05) : Colors.white.withOpacity(0.03),
          border: Border.all(color: isDestructive ? Colors.red.withOpacity(0.2) : Colors.white10, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: isDestructive ? Colors.red : const Color(0xFFD4AF37), size: 18),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDestructive ? Colors.red : Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: isDestructive ? Colors.red : Colors.white24, size: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog(User user) async {
    final controller = TextEditingController(text: user.displayName);
    bool saving = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E3A20),
          title: Text('Edit Profile', style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37))),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Username',
              labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFD4AF37))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final newUsername = controller.text.trim();
                      if (newUsername.isEmpty) return;
                      
                      final oldUsername = user.displayName ?? '';
                      if (newUsername.toLowerCase() == oldUsername.toLowerCase()) {
                         Navigator.pop(context);
                         return;
                      }

                      setState(() => saving = true);
                      try {
                        final exists = await _onlineService.checkUsernameExists(newUsername);
                        if (exists) {
                          setState(() => saving = false);
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username already taken!'), backgroundColor: Colors.red));
                          return;
                        }

                        await user.updateDisplayName(newUsername);
                        await _onlineService.updateUsername(oldUsername, newUsername, user.uid, user.email ?? '');

                        if (mounted) {
                          this.setState(() {});
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        setState(() => saving = false);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
              child: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black))
                  : const Text('Save', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmationDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0E0A), // Deep Dark, matching theme
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5), // Gold border
        ),
        title: Text(
          'SIGN OUT?',
          style: GoogleFonts.cinzel(
            color: const Color(0xFFD4AF37),
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Are you sure you want to sign out of your account?',
          style: GoogleFonts.montserrat(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'NO',
              style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'YES',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A20),
        title: Text('Delete Account', style: GoogleFonts.cinzel(color: Colors.red)),
        content: Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
          style: GoogleFonts.montserrat(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseAuth.instance.currentUser?.delete();
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting account: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
