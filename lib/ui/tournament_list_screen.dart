import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/tournament_models.dart';
import '../core/tournament_service.dart';
import 'tournament_detail_screen.dart';
import 'dart:ui' as ui;

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  final TournamentService _service = TournamentService();
  Stream<List<Tournament>>? _tournamentStream;

  @override
  void initState() {
    super.initState();
    _tournamentStream = _service.streamTournaments();
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Expanded(
                  child: StreamBuilder<List<Tournament>>(
                    stream: _tournamentStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return _buildEmptyState();
                      }
                      return _buildTournamentList(snapshot.data!);
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
          center: Alignment(-0.5, -0.5),
          radius: 1.5,
          colors: [Color(0xFF142B16), Color(0xFF0A0E0A)],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFD4AF37)),
              ),
              const SizedBox(width: 8),
              Text(
                "TOURNAMENT COMMAND",
                style: GoogleFonts.cinzel(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFD4AF37),
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "SELECT AN ACTIVE OPERATION TO BEGIN DEPLOYMENT",
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.white38,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 2,
            color: const Color(0xFFD4AF37),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentList(List<Tournament> tournaments) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: tournaments.length,
      itemBuilder: (context, index) {
        final t = tournaments[index];
        return _buildTournamentCard(t);
      },
    );
  }

  Widget _buildTournamentCard(Tournament t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TournamentDetailScreen(tournament: t),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusChip(t.status),
                    Text(
                      "SWISS LEAGUE",
                      style: GoogleFonts.robotoMono(
                        color: const Color(0xFFD4AF37).withOpacity(0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  t.title,
                  style: GoogleFonts.cinzel(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.description,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.white54,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatInfo(Icons.emoji_events_outlined, "PRIZE", "${t.prizePool}G"),
                    _buildStatInfo(Icons.groups_outlined, "RECRUITS", "${t.participants.length}"),
                    _buildStatInfo(Icons.timer_outlined, "ROUNDS", "${t.totalRounds}"),
                  ],
                ),
                const SizedBox(height: 24),
                _buildJoinButton(t),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(TournamentStatus status) {
    Color color = Colors.greenAccent;
    String text = "OPEN FOR ENLISTMENT";
    
    if (status == TournamentStatus.active) {
      color = Colors.orangeAccent;
      text = "OPERATION ACTIVE";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildStatInfo(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white24, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                color: Colors.white24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildJoinButton(Tournament t) {
    // Check if current user is already in
    final currentUser = FirebaseAuth.instance.currentUser;
    final isJoined = t.participants.any((p) => p.userId == currentUser?.uid);

    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: isJoined 
            ? [Colors.white10, Colors.white10]
            : [const Color(0xFFD4AF37), const Color(0xFFD4AF37).withOpacity(0.8)],
        ),
        boxShadow: isJoined ? [] : [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isJoined ? null : () async {
          try {
            await _service.joinTournament(t.id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enlisted successfully! Operational status updated.'))
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Deployment failed: $e'))
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          isJoined ? "ALREADY ENLISTED" : "JOIN OPERATION",
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isJoined ? Colors.white38 : Colors.black,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 80, color: Colors.white.withOpacity(0.05)),
            const SizedBox(height: 24),
            Text(
              "NO ACTIVE OPERATIONS",
              style: GoogleFonts.cinzel(
                color: Colors.white24,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "The command center is awaiting signal. If this persists, attempt a manual re-deployment.",
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: Colors.white12,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
