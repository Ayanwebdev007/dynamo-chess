import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/online_service.dart';
import 'board_screen.dart';
import '../core/models.dart';

class ChallengePlayerScreen extends StatefulWidget {
  const ChallengePlayerScreen({super.key});

  @override
  State<ChallengePlayerScreen> createState() => _ChallengePlayerScreenState();
}

class _ChallengePlayerScreenState extends State<ChallengePlayerScreen> {
  final OnlineService _onlineService = OnlineService();
  final TextEditingController _usernameController = TextEditingController();
  
  Map<String, dynamic>? _foundUser;
  bool _isSearching = false;
  bool _isSending = false;
  int _selectedTimeControl = 180; // Default: 3 min (Blitz)
  String? _errorMessage;
  
  Future<void> _searchUser() async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _foundUser = null;
    });
    
    try {
      final username = _usernameController.text.trim();
      if (username.isEmpty) {
        throw 'Please enter a username';
      }
      
      final user = await _onlineService.findUserByUsername(username);
      
      setState(() {
        if (user == null) {
          _errorMessage = 'User "$username" not found';
        } else {
          _foundUser = user;
        }
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSearching = false;
      });
    }
  }
  
  Future<void> _sendChallenge() async {
    if (_foundUser == null) return;
    
    setState(() => _isSending = true);
    
    try {
      final inviteId = await _onlineService.sendInvitationByUsername(
        _foundUser!['username'],
        _selectedTimeControl,
      );
      
      if (inviteId == null) {
        throw 'Failed to send invitation';
      }
      
      // Get the room ID from the invitation
      final roomId = await _onlineService.getRoomIdFromInvitation(inviteId);
      
      if (mounted) {
        // Navigate Player A to the board (as white, waiting for opponent)
        // Pass inviteId so BoardScreen can monitor if opponent declines
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BoardScreen(
              settings: GameSettings(timeLimit: Duration(seconds: _selectedTimeControl)),
              onlineRoomId: roomId,
              onlineService: _onlineService,
              isWhite: true, // Challenger is white
              invitationId: inviteId, // Pass invitation ID for monitoring
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.5,
            colors: [
              Color(0xFF1E3A20),
              Color(0xFF0A0E0A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'CHALLENGE PLAYER',
                      style: GoogleFonts.cinzel(
                        color: const Color(0xFFD4AF37),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search Section
                      Text(
                        'Enter Username',
                        style: GoogleFonts.montserrat(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _usernameController,
                              style: GoogleFonts.montserrat(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'username123',
                                hintStyle: GoogleFonts.montserrat(color: Colors.white38),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                                ),
                              ),
                              onSubmitted: (_) => _searchUser(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _isSearching ? null : _searchUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSearching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : Text(
                                    'Search',
                                    style: GoogleFonts.montserrat(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.montserrat(color: Colors.redAccent, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      if (_foundUser != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              // User Info
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: const Color(0xFFD4AF37),
                                    child: Text(
                                      _foundUser!['displayName'][0].toUpperCase(),
                                      style: GoogleFonts.cinzel(
                                        color: Colors.black,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _foundUser!['displayName'],
                                          style: GoogleFonts.cinzel(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '@${_foundUser!['username']}',
                                          style: GoogleFonts.montserrat(
                                            color: Colors.white54,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 24),
                                ],
                              ),
                              
                              const SizedBox(height: 24),
                              const Divider(color: Colors.white12),
                              const SizedBox(height: 24),
                              
                              // Time Control Selection
                              Text(
                                'Select Time Control',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildTimeOption('Bullet', '1 min', 60),
                              const SizedBox(height: 8),
                              _buildTimeOption('Blitz', '3 min', 180),
                              const SizedBox(height: 8),
                              _buildTimeOption('Rapid', '10 min', 600),
                              
                              const SizedBox(height: 24),
                              
                              // Send Challenge Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSending ? null : _sendChallenge,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD4AF37),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: _isSending
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.send, color: Colors.black, size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Send Challenge',
                                              style: GoogleFonts.montserrat(
                                                color: Colors.black,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTimeOption(String title, String duration, int seconds) {
    final isSelected = _selectedTimeControl == seconds;
    return InkWell(
      onTap: () => setState(() => _selectedTimeControl = seconds),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFD4AF37).withOpacity(0.15) 
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFFD4AF37) 
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFFD4AF37) : Colors.white38,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$title | $duration',
                style: GoogleFonts.montserrat(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
