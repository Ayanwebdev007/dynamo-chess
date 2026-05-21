import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/online_service.dart';
import '../platform_asset_image.dart';
import '../game_review_screen.dart';
import '../../core/tournament_service.dart';
import '../../core/tournament_models.dart';

enum AdminTab { overview, users, games, tournaments, analytics, settings }

class AdminDashboardScreen extends StatefulWidget {
  final AdminTab initialTab;
  const AdminDashboardScreen({super.key, this.initialTab = AdminTab.overview});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final OnlineService _onlineService = OnlineService();
  final TournamentService _tournamentService = TournamentService();
  late AdminTab _currentTab;
  bool _isLoading = true;
  
  // Data
  int _totalUsers = 0;
  int _activeGames = 0;
  List<Map<dynamic, dynamic>> _liveGames = [];
  List<Map<dynamic, dynamic>> _allUsers = [];
  
  // Selected User Details
  Map<dynamic, dynamic>? _selectedUser;
  List<Map<String, dynamic>> _userGameHistory = [];
  bool _isFetchingUserHistory = false;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    if (!kIsWeb) {
      Future.delayed(Duration.zero, () {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      _checkLoginStatus();
    }
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('isAdminLoggedIn') ?? false)) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/admin/login');
    } else {
      setState(() => _isLoading = false);
      _fetchAdminData();
    }
  }

  Future<void> _fetchAdminData() async {
    final db = FirebaseDatabase.instance.ref();
    
    db.child('users').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final usersMap = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        if (mounted) {
          setState(() {
            _totalUsers = usersMap.length;
            _allUsers = usersMap.entries.map((e) => {
              'uid': e.key, 
              ...Map<dynamic, dynamic>.from(e.value)
            }).toList();
          });
        }
      }
    });

    db.child('games').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final gamesMap = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final now = DateTime.now().millisecondsSinceEpoch;
        final twentyMinutes = 20 * 60 * 1000;
        
        final live = gamesMap.entries
            .where((e) {
              final data = Map<dynamic, dynamic>.from(e.value as Map);
              
              // AUTO-CLEANUP LOGIC:
              // If a game is 'waiting' and older than 20 minutes, mark it as 'aborted'
              if (data['status'] == 'waiting' && data['createdAt'] != null) {
                final createdAt = data['createdAt'] as int;
                if (now - createdAt > twentyMinutes) {
                  db.child('games').child(e.key).update({'status': 'aborted'});
                  return false;
                }
              }

              // Only show games that are ACTIVELY being played by two identified players
              return data['status'] == 'playing' && 
                     data['whitePlayerName'] != null && data['whitePlayerName'] != '' &&
                     data['blackPlayerName'] != null && data['blackPlayerName'] != '';
            })
            .map((e) => {'id': e.key, ...Map<dynamic, dynamic>.from(e.value)})
            .toList();
        
        if (mounted) {
          setState(() {
            _activeGames = live.length;
            _liveGames = live;
          });
        }
      } else {
        if (mounted) setState(() { _activeGames = 0; _liveGames = []; });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white38),
          onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
        ),
        title: Text(
          "DYNAMO COMMAND CENTER",
          style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold, letterSpacing: 2.0),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white38),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isAdminLoggedIn', false);
              if (mounted) Navigator.of(context).pushReplacementNamed('/admin/login');
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCurrentView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    if (_selectedUser != null) {
      return _buildUserDetailsView();
    }
    
    switch (_currentTab) {
      case AdminTab.overview:
        return _buildOverview();
      case AdminTab.users:
        return _buildUsersView();
      case AdminTab.games:
        return _buildGamesView();
      case AdminTab.tournaments:
        return _buildTournamentsView();
      default:
        return const Center(child: Text("Section under construction", style: TextStyle(color: Colors.white24)));
    }
  }

  Widget _buildOverview() {
    return SingleChildScrollView(
      key: const ValueKey('overview'),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsGrid(),
          const SizedBox(height: 40),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildLiveGamesList()),
              const SizedBox(width: 32),
              Expanded(flex: 2, child: _buildRecentUsersList()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersView() {
    return SingleChildScrollView(
      key: const ValueKey('users'),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("PLAYER REGISTRY", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white38),
                      const SizedBox(width: 16),
                      Text("Search players...", style: GoogleFonts.montserrat(color: Colors.white24)),
                      const Spacer(),
                      const Icon(Icons.filter_list, color: Colors.white38),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                ..._allUsers.map((user) => _buildUserRow(user)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamesView() {
    return SingleChildScrollView(
      key: const ValueKey('games'),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("LIVE MATCHES", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          _buildLiveGamesList(),
        ],
      ),
    );
  }

  Widget _buildUserRow(Map<dynamic, dynamic> user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFD4AF37).withOpacity(0.1),
            child: Text(user['displayName']?.substring(0, 1).toUpperCase() ?? "U", 
              style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['displayName'] ?? "Unknown Player", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(user['email'] ?? "No email recorded", style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: Text("Rating: ${user['stats']?['rating'] ?? 1200}", style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: Text("Games: ${user['stats']?['totalGames'] ?? 0}", style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => _viewUserDetails(user),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37).withOpacity(0.1),
              foregroundColor: const Color(0xFFD4AF37),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("INSPECT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white38), onPressed: () {}),
        ],
      ),
    );
  }

  Future<void> _viewUserDetails(Map<dynamic, dynamic> user) async {
    setState(() {
      _selectedUser = user;
      _userGameHistory = [];
      _isFetchingUserHistory = true;
    });
    
    final db = FirebaseDatabase.instance.ref();
    try {
      final snapshot = await db.child('gameHistory').child(user['uid']).get();
      
      if (snapshot.exists && snapshot.value != null) {
        final historyMap = Map<dynamic, dynamic>.from(snapshot.value as Map);
        final history = historyMap.entries.map((e) => Map<String, dynamic>.from(e.value as Map)).toList();
        // Sort by date descending
        history.sort((a, b) => ((b['finishedAt'] ?? 0) as int).compareTo((a['finishedAt'] ?? 0) as int));
        
        if (mounted) {
          setState(() {
            _userGameHistory = history;
            _isFetchingUserHistory = false;
          });
        }
      } else {
        if (mounted) setState(() => _isFetchingUserHistory = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingUserHistory = false);
    }
  }

  Widget _buildUserDetailsView() {
    final user = _selectedUser!;
    return SingleChildScrollView(
      key: const ValueKey('user_details'),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFFD4AF37)),
                onPressed: () => setState(() => _selectedUser = null),
              ),
              const SizedBox(width: 16),
              Text("PLAYER FILE: ${user['displayName']?.toUpperCase()}", 
                style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Info Card
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFFD4AF37).withOpacity(0.1),
                          child: Text(user['displayName']?.substring(0, 1).toUpperCase() ?? "U", 
                            style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 32, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildInfoRow("Player Name", user['displayName'] ?? "Unknown"),
                      _buildInfoRow("Email Address", user['email'] ?? "N/A"),
                      _buildInfoRow("Unique ID", user['uid'] ?? "N/A"),
                      _buildInfoRow("Account Created", "Realtime Data"),
                      const Divider(height: 40, color: Colors.white12),
                      Text("AGGREGATE STATS", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      _buildStatDetailRow("Global Rating", "${user['stats']?['rating'] ?? 1200}"),
                      _buildStatDetailRow("Games Won", "${user['stats']?['wins'] ?? 0}"),
                      _buildStatDetailRow("Games Lost", "${user['stats']?['losses'] ?? 0}"),
                      _buildStatDetailRow("Total Games", "${user['stats']?['totalGames'] ?? 0}"),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 32),
              // Game History Card
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("GAME HISTORY", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      if (_isFetchingUserHistory)
                        const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                      else if (_userGameHistory.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No game records found for this player", style: TextStyle(color: Colors.white24))))
                      else
                        _buildHistoryTable(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildStatDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildHistoryTable() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: 2, child: Text("DATE", style: _headerStyle())),
            Expanded(flex: 3, child: Text("OPPONENT", style: _headerStyle())),
            Expanded(child: Text("COLOR", style: _headerStyle())),
            Expanded(child: Text("RESULT", style: _headerStyle())),
            Expanded(flex: 2, child: Text("METHOD", style: _headerStyle())),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(color: Colors.white12),
        ..._userGameHistory.map((game) => _buildHistoryRow(game)),
      ],
    );
  }

  TextStyle _headerStyle() => GoogleFonts.montserrat(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold);

  Widget _buildHistoryRow(Map<String, dynamic> game) {
    final date = DateTime.fromMillisecondsSinceEpoch(game['finishedAt'] ?? 0);
    final formattedDate = "${date.day}/${date.month}/${date.year}";
    final result = game['result'] ?? 'unknown';
    final resultColor = result == 'win' ? Colors.greenAccent : (result == 'loss' ? Colors.redAccent : Colors.white54);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(formattedDate, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          Expanded(
            flex: 3, 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(game['opponent'] ?? "Dynamo AI", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(game['opponentId'] ?? "", style: const TextStyle(color: Colors.white24, fontSize: 9)),
              ],
            )
          ),
          Expanded(child: Text(game['myColor']?.toUpperCase() ?? "", style: const TextStyle(color: Colors.white54, fontSize: 11))),
          Expanded(child: Text(result.toUpperCase(), style: TextStyle(color: resultColor, fontWeight: FontWeight.bold, fontSize: 11))),
          Expanded(flex: 2, child: Text(game['method']?.toUpperCase() ?? "", style: const TextStyle(color: Colors.white38, fontSize: 11))),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => GameReviewScreen(
                    gameData: game, 
                    opponentName: game['opponent'] ?? "Unknown", 
                    myColor: game['myColor'] ?? "white"
                  )
                )
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37).withOpacity(0.1),
              foregroundColor: const Color(0xFFD4AF37),
              minimumSize: const Size(60, 30),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("REVIEW", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const PlatformAssetImage(assetPath: 'assets/dynamo_logo.png', viewType: 'dynamo_logo', width: 80, height: 80),
          const SizedBox(height: 24),
          _buildSidebarItem(Icons.dashboard_outlined, "Overview", _currentTab == AdminTab.overview, () => setState(() => _currentTab = AdminTab.overview)),
          _buildSidebarItem(Icons.people_outline, "Users", _currentTab == AdminTab.users, () => setState(() => _currentTab = AdminTab.users)),
          _buildSidebarItem(Icons.sports_esports_outlined, "Games", _currentTab == AdminTab.games, () => setState(() => _currentTab = AdminTab.games)),
          _buildSidebarItem(Icons.emoji_events_outlined, "Tournaments", _currentTab == AdminTab.tournaments, () => setState(() => _currentTab = AdminTab.tournaments)),
          _buildSidebarItem(Icons.analytics_outlined, "Analytics", _currentTab == AdminTab.analytics, () => setState(() => _currentTab = AdminTab.analytics)),
          _buildSidebarItem(Icons.settings_outlined, "System Config", _currentTab == AdminTab.settings, () => setState(() => _currentTab = AdminTab.settings)),
          const Spacer(),
          _buildSidebarItem(Icons.logout, "Exit Panel", false, () => Navigator.of(context).pushReplacementNamed('/')),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, bool isSelected, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFFD4AF37) : Colors.white38, size: 20),
              const SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        _buildStatCard("TOTAL PLAYERS", _totalUsers.toString(), Icons.people, Colors.blueAccent),
        const SizedBox(width: 24),
        _buildStatCard("ACTIVE GAMES", _activeGames.toString(), Icons.sports_esports, const Color(0xFFD4AF37)),
        const SizedBox(width: 24),
        _buildStatCard("SERVER LATENCY", "24ms", Icons.speed, Colors.greenAccent),
        const SizedBox(width: 24),
        _buildStatCard("UPTIME", "99.9%", Icons.cloud_done, Colors.purpleAccent),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: GoogleFonts.montserrat(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                Icon(icon, color: color.withOpacity(0.5), size: 16),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveGamesList() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("LIVE GAMES", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          if (_liveGames.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No active games", style: TextStyle(color: Colors.white24)))),
          ..._liveGames.take(10).map((game) => _buildGameTile(game)),
        ],
      ),
    );
  }

  Widget _buildGameTile(Map<dynamic, dynamic> game) {
    final whiteName = game['whitePlayerName'] ?? 'Unknown';
    final blackName = (game['blackPlayerName'] == null || game['blackPlayerName'] == '') ? 'Waiting...' : game['blackPlayerName'];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const CircleAvatar(backgroundColor: Colors.white12, radius: 16, child: Icon(Icons.play_arrow, size: 16, color: Color(0xFFD4AF37))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("$whiteName vs $blackName", 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text("Room ID: ${game['id']} • Status: ${game['status']}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.remove_red_eye_outlined, color: Colors.white38, size: 18),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
              tooltip: 'TERMINATE GAME',
              onPressed: () => _showTerminateGameDialog(game['id']),
            ),
          ],
        ),
      ),
    );
  }

  void _showTerminateGameDialog(String roomId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("TERMINATE GAME?"),
        content: Text("Are you sure you want to force abort room $roomId? This will clear it from active matches."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              await _onlineService.abortGame(roomId);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("TERMINATE"),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentUsersList() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("RECENT PLAYERS", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ..._allUsers.take(8).map((user) => _buildUserSmallTile(user)),
        ],
      ),
    );
  }

  Widget _buildUserSmallTile(Map<dynamic, dynamic> user) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFD4AF37).withOpacity(0.1),
            radius: 18,
            child: Text(user['displayName']?.substring(0, 1).toUpperCase() ?? "U", 
              style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['displayName'] ?? "Player", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(user['email'] ?? "", style: const TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
          ),
          if (user['isAdmin'] == true)
            const Icon(Icons.verified, color: Color(0xFFD4AF37), size: 14),
        ],
      ),
    );
  }

  Widget _buildTournamentsView() {
    return StreamBuilder<List<Tournament>>(
      stream: _tournamentService.streamTournaments(),
      builder: (context, snapshot) {
        final tournaments = snapshot.data ?? [];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("TOURNAMENT MANAGEMENT", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 24, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _showCreateTournamentDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("CREATE TOURNAMENT"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (tournaments.isEmpty)
                _buildEmptyTournamentsState()
              else
                ...tournaments.map((t) => _buildAdminTournamentCard(t)),
            ],
          ),
        );
      }
    );
  }

  Widget _buildEmptyTournamentsState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.emoji_events_outlined, size: 80, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 24),
          Text("NO ACTIVE TOURNAMENTS", style: GoogleFonts.cinzel(color: Colors.white24, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildAdminTournamentCard(Tournament t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text("ID: ${t.id} • Status: ${t.status.name.toUpperCase()}", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
              const Spacer(),
              _buildTournamentStatusBadge(t.status),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildStatDetailRow("Participants", "${t.participants.length}"),
              const SizedBox(width: 32),
              _buildStatDetailRow("Current Round", "${t.currentRound} / ${t.totalRounds}"),
              const SizedBox(width: 32),
              _buildStatDetailRow("Prize Pool", "${t.prizePool} GOLD"),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (t.status == TournamentStatus.enrolling)
                ElevatedButton(
                  onPressed: () => _tournamentService.pairNextRound(t.id),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.1), foregroundColor: Colors.green),
                  child: const Text("START TOURNAMENT (ROUND 1)"),
                ),
              if (t.status == TournamentStatus.active)
                ElevatedButton(
                  onPressed: () => _tournamentService.pairNextRound(t.id),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37).withOpacity(0.1), foregroundColor: const Color(0xFFD4AF37)),
                  child: const Text("PAIR NEXT ROUND"),
                ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => _showDeleteTournamentDialog(t),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                child: const Text("DELETE"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentStatusBadge(TournamentStatus status) {
    Color color = Colors.blueAccent;
    if (status == TournamentStatus.active) color = Colors.orangeAccent;
    if (status == TournamentStatus.completed) color = Colors.greenAccent;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showCreateTournamentDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final roundsController = TextEditingController(text: "3");
    final prizeController = TextEditingController(text: "1000");
    final timeController = TextEditingController(text: "180");
    final autoStartController = TextEditingController(text: "2");
    DateTime selectedStartDateTime = DateTime.now().add(const Duration(minutes: 5));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text("CREATE NEW TOURNAMENT", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAdminTextField(titleController, "Tournament Title", "e.g. Dynamo Elite Cup"),
                _buildAdminTextField(descController, "Tournament Description", "Brief description of the tournament", maxLines: 3),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Total Rounds", style: TextStyle(color: Colors.white38, fontSize: 12)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFD4AF37)),
                                const SizedBox(width: 8),
                                Text("AUTO-CALC", style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _buildAdminTextField(prizeController, "Prize Pool", "1000", keyboardType: TextInputType.number)),
                  ],
                ),
                _buildAdminTextField(timeController, "Time Limit (Seconds)", "180", keyboardType: TextInputType.number),
                
                // Scheduled Start Date & Time Picker
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Scheduled Start Date & Time", style: TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedStartDateTime,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Color(0xFFD4AF37),
                                  onPrimary: Colors.black,
                                  surface: Color(0xFF1A1A1A),
                                  onSurface: Colors.white,
                                ),
                                dialogBackgroundColor: const Color(0xFF121212),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (pickedDate != null) {
                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedStartDateTime),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: Color(0xFFD4AF37),
                                    onPrimary: Colors.black,
                                    surface: Color(0xFF1A1A1A),
                                    onSurface: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (pickedTime != null) {
                            setDialogState(() {
                              selectedStartDateTime = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Color(0xFFD4AF37)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "${selectedStartDateTime.day.toString().padLeft(2, '0')}/${selectedStartDateTime.month.toString().padLeft(2, '0')}/${selectedStartDateTime.year} ${selectedStartDateTime.hour.toString().padLeft(2, '0')}:${selectedStartDateTime.minute.toString().padLeft(2, '0')}",
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildAdminTextField(autoStartController, "Join Time Limit (Minutes after Start Time)", "2", keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: () async {
                try {
                  final id = "T-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
                  await _tournamentService.createTournament(
                    id: id,
                    title: titleController.text,
                    description: descController.text,
                    totalRounds: 0, // Will be auto-calculated on start
                    prizePool: int.tryParse(prizeController.text) ?? 1000,
                    timeLimitSeconds: int.tryParse(timeController.text) ?? 180,
                    scheduledStartAt: selectedStartDateTime,
                    autoStartDelayMinutes: int.tryParse(autoStartController.text) ?? 2,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tournament Created Successfully')),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Tournament Creation Failed: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black),
              child: const Text("CREATE"),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteTournamentDialog(Tournament t) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("DELETE TOURNAMENT?"),
        content: Text("Are you sure you want to permanently delete ${t.title}? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              await _tournamentService.deleteTournament(t.id);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("DELETE"),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTextField(TextEditingController controller, String label, String hint, {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white10),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }
}
