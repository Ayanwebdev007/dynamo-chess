import 'dart:async';
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
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.5, -0.5),
            radius: 1.5,
            colors: [Color(0xFF142B16), Color(0xFF0A0E0A)],
          ),
        ),
        child: SafeArea(
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
      ),
    );
  }

  Widget _buildHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
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
              Expanded(
                child: Text(
                  "TOURNAMENT",
                  style: GoogleFonts.cinzel(
                    fontSize: isMobile ? 18 : 28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFD4AF37),
                    letterSpacing: isMobile ? 1.0 : 2.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "SELECT AN ACTIVE TOURNAMENT TO REGISTER",
            style: GoogleFonts.montserrat(
              fontSize: isMobile ? 10 : 12,
              color: Colors.white38,
              fontWeight: FontWeight.w600,
              letterSpacing: isMobile ? 1.0 : 2.0,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 8),
      itemCount: tournaments.length,
      itemBuilder: (context, index) {
        final t = tournaments[index];
        return _buildTournamentCard(t);
      },
    );
  }

  Widget _buildTournamentCard(Tournament t) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
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
            padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: _buildStatusChip(t)),
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
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  t.description,
                  style: GoogleFonts.montserrat(
                    fontSize: isMobile ? 12 : 14,
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

  Widget _buildStatusChip(Tournament t) {
    Color color = Colors.greenAccent;
    String text = "REGISTRATION OPEN";
    
    if (t.status == TournamentStatus.completed) {
      color = Colors.blueAccent;
      text = "TOURNAMENT COMPLETED";
    } else if (t.status == TournamentStatus.active) {
      color = Colors.orangeAccent;
      text = "TOURNAMENT ACTIVE";
    } else if (t.status == TournamentStatus.enrolling && t.scheduledStartAt != null && DateTime.now().isBefore(t.scheduledStartAt!)) {
      color = const Color(0xFFD4AF37);
      text = "UPCOMING TOURNAMENT";
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

    final now = DateTime.now();
    final bool isUpcoming = t.scheduledStartAt != null && now.isBefore(t.scheduledStartAt!);
    final bool isClosed = t.autoStartAt != null && now.isAfter(t.autoStartAt!);
    
    String buttonText = "JOIN TOURNAMENT";
    bool isDisabled = false;
    Color buttonAccentColor = const Color(0xFFD4AF37);
    
    if (t.status == TournamentStatus.completed) {
      buttonText = "SEE RESULTS";
      buttonAccentColor = Colors.blueAccent;
    } else if (isJoined) {
      buttonText = "ENTER LOBBY";
      buttonAccentColor = Colors.greenAccent;
    } else if (isUpcoming) {
      final h = t.scheduledStartAt!.hour.toString().padLeft(2, '0');
      final m = t.scheduledStartAt!.minute.toString().padLeft(2, '0');
      buttonText = "REGISTRATION OPENS AT $h:$m";
      isDisabled = true;
    } else if (isClosed || t.status == TournamentStatus.active) {
      buttonText = "TOURNAMENT STARTED";
      isDisabled = true;
    }

    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: isDisabled 
            ? [Colors.white10, Colors.white10]
            : [buttonAccentColor, buttonAccentColor.withOpacity(0.8)],
        ),
        boxShadow: isDisabled ? [] : [
          BoxShadow(
            color: buttonAccentColor.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isDisabled 
          ? null 
          : () async {
              if (t.status == TournamentStatus.completed || isJoined || t.status == TournamentStatus.active) {
                // Navigate directly to the lobby/details
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TournamentDetailScreen(tournament: t),
                  ),
                );
              } else {
                // Join the tournament
                try {
                  await _service.joinTournament(t.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Registered successfully! Tournament status updated.'))
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Registration failed: $e'))
                  );
                }
              }
            },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          buttonText,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDisabled ? Colors.white38 : Colors.black,
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
              "NO ACTIVE TOURNAMENTS",
              style: GoogleFonts.cinzel(
                color: Colors.white24,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "The tournament dashboard is awaiting signal. If this persists, please try again later.",
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
