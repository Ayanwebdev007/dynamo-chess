import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../core/online_service.dart';
import '../core/models.dart';
import 'board_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String roomId;
  final bool isCreator;
  final OnlineService onlineService;

  const LobbyScreen({
    super.key,
    required this.roomId,
    required this.isCreator,
    required this.onlineService,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late Stream<dynamic> _gameStream;

  @override
  void initState() {
    super.initState();
    _gameStream = widget.onlineService.getGameStream(widget.roomId);
    
    // Listen for start
    _gameStream.listen((event) {
      if (event.snapshot.value == null) return;
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final status = data['status'];
      
      if (status == 'playing') {
        print("DEBUG: Game status is playing! Navigating to BoardScreen...");
        // Game Started!
        if (mounted) {
           final num? fWhiteTime = data['whiteTime'] as num?;
           final int timeLimitSeconds = fWhiteTime?.toInt() ?? 180;
           // Replace so back button goes to menu, not lobby
           Navigator.pushReplacement(
             context,
             MaterialPageRoute(
               builder: (context) => BoardScreen(
                 settings: GameSettings(timeLimit: Duration(seconds: timeLimitSeconds)), 
                 onlineRoomId: widget.roomId,
                 onlineService: widget.onlineService,
                 isWhite: widget.isCreator, // Creator is always white in our simple logic
               ),
             ),
           );
        }
      }
    });
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("ROOM CODE", style: GoogleFonts.montserrat(color: Colors.white54, letterSpacing: 2)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.roomId));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard!")));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.5), blurRadius: 20)
                  ],
                ),
                child: Text(
                  widget.roomId,
                  style: GoogleFonts.robotoMono(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Color(0xFFD4AF37)),
            const SizedBox(height: 24),
            Text(
              "Waiting for opponent...",
              style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              "Share the code to play",
              style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
