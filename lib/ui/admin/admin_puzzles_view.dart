import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/puzzle_service.dart';
import 'admin_puzzle_creator.dart';

class AdminPuzzlesView extends StatefulWidget {
  const AdminPuzzlesView({super.key});

  @override
  State<AdminPuzzlesView> createState() => _AdminPuzzlesViewState();
}

class _AdminPuzzlesViewState extends State<AdminPuzzlesView> {
  final PuzzleService _puzzleService = PuzzleService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Puzzle>>(
      stream: _puzzleService.streamPuzzles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
          );
        }

        final puzzles = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "PUZZLE MANAGEMENT",
                    style: GoogleFonts.cinzel(
                      color: const Color(0xFFD4AF37),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminPuzzleCreator(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("CREATE PUZZLE"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (puzzles.isEmpty)
                _buildEmptyState()
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 220,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                  ),
                  itemCount: puzzles.length,
                  itemBuilder: (context, index) {
                    final p = puzzles[index];
                    return _buildPuzzleCard(p);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.extension_outlined,
              size: 80, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 24),
          Text(
            "NO PUZZLES CREATED YET",
            style: GoogleFonts.cinzel(color: Colors.white24, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            "Click the 'Create Puzzle' button to add your first challenge.",
            style: GoogleFonts.montserrat(color: Colors.white12, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzleCard(Puzzle p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  p.title,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFD4AF37).withOpacity(0.3)),
                ),
                child: Text(
                  "${p.movesToWin} MOVE${p.movesToWin > 1 ? "S" : ""}",
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFFD4AF37),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              p.description,
              style: GoogleFonts.montserrat(
                color: Colors.white38,
                fontSize: 12,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "First Turn: ${p.startTurn.name.toUpperCase()}",
                style: GoogleFonts.montserrat(
                  color: Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFFD4AF37)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminPuzzleCreator(existingPuzzle: p),
                        ),
                      );
                    },
                    tooltip: "Edit Puzzle",
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _confirmDelete(p),
                    tooltip: "Delete Puzzle",
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Puzzle p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
        ),
        title: Text(
          "DELETE PUZZLE?",
          style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37)),
        ),
        content: Text(
          "Are you sure you want to delete '${p.title}'? This action cannot be undone.",
          style: GoogleFonts.montserrat(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () async {
              await _puzzleService.deletePuzzle(p.id);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("DELETE"),
          ),
        ],
      ),
    );
  }
}
