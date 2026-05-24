import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/online_service.dart';
import '../../core/fcm_sender_service.dart';
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
  
  // Played Games
  List<Map<String, dynamic>> _playedGames = [];
  bool _isLoadingPlayedGames = true;
  DataSnapshot? _gameHistorySnapshot;
  String _gamesSubTab = 'live'; // 'live' or 'history'
  
  // Selected User Details
  Map<dynamic, dynamic>? _selectedUser;
  List<Map<String, dynamic>> _userGameHistory = [];
  bool _isFetchingUserHistory = false;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // System Messaging State
  String _messagingTarget = 'all'; // 'all' or 'specific'
  String? _selectedMessagingUserUid;
  final TextEditingController _msgTitleController = TextEditingController(text: 'Dynamo Chess Update ♟️');
  final TextEditingController _msgBodyController = TextEditingController();
  final TextEditingController _msgImageUrlController = TextEditingController();
  bool _isSendingNotification = false;
  bool _hasCustomFcmKey = false;

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  void _checkCustomFcmKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString('fcm_service_account_json');
      if (mounted) {
        setState(() {
          _hasCustomFcmKey = (key != null && key.isNotEmpty && key != '{}');
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
    _msgTitleController.addListener(_onFieldChanged);
    _msgBodyController.addListener(_onFieldChanged);
    _msgImageUrlController.addListener(_onFieldChanged);
    _checkCustomFcmKey();

    if (!kIsWeb) {
      Future.delayed(Duration.zero, () {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      _checkLoginStatus();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _msgTitleController.dispose();
    _msgBodyController.dispose();
    _msgImageUrlController.dispose();
    super.dispose();
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

  String _getUserName(String userId) {
    if (userId == 'ai') return 'Dynamo AI';
    if (userId == 'offline_opp') return 'Offline Opponent';
    final user = _allUsers.firstWhere(
      (u) => u['uid'] == userId, 
      orElse: () => <dynamic, dynamic>{}
    );
    if (user.containsKey('displayName')) {
      return user['displayName'].toString();
    }
    return 'Player';
  }

  void _parseGameHistory() {
    if (_gameHistorySnapshot == null || _gameHistorySnapshot!.value == null) {
      if (mounted) {
        setState(() {
          _playedGames = [];
          _isLoadingPlayedGames = false;
        });
      }
      return;
    }
    
    try {
      final Map<dynamic, dynamic> playersHistoryMap = Map<dynamic, dynamic>.from(_gameHistorySnapshot!.value as Map);
      final Map<String, Map<String, dynamic>> uniqueGames = {};

      playersHistoryMap.forEach((playerId, playerGamesValue) {
        if (playerGamesValue != null) {
          final playerGamesMap = Map<dynamic, dynamic>.from(playerGamesValue as Map);
          playerGamesMap.forEach((gameId, gameValue) {
            final gameData = Map<dynamic, dynamic>.from(gameValue as Map);
            final String gId = gameId.toString();
            
            final String ownerId = playerId.toString();
            final String opponentId = (gameData['opponentId'] ?? '').toString();
            final String opponentName = (gameData['opponent'] ?? 'Unknown').toString();
            final String myColor = (gameData['myColor'] ?? 'white').toString();
            
            String whiteId = '';
            String blackId = '';
            if (myColor == 'white') {
              whiteId = ownerId;
              blackId = opponentId;
            } else {
              whiteId = opponentId;
              blackId = ownerId;
            }
            
            String whiteName = _getUserName(whiteId);
            String blackName = _getUserName(blackId);
            
            if (whiteName == 'Player') {
              if (myColor == 'black' && opponentName != 'Unknown') {
                whiteName = opponentName;
              }
            }
            if (blackName == 'Player') {
              if (myColor == 'white' && opponentName != 'Unknown') {
                blackName = opponentName;
              }
            }
            
            uniqueGames[gId] = {
              'gameId': gId,
              'whitePlayerName': whiteName,
              'whitePlayerId': whiteId,
              'blackPlayerName': blackName,
              'blackPlayerId': blackId,
              'result': gameData['result'] ?? 'draw',
              'finishedAt': gameData['finishedAt'] ?? 0,
              'method': gameData['method'] ?? 'unknown',
              'myColor': myColor,
              'opponentRating': gameData['opponentRating'] ?? 1200,
              'isOffline': gId.startsWith('offline_'),
              'isAI': opponentId == 'ai',
              'moveHistory': gameData['moveHistory'] ?? {},
            };
          });
        }
      });

      final List<Map<String, dynamic>> playedList = uniqueGames.values.toList();
      playedList.sort((a, b) => ((b['finishedAt'] ?? 0) as int).compareTo((a['finishedAt'] ?? 0) as int));
      
      if (mounted) {
        setState(() {
          _playedGames = playedList;
          _isLoadingPlayedGames = false;
        });
      }
    } catch (e) {
      print('Error parsing game history: $e');
      if (mounted) {
        setState(() {
          _isLoadingPlayedGames = false;
        });
      }
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
          _parseGameHistory();
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

    db.child('gameHistory').onValue.listen((event) {
      if (mounted) {
        setState(() {
          _gameHistorySnapshot = event.snapshot;
        });
        _parseGameHistory();
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
      case AdminTab.analytics:
        return _buildAnalyticsView();
      case AdminTab.settings:
        return _buildMessagingView();
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
    final filteredUsers = _allUsers.where((user) {
      final name = (user['displayName'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();

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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white38),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: GoogleFonts.montserrat(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Search players by name or email...",
                            hintStyle: GoogleFonts.montserrat(color: Colors.white24, fontSize: 14),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white38, size: 20),
                          onPressed: () => _searchController.clear(),
                        ),
                      const SizedBox(width: 16),
                      const Icon(Icons.filter_list, color: Colors.white38),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                if (filteredUsers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        _searchQuery.isEmpty ? "No players registered yet." : "No players found matching '$_searchQuery'.",
                        style: GoogleFonts.montserrat(color: Colors.white38, fontSize: 14),
                      ),
                    ),
                  )
                else
                  ...filteredUsers.map((user) => _buildUserRow(user)),
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
          Row(
            children: [
              Text(
                "MATCHES CONTROL", 
                style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 24, fontWeight: FontWeight.bold)
              ),
              const Spacer(),
              // Tabs
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    _buildSubTabButton('live', 'LIVE MATCHES', Icons.sensors),
                    _buildSubTabButton('history', 'PLAYED HISTORY', Icons.history),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _gamesSubTab == 'live' 
              ? _buildLiveGamesList() 
              : _buildPlayedGamesList(),
        ],
      ),
    );
  }

  Widget _buildSubTabButton(String tab, String label, IconData icon) {
    final isSelected = _gamesSubTab == tab;
    return InkWell(
      onTap: () => setState(() => _gamesSubTab = tab),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFD4AF37) : Colors.white38, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.montserrat(
                color: isSelected ? Colors.white : Colors.white38,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayedGamesList() {
    if (_isLoadingPlayedGames) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(64),
          child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
        ),
      );
    }

    if (_playedGames.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off, size: 64, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text(
              "NO PLAYED MATCHES FOUND",
              style: GoogleFonts.cinzel(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Played games history will appear here once players complete matches.",
              style: GoogleFonts.montserrat(color: Colors.white24, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group games by date
    final Map<String, List<Map<String, dynamic>>> groupedGames = {};
    for (var game in _playedGames) {
      final finishedAt = game['finishedAt'] as int? ?? 0;
      if (finishedAt == 0) continue;
      final date = DateTime.fromMillisecondsSinceEpoch(finishedAt);
      final dateStr = _formatGroupDate(date);
      if (!groupedGames.containsKey(dateStr)) {
        groupedGames[dateStr] = [];
      }
      groupedGames[dateStr]!.add(game);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedGames.entries.map((entry) {
        final String dateStr = entry.key;
        final List<Map<String, dynamic>> games = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 16, top: 16),
              child: Text(
                dateStr.toUpperCase(),
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFD4AF37).withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: games.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white12),
                itemBuilder: (context, index) {
                  final game = games[index];
                  return _buildPlayedGameTile(game);
                },
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _formatGroupDate(DateTime date) {
    final List<String> months = [
      'January', 'February', 'March', 'April', 'May', 'June', 
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final List<String> weekdays = [
      'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
    ];
    
    final dayOfWeek = weekdays[date.weekday % 7];
    final month = months[date.month - 1];
    return "$dayOfWeek, $month ${date.day}, ${date.year}";
  }

  Widget _buildPlayedGameTile(Map<String, dynamic> game) {
    final finishedAt = game['finishedAt'] as int? ?? 0;
    final date = DateTime.fromMillisecondsSinceEpoch(finishedAt);
    final timeStr = "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

    final whiteName = game['whitePlayerName'] ?? 'Unknown';
    final blackName = game['blackPlayerName'] ?? 'Unknown';
    
    final result = game['result'] ?? 'draw';
    final myColor = game['myColor'] ?? 'white';
    
    String resultText = 'Draw';
    Color resultColor = Colors.white54;
    
    if (result == 'win') {
      resultText = myColor == 'white' ? 'White Won' : 'Black Won';
      resultColor = const Color(0xFFD4AF37); // Gold
    } else if (result == 'loss') {
      resultText = myColor == 'white' ? 'Black Won' : 'White Won';
      resultColor = const Color(0xFFD4AF37); // Gold
    }

    final method = game['method']?.toString().toUpperCase() ?? 'COMPLETED';

    // Game type details
    String typeText = 'ONLINE';
    Color typeColor = const Color(0xFFD4AF37);
    IconData typeIcon = Icons.wifi;

    if (game['isOffline'] == true) {
      typeText = 'OFFLINE';
      typeColor = Colors.white38;
      typeIcon = Icons.wifi_off;
    } else if (game['isAI'] == true) {
      typeText = 'VS AI';
      typeColor = Colors.purpleAccent;
      typeIcon = Icons.smart_toy;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Time info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeStr,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(typeIcon, color: typeColor.withOpacity(0.6), size: 10),
                  const SizedBox(width: 4),
                  Text(
                    typeText,
                    style: GoogleFonts.montserrat(
                      color: typeColor,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 32),
          // Players
          Expanded(
            flex: 4,
            child: Row(
              children: [
                // White player
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        whiteName,
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "WHITE",
                        style: GoogleFonts.montserrat(
                          color: Colors.white38,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // VS Divider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "VS",
                    style: GoogleFonts.cinzel(
                      color: const Color(0xFFD4AF37).withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                // Black player
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        blackName,
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "BLACK",
                        style: GoogleFonts.montserrat(
                          color: Colors.white38,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Result
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resultText.toUpperCase(),
                  style: GoogleFonts.montserrat(
                    color: resultColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  method,
                  style: GoogleFonts.montserrat(
                    color: Colors.white24,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          // Review button
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GameReviewScreen(
                    gameData: game,
                    opponentName: blackName,
                    myColor: 'white',
                    whitePlayerName: whiteName,
                    blackPlayerName: blackName,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37).withOpacity(0.1),
              foregroundColor: const Color(0xFFD4AF37),
              minimumSize: const Size(80, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.2)),
              ),
            ),
            child: Text(
              "REVIEW",
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
          _buildSidebarItem(Icons.settings_outlined, "System Messaging", _currentTab == AdminTab.settings, () => setState(() => _currentTab = AdminTab.settings)),
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

  Widget _buildAnalyticsView() {
    // 1. Match Outcomes
    int whiteWins = 0;
    int blackWins = 0;
    int draws = 0;
    int checkmates = 0;
    int timeouts = 0;
    int resignations = 0;
    
    for (var game in _playedGames) {
      final result = game['result']?.toString() ?? '';
      final method = game['method']?.toString().toLowerCase() ?? '';
      
      if (result == 'win') {
        if (game['myColor'] == 'white') whiteWins++; else blackWins++;
      } else if (result == 'loss') {
        if (game['myColor'] == 'white') blackWins++; else whiteWins++;
      } else {
        draws++;
      }
      
      if (method.contains('checkmate')) checkmates++;
      else if (method.contains('time') || method.contains('abandon')) timeouts++;
      else if (method.contains('resign')) resignations++;
    }
    
    final totalFinished = whiteWins + blackWins + draws;
    final totalMethods = checkmates + timeouts + resignations;

    // 2. Rating Distribution
    final Map<String, int> ratingBuckets = {
      '< 1000': 0,
      '1000 - 1200': 0,
      '1200 - 1400': 0,
      '1400 - 1600': 0,
      '1600+': 0,
    };
    
    for (var u in _allUsers) {
      final rating = (u['stats']?['rating'] ?? 1200) as int;
      if (rating < 1000) ratingBuckets['< 1000'] = ratingBuckets['< 1000']! + 1;
      else if (rating < 1200) ratingBuckets['1000 - 1200'] = ratingBuckets['1000 - 1200']! + 1;
      else if (rating < 1400) ratingBuckets['1200 - 1400'] = ratingBuckets['1200 - 1400']! + 1;
      else if (rating < 1600) ratingBuckets['1400 - 1600'] = ratingBuckets['1400 - 1600']! + 1;
      else ratingBuckets['1600+'] = ratingBuckets['1600+']! + 1;
    }
    int maxBucket = 1;
    for (var val in ratingBuckets.values) {
      if (val > maxBucket) maxBucket = val;
    }

    // 3. Leaderboard
    final sortedUsers = List<Map<dynamic, dynamic>>.from(_allUsers);
    sortedUsers.sort((a, b) => ((b['stats']?['rating'] ?? 1200) as int).compareTo((a['stats']?['rating'] ?? 1200) as int));
    final topUsers = sortedUsers.take(5).toList();

    return SingleChildScrollView(
      key: const ValueKey('analytics'),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("PLATFORM ANALYTICS", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column (Charts)
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildAnalyticsCard(
                      title: "MATCH OUTCOMES",
                      child: Column(
                        children: [
                          _buildHorizontalBar("White Wins", whiteWins, totalFinished, Colors.white),
                          const SizedBox(height: 12),
                          _buildHorizontalBar("Black Wins", blackWins, totalFinished, Colors.grey.shade800),
                          const SizedBox(height: 12),
                          _buildHorizontalBar("Draws", draws, totalFinished, Colors.blueGrey),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAnalyticsCard(
                      title: "VICTORY METHODS",
                      child: Column(
                        children: [
                          _buildHorizontalBar("Checkmate", checkmates, totalMethods, Colors.redAccent),
                          const SizedBox(height: 12),
                          _buildHorizontalBar("Resignation", resignations, totalMethods, Colors.orangeAccent),
                          const SizedBox(height: 12),
                          _buildHorizontalBar("Timeout", timeouts, totalMethods, Colors.purpleAccent),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right Column (Histogram & Leaderboard)
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildAnalyticsCard(
                      title: "RATING DISTRIBUTION",
                      child: SizedBox(
                        height: 200,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: ratingBuckets.entries.map((e) => _buildVerticalBar(e.key, e.value, maxBucket)).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAnalyticsCard(
                      title: "GLOBAL LEADERBOARD (TOP 5)",
                      child: Column(
                        children: topUsers.map((u) => _buildLeaderboardRow(u)).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard({required String title, required Widget child}) {
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
          Text(title, style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildHorizontalBar(String label, int count, int total, Color color) {
    final double pct = total == 0 ? 0 : count / total;
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Expanded(
          child: Stack(
            children: [
              Container(height: 12, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6))),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(width: 40, child: Text("$count", textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildVerticalBar(String label, int count, int maxCount) {
    final double pct = maxCount == 0 ? 0 : count / maxCount;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text("$count", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 140 * pct,
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFFD4AF37), Colors.orangeAccent]),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.3), blurRadius: 8)],
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Widget _buildLeaderboardRow(Map<dynamic, dynamic> user) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFD4AF37).withOpacity(0.1),
            radius: 16,
            child: Text(user['displayName']?.substring(0, 1).toUpperCase() ?? "U", 
              style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(user['displayName'] ?? "Player", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          Text("${user['stats']?['rating'] ?? 1200}", style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildMessagingView() {
    return SingleChildScrollView(
      key: const ValueKey('messaging'),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text("SYSTEM MESSAGING & ANNOUNCEMENTS", 
                  style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _showFcmKeyConfigDialog,
                icon: Icon(
                  _hasCustomFcmKey ? Icons.vpn_key : Icons.vpn_key_outlined,
                  color: _hasCustomFcmKey ? const Color(0xFFD4AF37) : Colors.redAccent,
                  size: 16,
                ),
                label: Text(
                  _hasCustomFcmKey ? "KEY CONFIGURATION (ACTIVE)" : "CONFIGURE SERVICE ACCOUNT KEY",
                  style: TextStyle(
                    color: _hasCustomFcmKey ? Colors.white : Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.03),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _hasCustomFcmKey ? const Color(0xFFD4AF37).withOpacity(0.3) : Colors.redAccent.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (!_hasCustomFcmKey) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Direct FCM Push is currently offline. You must configure your Firebase Service Account JSON key using the button above to enable sending announcements and challenge messages from this Web console.",
                      style: GoogleFonts.montserrat(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column (Controls)
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Notification Scope", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildScopeOption('all', 'Broadcast to All Players', Icons.campaign_outlined),
                          const SizedBox(width: 16),
                          _buildScopeOption('specific', 'Direct to Player', Icons.person_search_outlined),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (_messagingTarget == 'specific') ...[
                        const Text("Select Recipient", style: TextStyle(color: Colors.white38, fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              dropdownColor: const Color(0xFF1E1E1E),
                              value: _selectedMessagingUserUid,
                              hint: const Text("Select a player...", style: TextStyle(color: Colors.white24)),
                              isExpanded: true,
                              style: const TextStyle(color: Colors.white),
                              items: _allUsers.map((user) {
                                return DropdownMenuItem<String>(
                                  value: user['uid'].toString(),
                                  child: Text("${user['displayName'] ?? 'Player'} (${user['email'] ?? 'No email'})"),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedMessagingUserUid = val;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      _buildAdminTextField(_msgTitleController, "Notification Title", "e.g. New Tournament Starting!"),
                      _buildAdminTextField(_msgBodyController, "Notification Message", "Enter main message content...", maxLines: 4),
                      _buildAdminTextField(_msgImageUrlController, "Optional Image URL", "e.g. https://domain.com/image.png"),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSendingNotification ? null : _sendSystemNotification,
                          icon: _isSendingNotification 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Icon(Icons.send_outlined, size: 18),
                          label: Text(_isSendingNotification ? "SENDING..." : "DISPATCH NOTIFICATION"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 32),
              // Right Column (Mock Preview)
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("LIVE PUSH PREVIEW", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _buildMockNotificationPreview(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScopeOption(String scope, String label, IconData icon) {
    final isSelected = _messagingTarget == scope;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _messagingTarget = scope;
            if (scope == 'all') {
              _selectedMessagingUserUid = null;
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.08) : Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.3) : Colors.white.withOpacity(0.05),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? const Color(0xFFD4AF37) : Colors.white38, size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMockNotificationPreview() {
    final title = _msgTitleController.text.isEmpty ? "Notification Title" : _msgTitleController.text;
    final body = _msgBodyController.text.isEmpty ? "Notification body text goes here..." : _msgBodyController.text;
    final imageUrl = _msgImageUrlController.text.trim();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phone Status Bar mock
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("12:00", style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                Row(
                  children: const [
                    Icon(Icons.wifi, color: Colors.white70, size: 10),
                    SizedBox(width: 4),
                    Icon(Icons.signal_cellular_4_bar, color: Colors.white70, size: 10),
                    SizedBox(width: 4),
                    Icon(Icons.battery_std, color: Colors.white70, size: 10),
                  ],
                ),
              ],
            ),
          ),
          // App banner mock
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Image.asset('assets/dynamo_logo.png', width: 20, height: 20, errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFD4AF37), width: 20, height: 20, child: const Icon(Icons.star, size: 12, color: Colors.black))),
                const SizedBox(width: 8),
                Text("DYNAMO CHESS", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const Spacer(),
                const Text("now", style: TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
          ),
          // Notification Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 12),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Image Preview if provided
          if (imageUrl.isNotEmpty && Uri.tryParse(imageUrl)?.hasAbsolutePath == true) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.white.withOpacity(0.02),
                        child: const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37), strokeWidth: 2)),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.red.withOpacity(0.05),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.broken_image_outlined, color: Colors.redAccent, size: 32),
                            const SizedBox(height: 8),
                            Text("Could not load image URL", style: GoogleFonts.montserrat(color: Colors.redAccent.withOpacity(0.8), fontSize: 10)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ] else
            const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _sendSystemNotification() async {
    final title = _msgTitleController.text.trim();
    final body = _msgBodyController.text.trim();
    final imageUrl = _msgImageUrlController.text.trim().isEmpty ? null : _msgImageUrlController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out both Title and Message body.')),
      );
      return;
    }

    if (_messagingTarget == 'specific' && _selectedMessagingUserUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a player to receive this notification.')),
      );
      return;
    }

    setState(() => _isSendingNotification = true);

    try {
      if (_messagingTarget == 'all') {
        // Broadcast notification
        await _onlineService.sendGlobalBroadcast(body, "Admin", imageUrl: imageUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Global announcement broadcast successfully!')),
          );
        }
      } else {
        // Send to specific user
        final recipientUid = _selectedMessagingUserUid!;
        final token = await FcmSenderService.getUserFcmToken(recipientUid);
        
        if (token == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recipient does not have a registered push token.')),
            );
          }
        } else {
          await FcmSenderService.sendToToken(
            token: token,
            title: title,
            body: body,
            imageUrl: imageUrl,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Direct notification dispatched successfully!')),
            );
          }
        }
      }

      // Reset body and image
      if (mounted) {
        setState(() {
          _msgBodyController.clear();
          _msgImageUrlController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to dispatch notification: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingNotification = false);
      }
    }
  }

  void _showFcmKeyConfigDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final currentKey = prefs.getString('fcm_service_account_json') ?? '';
    final keyController = TextEditingController(text: currentKey);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFD4AF37)),
        ),
        title: Row(
          children: [
            const Icon(Icons.vpn_key, color: Color(0xFFD4AF37)),
            const SizedBox(width: 12),
            Text("FCM Credentials Setup", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Paste the content of your service_account.json key below. This key is stored strictly inside your browser's local storage and is never uploaded publicly.",
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: keyController,
                maxLines: 8,
                style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  hintText: '{\n  "type": "service_account",\n  "project_id": "...",\n  ...\n}',
                  hintStyle: const TextStyle(color: Colors.white10),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          if (currentKey.isNotEmpty)
            TextButton(
              onPressed: () async {
                await prefs.remove('fcm_service_account_json');
                _checkCustomFcmKey();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Custom FCM key cleared. Falling back to default bundle.')),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text("CLEAR KEY"),
            ),
          ElevatedButton(
            onPressed: () async {
              final jsonText = keyController.text.trim();
              if (jsonText.isEmpty) {
                Navigator.pop(context);
                return;
              }
              // Basic validation check
              try {
                final parsed = json.decode(jsonText);
                if (parsed is! Map || parsed['private_key'] == null) {
                  throw 'JSON does not appear to be a valid Service Account key (missing private_key)';
                }
                await prefs.setString('fcm_service_account_json', jsonText);
                _checkCustomFcmKey();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('FCM key configured successfully!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invalid JSON Key: $e'), backgroundColor: Colors.redAccent),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black),
            child: const Text("SAVE KEY"),
          ),
        ],
      ),
    );
  }
}
