import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/tournament_models.dart';
import '../core/tournament_service.dart';
import '../core/online_service.dart';
import '../core/models.dart';
import 'board_screen.dart';
import 'dart:ui' as ui;

class TournamentDetailScreen extends StatefulWidget {
  final Tournament tournament;
  const TournamentDetailScreen({super.key, required this.tournament});

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> with SingleTickerProviderStateMixin {
  final TournamentService _service = TournamentService();
  late TabController _tabController;
  Stream<Tournament?>? _tournamentStream;
  String? _lastDeployedMatchId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tournamentStream = _service.streamTournament(widget.tournament.id);
    
    _tournamentStream!.listen((t) {
      if (t != null && mounted) {
        _handleAutoDeployment(t);
      }
    });
  }

  void _handleAutoDeployment(Tournament t) {
    if (t.status != TournamentStatus.active) return;
    
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final round = t.rounds.firstWhere((r) => r.roundNumber == t.currentRound);
      final myMatch = round.matches.firstWhere(
        (m) => (m.whitePlayerId == currentUserId || m.blackPlayerId == currentUserId) && !m.isCompleted
      );

      if (_lastDeployedMatchId == myMatch.id) return;

      _lastDeployedMatchId = myMatch.id;
      print('🚀 AUTO-DEPLOY: Found active match ${myMatch.id}. Deploying player...');
      
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
           Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BoardScreen(
                onlineRoomId: myMatch.id,
                onlineService: OnlineService(),
                isWhite: myMatch.whitePlayerId == currentUserId,
                settings: t.settings,
                tournamentId: t.id,
                roundNumber: t.currentRound,
              ),
            ),
          );
        }
      });
    } catch (_) {
      // No active match for this user
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: StreamBuilder<Tournament?>(
                    stream: _tournamentStream,
                    builder: (context, snapshot) {
                      // Use live data if available, otherwise fallback to the data passed from the list
                      final t = snapshot.data ?? widget.tournament;
                      
                      // Handle potential error only if we have NO data to show
                      if (snapshot.hasError && snapshot.data == null) {
                         return Center(
                           child: Column(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                               const SizedBox(height: 16),
                               Text("COMMUNICATION ERROR", style: GoogleFonts.cinzel(color: Colors.redAccent)),
                               Text("${snapshot.error}", style: const TextStyle(color: Colors.white24, fontSize: 10)),
                             ],
                           ),
                         );
                      }
                      return Column(
                        children: [
                          _buildAutomationStatus(t),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildOverviewTab(t),
                                _buildMatchesTab(t),
                                _buildStandingsTab(t),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.5, -0.5),
          radius: 1.5,
          colors: [Color(0xFF142B16), Color(0xFF0A0E0A)],
        ),
      ),
    );
  }

  Widget _buildAutomationStatus(Tournament t) {
    if (t.status == TournamentStatus.completed) return const SizedBox.shrink();

    String message = "";
    DateTime? target;

    if (t.status == TournamentStatus.enrolling && t.autoStartAt != null) {
      message = "COMMENCING IN:";
      target = t.autoStartAt;
    } else if (t.status == TournamentStatus.active && t.nextEventAt != null) {
      message = "NEXT ROUND IN:";
      target = t.nextEventAt;
    }

    if (target == null) return const SizedBox.shrink();

    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, _) {
        final remaining = target!.difference(DateTime.now());
        if (remaining.isNegative) return const SizedBox.shrink();
        
        final mins = remaining.inMinutes;
        final secs = remaining.inSeconds % 60;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withOpacity(0.1),
            border: Border(bottom: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFD4AF37)),
              const SizedBox(width: 12),
              Text(
                "$message ${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}",
                style: GoogleFonts.montserrat(
                  color: const Color(0xFFD4AF37),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFD4AF37)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tournament.title,
                  style: GoogleFonts.cinzel(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  "OPERATIONAL INTEL DASHBOARD",
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    color: const Color(0xFFD4AF37),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFFD4AF37),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white38,
        labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: "OVERVIEW"),
          Tab(text: "MATCHES"),
          Tab(text: "STANDINGS"),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(Tournament t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            "MISSION OBJECTIVE",
            t.description,
            Icons.assignment_outlined,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatBox("PRIZE POOL", "${t.prizePool} GOLD", Icons.emoji_events),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatBox("ROUNDS", "${t.totalRounds}", Icons.layers_outlined),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader("OPERATIONAL RULES"),
          const SizedBox(height: 16),
          _buildRuleItem("Swiss System pairing logic applied."),
          _buildRuleItem("3-minute Blitz time control per deployment."),
          _buildRuleItem("Points: Win 1.0 | Draw 0.5 | Loss 0.0"),
          _buildRuleItem("Tie-breaks resolved via Buchholz calculation."),
        ],
      ),
    );
  }

  Widget _buildMatchesTab(Tournament t) {
    if (t.rounds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.1)),
                ),
                child: const Icon(Icons.radar, size: 48, color: Color(0xFFD4AF37)),
              ),
              const SizedBox(height: 32),
              Text(
                "AWAITING DEPLOYMENT",
                style: GoogleFonts.cinzel(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "The command center is currently finalizing pairings. Stand by for Round 1 assignments.",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: Colors.white38,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sortedRounds = List<TournamentRound>.from(t.rounds);
    sortedRounds.sort((a, b) => b.roundNumber.compareTo(a.roundNumber));

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: sortedRounds.length,
      itemBuilder: (context, index) {
        final round = sortedRounds[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "ROUND ${round.roundNumber}",
                    style: GoogleFonts.montserrat(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (round.isCompleted) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.check_circle, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text("COMPLETED", style: GoogleFonts.montserrat(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
                const Spacer(),
                Text("${round.matches.length} MATCHES", style: GoogleFonts.robotoMono(color: Colors.white24, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 16),
            ...round.matches.map((match) => _buildMatchCard(match, t.settings, t)).toList(),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildMatchCard(TournamentMatch match, GameSettings settings, Tournament t) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isMyMatch = match.whitePlayerId == currentUserId || match.blackPlayerId == currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isMyMatch ? const Color(0xFFD4AF37).withOpacity(0.1) : Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMyMatch ? const Color(0xFFD4AF37).withOpacity(0.5) : Colors.white10,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildPlayerInfo(match.whitePlayerName ?? "Unknown", true, match.whiteScore, match.isCompleted),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      match.isCompleted ? "${match.whiteScore?.toStringAsFixed(1) ?? '0.0'} - ${match.blackScore?.toStringAsFixed(1) ?? '0.0'}" : "VS",
                      style: GoogleFonts.robotoMono(
                        color: match.isCompleted ? const Color(0xFFD4AF37) : Colors.white24, 
                        fontWeight: FontWeight.bold,
                        fontSize: match.isCompleted ? 14 : 12,
                      ),
                    ),
                    if (match.isCompleted)
                      Text(
                        "RESULT",
                        style: GoogleFonts.montserrat(color: Colors.white10, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
              _buildPlayerInfo(match.blackPlayerName ?? "Unknown", false, match.blackScore, match.isCompleted),
            ],
          ),
          if (isMyMatch && t.status == TournamentStatus.active && !match.isCompleted) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "PREPARING AUTO-DEPLOYMENT...",
                    style: GoogleFonts.montserrat(
                      color: const Color(0xFFD4AF37),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerInfo(String name, bool isWhite, double? score, bool isCompleted) {
    final bool isWinner = isCompleted && score != null && score > 0.5;
    final bool isDraw = isCompleted && score != null && score == 0.5;

    return Expanded(
      child: Column(
        crossAxisAlignment: isWhite ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(
            name,
            style: GoogleFonts.montserrat(
              color: isWinner ? const Color(0xFFD4AF37) : (isDraw ? Colors.white70 : (isCompleted ? Colors.white38 : Colors.white)), 
              fontWeight: isWinner ? FontWeight.w900 : FontWeight.bold,
              fontSize: isWinner ? 15 : 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            mainAxisAlignment: isWhite ? MainAxisAlignment.start : MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isWinner && !isWhite) const Icon(Icons.star, color: Color(0xFFD4AF37), size: 10),
              Text(
                isWhite ? "WHITE" : "BLACK",
                style: GoogleFonts.robotoMono(
                  color: isWinner ? const Color(0xFFD4AF37).withOpacity(0.5) : Colors.white24, 
                  fontSize: 10
                ),
              ),
              if (isWinner && isWhite) const Icon(Icons.star, color: Color(0xFFD4AF37), size: 10),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStandingsTab(Tournament t) {
    final participants = List<TournamentParticipant>.from(t.participants);
    participants.sort((a, b) {
      if (b.score != a.score) return b.score.compareTo(a.score);
      return b.buchholz.compareTo(a.buchholz);
    });

    if (participants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.white10),
            const SizedBox(height: 16),
            Text("NO DATA RECORDED", style: GoogleFonts.cinzel(color: Colors.white24)),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (t.status == TournamentStatus.completed) _buildVictoryBanner(participants.first),
        _buildStandingsHeader(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: participants.length,
            itemBuilder: (context, index) {
              return _buildStandingRow(index + 1, participants[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVictoryBanner(TournamentParticipant winner) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFD4AF37).withOpacity(0.2),
            const Color(0xFFD4AF37).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.emoji_events, size: 48, color: Color(0xFFD4AF37)),
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text("1ST", style: TextStyle(color: Color(0xFFD4AF37), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TOURNAMENT VICTOR",
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFFD4AF37),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  winner.name.toUpperCase(),
                  style: GoogleFonts.cinzel(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Score: ${winner.score} | BH: ${winner.buchholz}",
                  style: GoogleFonts.robotoMono(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandingsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text("RK", style: _standingHeaderStyle)),
          const SizedBox(width: 12),
          Expanded(child: Text("COMMANDER", style: _standingHeaderStyle)),
          SizedBox(width: 60, child: Text("SCORE", style: _standingHeaderStyle, textAlign: TextAlign.center)),
          SizedBox(width: 60, child: Text("BH", style: _standingHeaderStyle, textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  TextStyle get _standingHeaderStyle => GoogleFonts.montserrat(
    color: Colors.white24,
    fontSize: 10,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.0,
  );

  Widget _buildStandingRow(int rank, TournamentParticipant p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              "$rank",
              style: GoogleFonts.robotoMono(
                color: rank <= 3 ? const Color(0xFFD4AF37) : Colors.white38,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              p.name,
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              p.score.toStringAsFixed(1),
              textAlign: TextAlign.center,
              style: GoogleFonts.robotoMono(
                color: const Color(0xFFD4AF37),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              p.buchholz.toStringAsFixed(1),
              textAlign: TextAlign.center,
              style: GoogleFonts.robotoMono(color: Colors.white24, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String content, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFD4AF37), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD4AF37),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: GoogleFonts.montserrat(color: Colors.white70, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white24, size: 20),
          const SizedBox(height: 12),
          Text(label, style: GoogleFonts.montserrat(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String rule) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFFD4AF37), size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              rule,
              style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 13),
            ),
          ),
        ],
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
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
      ],
    );
  }
}
