import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/puzzle_service.dart';
import 'puzzle_play_screen.dart';

class PuzzleListScreen extends StatefulWidget {
  const PuzzleListScreen({super.key});

  @override
  State<PuzzleListScreen> createState() => _PuzzleListScreenState();
}

class _PuzzleListScreenState extends State<PuzzleListScreen> {
  final PuzzleService _puzzleService = PuzzleService();
  Set<String> _solvedPuzzleIds = {};
  bool _isLoadingSolved = true;

  @override
  void initState() {
    super.initState();
    _loadSolvedPuzzles();
  }

  Future<void> _loadSolvedPuzzles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('solved_puzzles') ?? [];
      setState(() {
        _solvedPuzzleIds = list.toSet();
        _isLoadingSolved = false;
      });
    } catch (_) {
      setState(() => _isLoadingSolved = false);
    }
  }

  Future<void> _onPuzzleSolved(String puzzleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _solvedPuzzleIds.add(puzzleId);
      });
      await prefs.setStringList('solved_puzzles', _solvedPuzzleIds.toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      body: Stack(
        children: [
          // Radial Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.5,
                colors: [
                  Color(0xFF142B16), // Dark Green glow
                  Color(0xFF0A0E0A), // Black
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        "TACTICAL CHALLENGES",
                        style: GoogleFonts.cinzel(
                          color: const Color(0xFFD4AF37),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Divider(color: Colors.white10),
                ),
                
                // Puzzles Grid / List
                Expanded(
                  child: StreamBuilder<List<Puzzle>>(
                    stream: _puzzleService.streamPuzzles(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting || _isLoadingSolved) {
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                        );
                      }

                      final puzzles = snapshot.data ?? [];

                      if (puzzles.isEmpty) {
                        return _buildEmptyState();
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(40),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 380,
                          mainAxisExtent: 220,
                          crossAxisSpacing: 32,
                          mainAxisSpacing: 32,
                        ),
                        itemCount: puzzles.length,
                        itemBuilder: (context, index) {
                          final puzzle = puzzles[index];
                          final isSolved = _solvedPuzzleIds.contains(puzzle.id);
                          return _buildPuzzleCard(puzzle, isSolved);
                        },
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.extension_outlined, size: 80, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 24),
          Text(
            "NO PUZZLES AVAILABLE",
            style: GoogleFonts.cinzel(color: Colors.white24, fontSize: 18, letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            "Check back later! Admin is cooking up new tactical configurations.",
            style: GoogleFonts.montserrat(color: Colors.white12, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzleCard(Puzzle puzzle, bool isSolved) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSolved 
              ? Colors.green.withOpacity(0.2) 
              : Colors.white.withOpacity(0.05),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PuzzlePlayScreen(
                  puzzle: puzzle,
                  onSolved: () => _onPuzzleSolved(puzzle.id),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        puzzle.title.toUpperCase(),
                        style: GoogleFonts.cinzel(
                          color: isSolved ? Colors.greenAccent : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSolved)
                      const Icon(Icons.stars, color: Colors.greenAccent, size: 24)
                    else
                      Icon(Icons.play_circle_outline, color: const Color(0xFFD4AF37).withOpacity(0.6), size: 24),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "${puzzle.movesToWin} Move${puzzle.movesToWin > 1 ? "s" : ""} to Win",
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFFD4AF37),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Text(
                    puzzle.description,
                    style: GoogleFonts.montserrat(
                      color: Colors.white38,
                      fontSize: 12,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    isSolved ? "SOLVED" : "PLAY CHALLENGE",
                    style: GoogleFonts.montserrat(
                      color: isSolved ? Colors.greenAccent : const Color(0xFFD4AF37),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
