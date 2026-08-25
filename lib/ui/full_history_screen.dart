import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/online_service.dart';
import 'game_review_screen.dart';

class FullHistoryScreen extends StatefulWidget {
  final String? userId;
  final String? playerName;

  const FullHistoryScreen({
    super.key,
    this.userId,
    this.playerName,
  });

  @override
  State<FullHistoryScreen> createState() => _FullHistoryScreenState();
}

class _FullHistoryScreenState extends State<FullHistoryScreen> {
  final OnlineService _onlineService = OnlineService();
  List<Map<String, dynamic>> _allGames = [];
  bool _isLoading = true;
  String _searchQuery = "";
  String _selectedFilter = "all"; // 'all', 'win', 'loss', 'draw'
  bool _sortNewestFirst = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final targetUid = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;

    if (targetUid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final games = await _onlineService.getGameHistory(targetUid, limit: 0); // 0 = all games
      if (mounted) {
        setState(() {
          _allGames = games;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredGames {
    return _allGames.where((game) {
      // Filter by result
      if (_selectedFilter != 'all') {
        final result = (game['result'] ?? '').toString().toLowerCase();
        if (result != _selectedFilter) return false;
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final opponent = (game['opponent'] ?? '').toString().toLowerCase();
        final method = (game['method'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        if (!opponent.contains(query) && !method.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList()
      ..sort((a, b) {
        final timeA = (a['finishedAt'] ?? 0) as int;
        final timeB = (b['finishedAt'] ?? 0) as int;
        return _sortNewestFirst ? timeB.compareTo(timeA) : timeA.compareTo(timeB);
      });
  }

  String _formatDateTime(int timestamp) {
    if (timestamp == 0) return 'Unknown Date';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[date.month - 1];
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$month ${date.day}, ${date.year} • $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.playerName != null
        ? "${widget.playerName!.toUpperCase()}'S MATCHES"
        : "MATCH HISTORY";

    final totalWins = _allGames.where((g) => (g['result'] ?? '').toString().toLowerCase() == 'win').length;
    final totalLosses = _allGames.where((g) => (g['result'] ?? '').toString().toLowerCase() == 'loss').length;
    final totalDraws = _allGames.where((g) => (g['result'] ?? '').toString().toLowerCase() == 'draw').length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFD4AF37)),
          onPressed: () => Navigator.pop(context),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            style: GoogleFonts.cinzel(
              color: const Color(0xFFD4AF37),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _sortNewestFirst ? Icons.arrow_downward : Icons.arrow_upward,
              color: const Color(0xFFD4AF37),
              size: 20,
            ),
            tooltip: _sortNewestFirst ? "Showing Newest First" : "Showing Oldest First",
            onPressed: () {
              setState(() => _sortNewestFirst = !_sortNewestFirst);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFD4AF37), size: 20),
            tooltip: "Refresh History",
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : RefreshIndicator(
              color: const Color(0xFFD4AF37),
              backgroundColor: const Color(0xFF1E1E1E),
              onRefresh: _loadHistory,
              child: Column(
                children: [
                  // Search & Filter Header
                  _buildSearchAndFilters(totalWins, totalLosses, totalDraws),

                  // Games List
                  Expanded(
                    child: _filteredGames.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _filteredGames.length,
                            itemBuilder: (context, index) {
                              final game = _filteredGames[index];
                              return _buildGameCard(game);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchAndFilters(int wins, int losses, int draws) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          // Search Input
          TextField(
            controller: _searchController,
            style: GoogleFonts.montserrat(color: Colors.white, fontSize: 13),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: "Search by opponent name...",
              hintStyle: GoogleFonts.montserrat(color: Colors.white30, fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37), size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'ALL (${_allGames.length})', const Color(0xFFD4AF37)),
                const SizedBox(width: 8),
                _buildFilterChip('win', 'WINS ($wins)', const Color(0xFF4CAF50)),
                const SizedBox(width: 8),
                _buildFilterChip('loss', 'LOSSES ($losses)', const Color(0xFFE53935)),
                const SizedBox(width: 8),
                _buildFilterChip('draw', 'DRAWS ($draws)', Colors.white60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, Color activeColor) {
    final isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.2) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white12,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.montserrat(
            color: isSelected ? activeColor : Colors.white60,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game) {
    final result = (game['result'] ?? 'draw').toString().toLowerCase();
    final opponent = game['opponent'] ?? 'Dynamo AI';
    final method = (game['method'] ?? 'normal').toString();
    final myColor = (game['myColor'] ?? 'white').toString().toLowerCase();
    final timestamp = (game['finishedAt'] ?? 0) as int;

    Color resultColor;
    String resultBadge;
    if (result == 'win') {
      resultColor = const Color(0xFFD4AF37);
      resultBadge = 'VICTORY';
    } else if (result == 'loss') {
      resultColor = const Color(0xFFDC143C);
      resultBadge = 'DEFEAT';
    } else {
      resultColor = Colors.white54;
      resultBadge = 'DRAW';
    }

    final isWhite = myColor == 'white';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: resultColor.withOpacity(0.25), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openGameReview(game, opponent, myColor),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Result Indicator Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: resultColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: resultColor.withOpacity(0.5), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      resultBadge[0],
                      style: GoogleFonts.montserrat(
                        color: resultColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Match Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              opponent.toUpperCase(),
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isWhite ? Colors.white24 : Colors.black87,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4)),
                            ),
                            child: Text(
                              isWhite ? "WHITE" : "BLACK",
                              style: GoogleFonts.montserrat(
                                color: isWhite ? Colors.white : const Color(0xFFD4AF37),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            resultBadge,
                            style: GoogleFonts.montserrat(
                              color: resultColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            " • by ${method.toUpperCase()}",
                            style: GoogleFonts.montserrat(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDateTime(timestamp),
                        style: GoogleFonts.montserrat(
                          color: Colors.white30,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Action Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.arrow_forward_ios, color: Color(0xFFD4AF37), size: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_toggle_off, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedFilter != 'all'
                ? "NO MATCHES FOUND"
                : "NO GAME HISTORY",
            style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedFilter != 'all'
                ? "Try adjusting your search or filter settings."
                : "Play online or practice against AI to record match history.",
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(color: Colors.white30, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _openGameReview(Map<String, dynamic> game, String opponent, String myColor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameReviewScreen(
          gameData: game,
          opponentName: opponent,
          myColor: myColor,
        ),
      ),
    );
  }
}
