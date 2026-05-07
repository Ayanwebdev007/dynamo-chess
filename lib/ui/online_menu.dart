import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/online_service.dart';
import 'lobby_screen.dart';
import 'challenge_player_screen.dart';
import 'matchmaking_screen.dart';

class OnlineMenuScreen extends StatefulWidget {
  const OnlineMenuScreen({super.key});

  @override
  State<OnlineMenuScreen> createState() => _OnlineMenuScreenState();
}

class _OnlineMenuScreenState extends State<OnlineMenuScreen> {
  final OnlineService _onlineService = OnlineService();
  bool _isLoading = false;

  void _createGame() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("Select Time Control", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _timeOption(dialogContext, "Bullet | 1 min", 60),
            _timeOption(dialogContext, "Blitz | 3 min", 180),
            _timeOption(dialogContext, "Rapid | 10 min", 600),
          ],
        ),
      ),
    );
  }

  Widget _timeOption(BuildContext dialogContext, String label, int seconds) {
    return ListTile(
      title: Text(label, style: GoogleFonts.montserrat(color: Colors.white)),
      onTap: () {
        Navigator.pop(dialogContext); // Close dialog
        _performCreateGame(seconds);
      },
    );
  }

  void _findRandomMatch() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("Select Time Control", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _matchmakingTimeOption(dialogContext, "Bullet | 1 min", 60),
            _matchmakingTimeOption(dialogContext, "Blitz | 3 min", 180),
            _matchmakingTimeOption(dialogContext, "Rapid | 10 min", 600),
          ],
        ),
      ),
    );
  }

  Widget _matchmakingTimeOption(BuildContext dialogContext, String label, int seconds) {
    return ListTile(
      title: Text(label, style: GoogleFonts.montserrat(color: Colors.white)),
      onTap: () {
        Navigator.pop(dialogContext); // Close dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MatchmakingScreen(
              timeLimitSeconds: seconds,
              onlineService: _onlineService,
            ),
          ),
        );
      },
    );
  }

  void _performCreateGame(int timeLimit) async {
    setState(() => _isLoading = true);
    try {
      final roomId = await _onlineService.createGame(timeLimit);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LobbyScreen(
              roomId: roomId,
              isCreator: true,
              onlineService: _onlineService,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _joinGame() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text("Join Game", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37))),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Enter Room Code",
              labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFD4AF37))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
              onPressed: () async {
                final code = controller.text.trim();
                if (code.length != 6) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text("Invalid Code")));
                  return;
                }
                Navigator.pop(dialogContext); // Close dialog
                setState(() => _isLoading = true);
                
                try {
                  final success = await _onlineService.joinGame(code);
                  if (success) {
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LobbyScreen(
                            roomId: code,
                            isCreator: false,
                            onlineService: _onlineService,
                          ),
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      print("DEBUG: Room not found or full");
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Room not found or full")));
                    }
                  }
                } catch (e) {
                  print("DEBUG: Error joining game: $e");
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text("Join", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFD4AF37)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("ONLINE CHESS", style: GoogleFonts.cinzel(fontSize: 32, color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 48),
                        _buildButton("FIND MATCH", Icons.search, _findRandomMatch),
                        const SizedBox(height: 16),
                        _buildButton("CREATE GAME", Icons.add_circle_outline, _createGame),
                        const SizedBox(height: 16),
                        _buildButton("CHALLENGE PLAYER", Icons.person_add, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ChallengePlayerScreen()),
                          );
                        }),
                        const SizedBox(height: 16),
                        _buildButton("JOIN GAME", Icons.login, _joinGame),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 280, // Slightly wider to accommodate "CHALLENGE PLAYER"
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5)),
          boxShadow: [
            BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // shrink-wrap
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFD4AF37)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label, 
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: Colors.white, 
                  fontSize: 16, 
                  fontWeight: FontWeight.bold
                )
              ),
            ),
          ],
        ),
      ),
    );
  }
}
