import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/online_service.dart';
import '../core/models.dart';
import 'board_screen.dart';

class MatchmakingScreen extends StatefulWidget {
  final int timeLimitSeconds;
  final OnlineService onlineService;

  const MatchmakingScreen({
    super.key,
    required this.timeLimitSeconds,
    required this.onlineService,
  });

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  int _timeLeft = 60;
  Timer? _timer;
  String? _roomId;
  bool _isCreator = false;
  StreamSubscription? _gameSubscription;
  bool _matchFound = false;
  bool _searching = true;

  @override
  void initState() {
    super.initState();
    _startMatchmaking();
  }

  void _startMatchmaking() async {
    try {
      final roomId = await widget.onlineService.findRandomMatch(widget.timeLimitSeconds);
      if (!mounted) return;
      
      setState(() {
        _roomId = roomId;
      });

      // Determine if we are creator (white)
      final myId = widget.onlineService.userId;
      
      // Start listening to the room
      _gameSubscription = widget.onlineService.getGameStream(roomId).listen((event) {
        if (event.snapshot.value == null) return;
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final status = data['status'];
        
        // We set _isCreator based on the room data
        if (data['whitePlayerId'] == myId) {
          _isCreator = true;
        }

        if (status == 'playing' && !_matchFound) {
          _matchFound = true;
          _timer?.cancel();
          _gameSubscription?.cancel();
          
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => BoardScreen(
                  settings: GameSettings(timeLimit: Duration(seconds: widget.timeLimitSeconds)),
                  onlineRoomId: roomId,
                  onlineService: widget.onlineService,
                  isWhite: _isCreator,
                ),
              ),
            );
          }
        } else if (status == 'aborted') {
          // If the other player canceled during matchmaking
          if (!_matchFound && mounted && _searching) {
             _timer?.cancel();
             _gameSubscription?.cancel();
             setState(() {
               _searching = false;
             });
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Opponent left the queue.")));
          }
        }
      });

      // Start countdown
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_timeLeft > 0) {
          setState(() {
            _timeLeft--;
          });
        } else {
          // Timeout
          timer.cancel();
          _cancelMatchmaking();
          if (mounted) {
             setState(() {
               _searching = false;
             });
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error finding match: $e")));
        Navigator.pop(context);
      }
    }
  }

  void _cancelMatchmaking() {
    _timer?.cancel();
    _gameSubscription?.cancel();
    if (_roomId != null) {
      // If we created the room, abort it so others don't join it
      // Wait, if we joined someone else's room, we shouldn't abort it unless we are the only ones there.
      // But actually, we only enter "playing" immediately if we join, so we would rarely cancel after joining.
      // If we are waiting, we are the creator. 
      widget.onlineService.leaveGame(_roomId!);
    }
  }

  @override
  void dispose() {
    if (!_matchFound) {
      _cancelMatchmaking();
    }
    super.dispose();
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
        child: _searching 
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFD4AF37)),
                  const SizedBox(height: 32),
                  Text(
                    "Searching for opponent...",
                    style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Time left: $_timeLeft s",
                    style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 18),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1E1E),
                      side: const BorderSide(color: Color(0xFFD4AF37)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text("CANCEL", style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
                  )
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_off, color: Colors.red[400], size: 64),
                  const SizedBox(height: 24),
                  Text(
                    "No match found",
                    style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Try again or invite a friend.",
                    style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text("BACK TO MENU", style: GoogleFonts.montserrat(color: Colors.black, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
      ),
    );
  }
}
