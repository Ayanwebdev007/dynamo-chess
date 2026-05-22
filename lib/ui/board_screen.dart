import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../core/models.dart';
import '../core/board.dart';
import '../core/game_state.dart';
import '../core/rules_engine.dart';
import '../core/score_calculator.dart';
import 'board_painter.dart';
import 'game_header.dart';
import 'player_profile.dart';
import 'bottom_controls.dart';
import 'chat_dialog.dart';
import '../core/auth_service.dart';
import '../core/online_service.dart';
import '../core/fen_converter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'platform_asset_image.dart';
import '../core/ai_engine.dart';
import '../core/settings_controller.dart';
import '../core/tournament_service.dart';

class BoardScreen extends StatefulWidget {
  final GameSettings settings;
  final String? onlineRoomId;
  final OnlineService? onlineService;
  final bool isWhite; // For online play, determines perspective
  final String? invitationId; // For monitoring invitation status (decline/expiry)
  final bool isVsComputer;
  final int aiDifficulty;
  final String? tournamentId;
  final int? roundNumber;
  final bool isSpectator;

  const BoardScreen({
    super.key, 
    this.settings = GameSettings.blitz3,
    this.onlineRoomId,
    this.onlineService,
    this.isWhite = true,
    this.invitationId,
    this.isVsComputer = false,
    this.aiDifficulty = 2,
    this.tournamentId,
    this.roundNumber,
    this.isSpectator = false,
  });

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  late GameState _gameState;
  Timer? _timer;
  StreamSubscription? _gameSubscription;
  StreamSubscription? _chatSubscription;
  bool _hasNewMessages = false;
  String? _lastChatMessage;
  Timer? _messageClearTimer;
  bool _showGameOverOverlay = false;
  String? _whitePlayerId;
  String? _blackPlayerId;
  Timer? _invitationTimeoutTimer;
  final AuthService _auth = AuthService();
  String? _firebaseGameStatus; // Track Firebase game status ('waiting', 'playing', etc.)
  bool _isAiThinking = false;
  String _whitePlayerName = "White";
  String _blackPlayerName = "Black";
  final ScrollController _moveScrollController = ScrollController();
  final SettingsController _settings = SettingsController();
  bool _hasRecordedResult = false; // Prevent double recording
  bool _hasScheduledAutoQuit = false; // Prevent double auto-quitting

  @override
  void initState() {
    super.initState();
    
    // Initialize GameState first
    final board = DynamoBoard();
    board.initializeBoard();
    _gameState = GameState(
      board: board,
      settings: widget.settings, 
    );
    
    // Systematic precaching for instant display - wrapped in post-frame to avoid MediaQuery error in initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _precachePieces();
    });
    
    if (widget.invitationId != null) {
      _setupInvitationMonitor();
    }
    
    if (widget.onlineRoomId != null) {
      _setupOnlineGame();
    }
    
    // Always start timer logic - the timer class internally checks status/turn
    _startTimer();

    // Set initial names
    final user = FirebaseAuth.instance.currentUser;
    final myName = user?.displayName ?? "You";
    
    if (widget.onlineRoomId == null) {
      if (widget.isVsComputer) {
        _whitePlayerName = widget.isWhite ? myName : "Dynamo AI";
        _blackPlayerName = widget.isWhite ? "Dynamo AI" : myName;
      } else {
        _whitePlayerName = myName; // Current user is white in local pvp by default
        _blackPlayerName = "Guest";
      }
    } else {
      _whitePlayerName = widget.isWhite ? myName : "Opponent";
      _blackPlayerName = widget.isWhite ? "Opponent" : myName;
    }

    // Check for initial AI move if computer is white
    if (widget.isVsComputer && !widget.isWhite) {
      _triggerAIMove();
    }

    // Listen for new chat messages to show badge
    if (widget.onlineRoomId != null) {
      _chatSubscription = widget.onlineService!.getChatStream(widget.onlineRoomId!).listen((event) {
        if (mounted && event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          
          // Don't notify for our own messages
          if (data['senderId'] == _auth.currentUser?.uid) return;

          setState(() {
            _hasNewMessages = true;
            _lastChatMessage = "${data['senderName']}: ${data['text']}";
          });

          // Auto-clear message overlay after 2 seconds
          _messageClearTimer?.cancel();
          _messageClearTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _lastChatMessage = null;
              });
            }
          });
        }
      });
    }
  }

  void _showChat() {
    if (widget.onlineRoomId == null) return;
    
    setState(() {
      _hasNewMessages = false;
    });

    showDialog(
      context: context,
      builder: (context) => ChatDialog(
        roomId: widget.onlineRoomId!,
        currentUserId: _auth.currentUser?.uid ?? 'unknown',
        currentUserName: _auth.currentUser?.displayName ?? 'Anonymous',
        onlineService: widget.onlineService!,
      ),
    );
  }

  void _precachePieces() {
    final types = ["king", "queen", "rook", "bishop", "knight", "pawn", "missile"];
    final colors = ["w", "b"];
    for (var t in types) {
      for (var c in colors) {
        precacheImage(AssetImage('assets/pieces/${t}_$c.png'), context);
      }
    }
    // Precache logo too
    precacheImage(const AssetImage('assets/dynamo_logo.png'), context);
  }

  
  StreamSubscription? _invitationSubscription;
  
  void _setupInvitationMonitor() {
    _invitationSubscription = widget.onlineService!.getInvitationStatusStream(widget.invitationId!).listen((status) {
      if (!mounted) return;
      
      if (status == 'declined') {
        // Opponent declined the challenge
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opponent declined your challenge'),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (status == 'expired') {
        // Invitation expired
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation expired'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    });
  }

  Future<void> _triggerAIMove() async {
    debugPrint('🤖 AI: Checking if I should move... Status: ${_gameState.status}');
    if (!mounted || _gameState.status != GameStatus.playing) return;
    
    final aiColor = widget.isWhite ? PlayerColor.black : PlayerColor.white;
    debugPrint('🤖 AI: My Color: $aiColor, Current Turn: ${_gameState.turn}');
    if (_gameState.turn != aiColor) return;

    debugPrint('🤖 AI: Thinking...');
    setState(() => _isAiThinking = true);

    final stopwatch = Stopwatch()..start();
    
    // Depth 2 provides a good balance of speed and casual intelligence without blocking
    final bestMove = await AIEngine.getBestMove(_gameState.board, aiColor, 2);

    // Ensure at least 2 seconds have passed since the start of thinking
    final elapsed = stopwatch.elapsedMilliseconds;
    final remainingDelay = 2000 - elapsed;
    if (remainingDelay > 0 && mounted) {
      await Future.delayed(Duration(milliseconds: remainingDelay));
    }

    if (mounted && bestMove != null) {
      debugPrint('🤖 AI: Executing move from ${bestMove.start} to ${bestMove.end}');
      setState(() {
        _isAiThinking = false;
        _onSquareTapped(bestMove.start, isAiTap: true); // Select
        _onSquareTapped(bestMove.end, isAiTap: true);   // Move
      });
    } else if (mounted) {
      debugPrint('🤖 AI: No move found or unmounted');
      setState(() => _isAiThinking = false);
    }
  }

  void _setupOnlineGame() {
    _gameSubscription = widget.onlineService!.getGameStream(widget.onlineRoomId!).listen((event) {
      if (event.snapshot.value == null) return;
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final status = data['status'];
      
      // Store Firebase status and names
      setState(() {
        _firebaseGameStatus = status;
        if (data['whitePlayerName'] != null && data['whitePlayerName'] != '') {
          _whitePlayerName = data['whitePlayerName'];
        }
        if (data['blackPlayerName'] != null && data['blackPlayerName'] != '') {
          _blackPlayerName = data['blackPlayerName'];
        }
        if (data['whitePlayerId'] != null) _whitePlayerId = data['whitePlayerId'];
        if (data['blackPlayerId'] != null) _blackPlayerId = data['blackPlayerId'];
      });
      
      // Start/Stop invitation timeout timer
      if (status == 'waiting') {
        _startInvitationTimeout();
      } else {
        _invitationTimeoutTimer?.cancel();
        _invitationTimeoutTimer = null;
      }
      
      if (status == 'aborted' || status == 'rejected') {
        _showAbortedDialog(reason: status == 'rejected' ? "Invitation rejected." : "The opponent has left the game.");
        return;
      }
      
      // Record game results when game ends (first client to detect it records for both)
      if (status == 'white_won') {
        final method = data['gameMethod'] ?? 'checkmate';
        if (_gameState.status == GameStatus.playing) {
          setState(() {
            _gameState.status = GameStatus.whiteWon;
            _gameState.gameResult = method == 'resignation' ? "Black Resigned" : "White Wins!";
          });
        }
        
        // Delay the overlay to let user see the board
        Future.delayed(const Duration(milliseconds: 2000), () {
          _showGameOverAndScheduleAutoQuit();
        });
        
        // Record if not already recorded (check if winnerId exists in game data)
        if (!widget.isSpectator && (data['winnerId'] == null || data['winnerId'] == '')) {
          setState(() => _hasRecordedResult = true);
          widget.onlineService!.recordGameResult(
            widget.onlineRoomId!, 
            data['whitePlayerId'], 
            'white_won', 
            method
          );
          // NEW: Report to Tournament Service
          if (widget.tournamentId != null && widget.roundNumber != null) {
            TournamentService().reportMatchResult(
              widget.tournamentId!,
              widget.roundNumber!,
              widget.onlineRoomId!,
              1.0, // White Won
              0.0, // Black Lost
            );
          }
        }
        return;
      }
      
      if (status == 'black_won') {
        final method = data['gameMethod'] ?? 'checkmate';
        if (_gameState.status == GameStatus.playing) {
          setState(() {
            _gameState.status = GameStatus.blackWon;
            _gameState.gameResult = method == 'resignation' ? "White Resigned" : "Black Wins!";
          });
        }
        
        // Delay the overlay to let user see the board
        Future.delayed(const Duration(milliseconds: 2000), () {
          _showGameOverAndScheduleAutoQuit();
        });
        
        // Record if not already recorded
        if (!widget.isSpectator && (data['winnerId'] == null || data['winnerId'] == '')) {
          setState(() => _hasRecordedResult = true);
          widget.onlineService!.recordGameResult(
            widget.onlineRoomId!, 
            data['blackPlayerId'], 
            'black_won', 
            method
          );
          // NEW: Report to Tournament Service
          if (widget.tournamentId != null && widget.roundNumber != null) {
            TournamentService().reportMatchResult(
              widget.tournamentId!,
              widget.roundNumber!,
              widget.onlineRoomId!,
              0.0, // White Lost
              1.0, // Black Won
            );
          }
        }
        return;
      }
      
      if (status == 'draw') {
        if (_gameState.status == GameStatus.playing) {
          setState(() {
            _gameState.status = GameStatus.draw;
            _gameState.gameResult = "Draw!";
          });
        }
        
        // Delay the overlay to let user see the board
        Future.delayed(const Duration(milliseconds: 2000), () {
          _showGameOverAndScheduleAutoQuit();
        });
        
        // Record draw
        if (!widget.isSpectator && data['winnerId'] == null) {  // Draws have no winnerId
          setState(() => _hasRecordedResult = true);
          widget.onlineService!.recordGameResult(
            widget.onlineRoomId!, 
            null,  // No winner
            'draw', 
            'agreement'
          );
          // NEW: Report to Tournament Service
          if (widget.tournamentId != null && widget.roundNumber != null) {
            TournamentService().reportMatchResult(
              widget.tournamentId!,
              widget.roundNumber!,
              widget.onlineRoomId!,
              0.5, // Draw
              0.5, // Draw
            );
          }
        }
        return;
      }
      
      // Sync Last Move
      if (data['lastMove'] != null) {
        final lm = data['lastMove'];
        final from = lm['from'];
        final to = lm['to'];
        _gameState.lastMoveStart = Position(from['x'], from['y']);
        _gameState.lastMoveEnd = Position(to['x'], to['y']);
      }

      // Sync Times - ALWAYS SYNC even if boardState is null (important for Invitations)
      // Use num? as Firebase may return double or int, and toInt() for Duration
      final num? fWhiteTime = data['whiteTime'] as num?;
      final num? fBlackTime = data['blackTime'] as num?;
      
      if (fWhiteTime != null || fBlackTime != null) {
        setState(() {
          final myColor = widget.isWhite ? PlayerColor.white : PlayerColor.black;
          
          // CRITICAL: Only sync if it's NOT our turn, OR if the time in Firebase is significantly different.
          // This prevents the "reset to 60s" jitter every second while our local timer is ticking.
          
          if (fWhiteTime != null) {
            final newWhiteTime = Duration(seconds: fWhiteTime.toInt());
            // Sync White clock if we are NOT White, or if White just moved (turn changed to Black)
            if (!widget.isWhite || _gameState.turn == PlayerColor.black) {
              _gameState.whiteTime = newWhiteTime;
            }
          }
          
          if (fBlackTime != null) {
            final newBlackTime = Duration(seconds: fBlackTime.toInt());
            // Sync Black clock if we are NOT Black, or if Black just moved (turn changed to White)
            if (widget.isWhite || _gameState.turn == PlayerColor.white) {
              _gameState.blackTime = newBlackTime;
            }
          }
        });
      }

      // Update Board State
      if (data['boardState'] != null) {
        final fen = data['boardState'] as String;
        setState(() {
          _gameState.board.grid = FenConverter.fromFen(fen);
          // Sync Turn
          final turnStr = data['turn'] ?? 'white';
          _gameState.turn = turnStr == 'white' ? PlayerColor.white : PlayerColor.black;
          
          if (status == 'playing' && _gameState.status != GameStatus.whiteWon && 
              _gameState.status != GameStatus.blackWon && _gameState.status != GameStatus.draw) {
            _gameState.status = GameStatus.playing;
          }
          
          // Auto-scroll to latest move
          _scrollToEnd();
        });
      }
    });
  }

  void _startInvitationTimeout() {
    _invitationTimeoutTimer?.cancel();
    _invitationTimeoutTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && _firebaseGameStatus == 'waiting') {
        _cancelInvitation(reason: "Challenge expired (No response).");
      }
    });
  }

  void _cancelInvitation({String? reason}) {
    if (widget.onlineRoomId != null) {
      widget.onlineService?.leaveGame(widget.onlineRoomId!);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(reason ?? "Challenge cancelled.")),
    );
    Navigator.of(context).pop();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (widget.onlineRoomId == null && _gameState.status == GameStatus.playing) {
         // Local timer logic
         setState(() {
           _gameState.decrementTime(const Duration(seconds: 1));
           
           // Check if time ran out
           if (_gameState.status != GameStatus.playing) {
             _checkAndRecordOfflineGameOver();
             Future.delayed(const Duration(milliseconds: 2000), () {
               _showGameOverAndScheduleAutoQuit();
             });
           }
         });
      } else if (widget.onlineRoomId != null) {
        // Online timer: only decrement if Firebase status is 'playing' (not 'waiting')
         if (_gameState.status == GameStatus.playing && (_firebaseGameStatus == 'playing' || widget.tournamentId != null)) {
             setState(() {
               _gameState.decrementTime(const Duration(seconds: 1));
               
               // Check if time ran out locally
               if (_gameState.status != GameStatus.playing) {
                 if (!widget.isSpectator) {
                   _checkAndRecordOnlineGameOver();
                 }
                 
                 Future.delayed(const Duration(milliseconds: 2000), () {
                   _showGameOverAndScheduleAutoQuit();
                 });
               }
             });
         }
      }
    });
  }



  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _onSquareTapped(Position pos, {bool isAiTap = false}) {
    if (widget.isSpectator) return; // Spectators cannot move pieces
    
    // Online Check: Can only move if it's my turn
    if (widget.onlineRoomId != null) {
      final myColor = widget.isWhite ? PlayerColor.white : PlayerColor.black;
      if (_gameState.turn != myColor) {
        // Not my turn
        return;
      }
      // Also can't select opponent pieces
      if (_gameState.selectedPosition == null) {
         final piece = _gameState.board.getPiece(pos);
         if (piece != null && piece.color != myColor) return;
      }
    }

    // AI Check: Can't move if AI is thinking or it's AI's turn (unless it's an AI-initiated tap)
    if (widget.isVsComputer && !isAiTap) {
      final myColor = widget.isWhite ? PlayerColor.white : PlayerColor.black;
      if (_gameState.turn != myColor || _isAiThinking) return;
    }

    setState(() {
      _gameState.handleSquareTap(pos, (message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: GoogleFonts.montserrat()),
            backgroundColor: const Color(0xFFD4AF37),
            duration: const Duration(seconds: 2)
          ),
        );
      }, (promotionPos) {
        _showPromotionDialog(promotionPos);
      }, onMoveMade: () {
         _scrollToEnd();
         if (widget.onlineRoomId != null) {
           _sendOnlineMove();
         }
          if (widget.isVsComputer) {
            _triggerAIMove();
          }
          
          // Check for Game Over (Now both Offline and Online)
          if (_gameState.status != GameStatus.playing) {
            if (widget.onlineRoomId == null) {
              _checkAndRecordOfflineGameOver();
            } else {
               _checkAndRecordOnlineGameOver();
            }
            
            // Delay the overlay
            Future.delayed(const Duration(milliseconds: 2000), () {
              _showGameOverAndScheduleAutoQuit();
            });
          }
      });
    });
  }

  void _sendOnlineMove() {
     final fen = FenConverter.toFen(_gameState.board.grid, _gameState.turn);
     
     // Get last move from history
     final lastMove = _gameState.history.last;
     
     widget.onlineService!.makeMove(
       widget.onlineRoomId!,
       fen,
       _gameState.turn, 
       _gameState.whiteTime.inSeconds,
       _gameState.blackTime.inSeconds,
       lastMove.start,
       lastMove.end,
     );
  }

  void _showPromotionDialog(Position pos) {
    // If it's the AI's turn or Auto-Promote is ON, auto-promote to Queen
    bool shouldAutoPromote = _settings.autoPromote || 
                            (widget.isVsComputer && _gameState.turn != (widget.isWhite ? PlayerColor.white : PlayerColor.black));

    if (shouldAutoPromote) {
      _gameState.finalizePromotion(PieceType.queen);
      if (widget.isVsComputer && _gameState.turn == (widget.isWhite ? PlayerColor.white : PlayerColor.black)) {
        // Only trigger AI if it's actually AI's turn now (shouldn't happen here but safe)
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('PROMOTION', style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _promotionOption(PieceType.queen, 'QUEEN'),
            _promotionOption(PieceType.missile, 'MISSILE'),
            _promotionOption(PieceType.rook, 'ROOK'),
            _promotionOption(PieceType.bishop, 'BISHOP'),
            _promotionOption(PieceType.knight, 'KNIGHT'),
          ],
        ),
      ),
    );
  }

  Widget _promotionOption(PieceType type, String label) {
    return ListTile(
      title: Text(label, style: GoogleFonts.montserrat(color: Colors.white)),
      onTap: () {
        setState(() {
          _gameState.finalizePromotion(type);
          Navigator.of(context).pop();
          if (widget.onlineRoomId != null) {
             _sendOnlineMove();
          }
        });
      },
    );
  }

  Position? _findKing(PlayerColor color) {
    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 10; x++) {
        final piece = _gameState.board.getPiece(Position(x, y));
        if (piece != null && piece.type == PieceType.king && piece.color == color) {
          return Position(x, y);
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool amIWhite = widget.onlineRoomId == null ? true : widget.isWhite;
    final PlayerColor topColor = amIWhite ? PlayerColor.black : PlayerColor.white;
    final PlayerColor bottomColor = amIWhite ? PlayerColor.white : PlayerColor.black;
    final Duration topTime = topColor == PlayerColor.white ? _gameState.whiteTime : _gameState.blackTime;
    final Duration bottomTime = bottomColor == PlayerColor.white ? _gameState.whiteTime : _gameState.blackTime;

    final topCaptured = ScoreCalculator.getCapturedPieces(_gameState.history, topColor);
    final bottomCaptured = ScoreCalculator.getCapturedPieces(_gameState.history, bottomColor);
    final scoreAdvantages = ScoreCalculator.getScoreAdvantage(_gameState.history);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A), // Deep Dark
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.5,
                colors: [
                  Color(0xFF1E3A20), // Dark Green Glow
                  Color(0xFF0A0E0A), // Black
                ],
              ),
            ),
          ),

          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isWide = constraints.maxWidth > 900;
                
                if (isWide) {
                  return _buildDesktopLayout(constraints);
                }

                return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    appBar: GameHeader(
                      settings: widget.settings,
                    ),
                    body: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          // Move History (Replaced Turn Status)
                          _buildMoveHistory(),

                          // Opponent Profile (Top)
                          PlayerProfileWidget(
                            name: topColor == PlayerColor.white ? _whitePlayerName : _blackPlayerName,
                            flagAsset: "assets/inflag.png",
                            avatarUrl: "", // Clear broken URL
                            time: _formatTime(topTime),
                            isOpponent: true,
                            isActive: _gameState.status == GameStatus.playing && _gameState.turn == topColor,
                            capturedPieces: topCaptured,
                            scoreAdvantage: scoreAdvantages[topColor],
                            capturedPiecesColor: topColor == PlayerColor.white ? PlayerColor.black : PlayerColor.white,
                          ),
                          
                          const SizedBox(height: 4),

                          // Game Board Area
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 0.0),
                            child: AspectRatio(
                              aspectRatio: 1.0,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final boardSize = constraints.maxWidth;
                                  final squareSize = boardSize / 10;
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapDown: (details) {
                                      print("TAP AT: ${details.localPosition}");
                                      final x = (details.localPosition.dx / squareSize).floor();
                                      final y = (details.localPosition.dy / squareSize).floor();
                                      print("SQUARE: ($x, $y)");
                                      _onSquareTapped(Position(
                                        widget.onlineRoomId != null && !widget.isWhite ? 9 - x : x,
                                        widget.onlineRoomId != null && !widget.isWhite ? 9 - y : y,
                                      ));
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10)),
                                        ],
                                      ),
                                      child: Stack(
                                        children: [
                                          // Layer 1: Board Squares (Background)
                                          SizedBox(
                                            width: boardSize,
                                            height: boardSize,
                                            child: _buildBoardBackground(squareSize, theme: _settings.boardTheme, showCoords: _settings.showCoordinates),
                                          ),

                                          // Layer 2: Background Highlights (Last Move, Selection, Check) - BELOW Images
                                          IgnorePointer(
                                            child: CustomPaint(
                                              size: Size(boardSize, boardSize),
                                              painter: BoardHighlightPainter(
                                                board: _gameState.board,
                                                selectedPosition: _gameState.selectedPosition,
                                                showLastMove: _settings.showLastMove,
                                                lastMove: _gameState.history.isNotEmpty ? _gameState.history.last : null,
                                                lastMoveStart: _gameState.lastMoveStart,
                                                lastMoveEnd: _gameState.lastMoveEnd,
                                                checkPos: RulesEngine.isCheck(_gameState.turn, _gameState.board) 
                                                   ? _findKing(_gameState.turn) 
                                                   : null,
                                                isWhite: widget.onlineRoomId == null ? true : widget.isWhite,
                                              ),
                                            ),
                                          ),
                                          
                                          // Layer 3: Pieces (Platform Views - Transparent Background)
                                          SizedBox(
                                            width: boardSize,
                                            height: boardSize,
                                            child: _buildPiecesLayer(squareSize),
                                          ),

                                          // Layer 4: Foreground Hints (Valid Moves) - ABOVE Images
                                          IgnorePointer(
                                            child: CustomPaint(
                                              size: Size(boardSize, boardSize),
                                              painter: BoardForegroundPainter(
                                                board: _gameState.board,
                                                validMoves: _settings.showLegalMoves ? _gameState.validMoves : [],
                                                isWhite: widget.onlineRoomId == null ? true : widget.isWhite,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 4),

                          // User Profile (Bottom)
                          PlayerProfileWidget(
                            name: bottomColor == PlayerColor.white ? _whitePlayerName : _blackPlayerName,
                            flagAsset: "assets/inflag.png",
                            avatarUrl: "", // Clear broken URL
                            time: _formatTime(bottomTime),
                            isOpponent: false,
                            isActive: _gameState.status == GameStatus.playing && _gameState.turn == bottomColor,
                            capturedPieces: bottomCaptured,
                            scoreAdvantage: scoreAdvantages[bottomColor],
                            capturedPiecesColor: bottomColor == PlayerColor.white ? PlayerColor.black : PlayerColor.white,
                          ),

                          const SizedBox(height: 8),

                          // Bottom Controls
                          BottomControls(
                            onDrawClaim: widget.onlineRoomId != null ? null : _handleDrawClaim, // Draw claim logic for online matches pending
                            canClaimDraw: _gameState.repetitionHistory.values.any((count) => count >= 3) || _gameState.fiftyMoveCounter >= 100,
                            onChat: (widget.onlineRoomId != null && !widget.isSpectator) ? _showChat : null,
                            onResign: (_gameState.status == GameStatus.playing && !widget.isSpectator) ? _showResignDialog : null,
                            showChatBadge: !widget.isSpectator && _hasNewMessages,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Floating Message Overlay (Top center)
          if (_lastChatMessage != null)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Text(
                    _lastChatMessage!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),

          if (_showGameOverOverlay) _buildGameOverOverlay(),
          
          // Waiting overlay when Player A is waiting for Player B to accept invitation
          if (_firebaseGameStatus == 'waiting') _buildWaitingOverlay(),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BoxConstraints constraints) {
    final bool amIWhite = widget.onlineRoomId == null ? true : widget.isWhite;
    final PlayerColor topColor = amIWhite ? PlayerColor.black : PlayerColor.white;
    final PlayerColor bottomColor = amIWhite ? PlayerColor.white : PlayerColor.black;
    final Duration topTime = topColor == PlayerColor.white ? _gameState.whiteTime : _gameState.blackTime;
    final Duration bottomTime = bottomColor == PlayerColor.white ? _gameState.whiteTime : _gameState.blackTime;

    final topCaptured = ScoreCalculator.getCapturedPieces(_gameState.history, topColor);
    final bottomCaptured = ScoreCalculator.getCapturedPieces(_gameState.history, bottomColor);
    final scoreAdvantages = ScoreCalculator.getScoreAdvantage(_gameState.history);

    // Calculate board size based on available height mostly, but also width
    final double sidebarWidth = 350;
    final double availableWidth = constraints.maxWidth - sidebarWidth - 64; // Padding
    final double availableHeight = constraints.maxHeight - 100; // Padding for header/footer
    final double boardSize = (availableWidth < availableHeight ? availableWidth : availableHeight).clamp(400, 800);

    return Row(
      children: [
        // Left Side: Board
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GameHeader(settings: widget.settings),
              const SizedBox(height: 20),
              Container(
                width: boardSize,
                height: boardSize,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20)),
                  ],
                ),
                child: _buildBoardWidget(boardSize),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),

        // Right Side: Sidebar
        Container(
          width: sidebarWidth,
          height: double.infinity,
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Column(
                children: [
                  // Opponent
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: PlayerProfileWidget(
                      name: topColor == PlayerColor.white ? _whitePlayerName : _blackPlayerName,
                      flagAsset: "assets/inflag.png",
                      avatarUrl: "",
                      time: _formatTime(topTime),
                      isOpponent: true,
                      isActive: _gameState.status == GameStatus.playing && _gameState.turn == topColor,
                      capturedPieces: topCaptured,
                      scoreAdvantage: scoreAdvantages[topColor],
                      capturedPiecesColor: topColor == PlayerColor.white ? PlayerColor.black : PlayerColor.white,
                    ),
                  ),
    
                  const Divider(color: Colors.white10, height: 1),
    
                  // Move History (Expanded for Desktop)
                  Expanded(
                    child: _buildDesktopMoveHistory(),
                  ),
    
                  const Divider(color: Colors.white10, height: 1),
    
                  // My Profile
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: PlayerProfileWidget(
                      name: bottomColor == PlayerColor.white ? _whitePlayerName : _blackPlayerName,
                      flagAsset: "assets/inflag.png",
                      avatarUrl: "",
                      time: _formatTime(bottomTime),
                      isOpponent: false,
                      isActive: _gameState.status == GameStatus.playing && _gameState.turn == bottomColor,
                      capturedPieces: bottomCaptured,
                      scoreAdvantage: scoreAdvantages[bottomColor],
                      capturedPiecesColor: bottomColor == PlayerColor.white ? PlayerColor.black : PlayerColor.white,
                    ),
                  ),
    
                  // Controls
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: BottomControls(
                      onDrawClaim: widget.onlineRoomId != null ? null : _handleDrawClaim,
                      canClaimDraw: _gameState.repetitionHistory.values.any((count) => count >= 3) || _gameState.fiftyMoveCounter >= 100,
                      onChat: (widget.onlineRoomId != null && !widget.isSpectator) ? _showChat : null,
                      onResign: (_gameState.status == GameStatus.playing && !widget.isSpectator) ? _showResignDialog : null,
                      showChatBadge: !widget.isSpectator && _hasNewMessages,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoardWidget(double boardSize) {
    final squareSize = boardSize / 10;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        final x = (details.localPosition.dx / squareSize).floor();
        final y = (details.localPosition.dy / squareSize).floor();
        _onSquareTapped(Position(
          widget.onlineRoomId != null && !widget.isWhite ? 9 - x : x,
          widget.onlineRoomId != null && !widget.isWhite ? 9 - y : y,
        ));
      },
      child: Stack(
        children: [
          // Layer 1: Board Squares
          SizedBox(
            width: boardSize,
            height: boardSize,
            child: _buildBoardBackground(squareSize, theme: _settings.boardTheme, showCoords: _settings.showCoordinates),
          ),

          // Layer 2: Background Highlights
          IgnorePointer(
            child: CustomPaint(
              size: Size(boardSize, boardSize),
              painter: BoardHighlightPainter(
                board: _gameState.board,
                selectedPosition: _gameState.selectedPosition,
                showLastMove: _settings.showLastMove,
                lastMove: _gameState.history.isNotEmpty ? _gameState.history.last : null,
                lastMoveStart: _gameState.lastMoveStart,
                lastMoveEnd: _gameState.lastMoveEnd,
                checkPos: RulesEngine.isCheck(_gameState.turn, _gameState.board) 
                   ? _findKing(_gameState.turn) 
                   : null,
                isWhite: widget.onlineRoomId == null ? true : widget.isWhite,
              ),
            ),
          ),
          
          // Layer 3: Pieces
          SizedBox(
            width: boardSize,
            height: boardSize,
            child: _buildPiecesLayer(squareSize),
          ),

          // Layer 4: Foreground Hints
          IgnorePointer(
            child: CustomPaint(
              size: Size(boardSize, boardSize),
              painter: BoardForegroundPainter(
                board: _gameState.board,
                validMoves: _settings.showLegalMoves ? _gameState.validMoves : [],
                isWhite: widget.onlineRoomId == null ? true : widget.isWhite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopMoveHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            "MOVE HISTORY",
            style: GoogleFonts.cinzel(
              color: const Color(0xFFD4AF37),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _moveScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: (_gameState.history.length / 2).ceil(),
            itemBuilder: (context, index) {
              final whiteMoveIndex = index * 2;
              final blackMoveIndex = index * 2 + 1;
              final moveNumber = index + 1;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        "$moveNumber.",
                        style: GoogleFonts.robotoMono(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                    Expanded(child: _buildMoveText(whiteMoveIndex)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMoveText(blackMoveIndex)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMoveText(int index) {
    if (index >= _gameState.history.length) return const SizedBox();
    
    final move = _gameState.history[index];
    final startFile = String.fromCharCode(97 + move.start.x);
    final startRank = 10 - move.start.y;
    final endFile = String.fromCharCode(97 + move.end.x);
    final endRank = 10 - move.end.y;
    final moveText = "$startFile$startRank-$endFile$endRank";

    final isLastMove = index == _gameState.history.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLastMove ? const Color(0xFFD4AF37).withOpacity(0.2) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isLastMove ? const Color(0xFFD4AF37).withOpacity(0.5) : Colors.transparent,
        ),
      ),
      child: Text(
        moveText,
        style: GoogleFonts.robotoMono(
          color: isLastMove ? const Color(0xFFD4AF37) : Colors.white70,
          fontWeight: isLastMove ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD4AF37), width: 1),
            boxShadow: [
              BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.2), blurRadius: 30, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Color(0xFFD4AF37), size: 48),
              const SizedBox(height: 20),
              Text(
                "GAME OVER",
                style: GoogleFonts.cinzel(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                _gameState.gameResult,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  print('🚀 QUIT: Tapped Quit to Menu. Popping BoardScreen.');
                  // Ensure we clear any pending state before leaving
                  _timer?.cancel();
                  _gameSubscription?.cancel();
                  _chatSubscription?.cancel();
                  _invitationSubscription?.cancel();
                  
                  // Use popUntil to go back to the previous stable screen (usually tournament or lobby)
                  // If we are deep in a stack, this ensures we exit the board completely.
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text('QUIT TO MENU', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
              ),
              if (widget.tournamentId != null) ...[
                const SizedBox(height: 16),
                Text(
                  "RETURNING TO COMMAND CENTER...",
                  style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildWaitingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD4AF37), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFFD4AF37),
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              Text(
                'Waiting for opponent to accept...',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Invitation sent',
                style: GoogleFonts.montserrat(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => _cancelInvitation(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  'CANCEL CHALLENGE',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _checkAndRecordOfflineGameOver() {
    if (_hasRecordedResult) return;
    
    final result = _gameState.status == GameStatus.whiteWon ? 'white_won' : 
                   (_gameState.status == GameStatus.blackWon ? 'black_won' : 'draw');
    
    final method = _gameState.gameResult.contains('Resigned') ? 'resignation' : 
                   (_gameState.gameResult.contains('time') ? 'timeout' : 'checkmate');

    final opponentName = widget.isVsComputer ? "Dynamo AI" : "Local Player";
    final myColor = widget.isWhite ? PlayerColor.white : PlayerColor.black;

    widget.onlineService?.recordOfflineGame(result, method, opponentName, myColor);
    _hasRecordedResult = true;
  }

  void _checkAndRecordOnlineGameOver() {
    if (_hasRecordedResult || widget.onlineRoomId == null) return;
    
    final result = _gameState.status == GameStatus.whiteWon ? 'white_won' : 
                   (_gameState.status == GameStatus.blackWon ? 'black_won' : 'draw');
    
    final method = _gameState.gameResult.contains('Resigned') ? 'resignation' : 
                   (_gameState.gameResult.contains('time') ? 'timeout' : 'checkmate');

    final winnerId = _gameState.status == GameStatus.whiteWon ? _whitePlayerId : 
                    (_gameState.status == GameStatus.blackWon ? _blackPlayerId : null);

    // 1. Update Game Node (Triggers stream for opponent)
    widget.onlineService!.recordGameResult(
      widget.onlineRoomId!,
      winnerId,
      result,
      method,
    );

    // 2. Report to Tournament Service if applicable
    if (widget.tournamentId != null && widget.roundNumber != null) {
      final whiteScore = result == 'white_won' ? 1.0 : (result == 'draw' ? 0.5 : 0.0);
      final blackScore = result == 'black_won' ? 1.0 : (result == 'draw' ? 0.5 : 0.0);
      
      TournamentService().reportMatchResult(
        widget.tournamentId!,
        widget.roundNumber!,
        widget.onlineRoomId!,
        whiteScore,
        blackScore,
      );
    }
    
    _hasRecordedResult = true;
  }

  void _showGameOverAndScheduleAutoQuit() {
    if (!mounted) return;
    setState(() {
      _showGameOverOverlay = true;
    });
    if (widget.tournamentId != null && !_hasScheduledAutoQuit) {
      _hasScheduledAutoQuit = true;
      print('🚀 AUTO-QUIT: Scheduled return to tournament dashboard in 10 seconds.');
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) {
          print('🚀 AUTO-QUIT: Returning to tournament dashboard.');
          Navigator.of(context).pop();
        }
      });
    }
  }

  void _showAbortedDialog({String? reason}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(reason?.contains("rejected") == true ? "Challenge Rejected" : "Game Aborted", 
             style: GoogleFonts.cinzel(color: Colors.redAccent)),
        content: Text(reason ?? "The opponent has left the game.", style: GoogleFonts.montserrat(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Exit to menu
            },
            child: const Text("Exit", style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _showResignDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("Resign Game?", style: GoogleFonts.cinzel(color: Colors.redAccent)),
        content: Text("Are you sure you want to resign? You will lose this game.", style: GoogleFonts.montserrat(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Cancel", style: GoogleFonts.montserrat(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleResignation();
            },
            child: Text("Resign", style: GoogleFonts.montserrat(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleResignation() {
    setState(() {
      final myColor = widget.onlineRoomId == null 
           ? _gameState.turn // Local: Resign current turn's player? Or user chooses? Using turn for simplicity
           : (widget.isWhite ? PlayerColor.white : PlayerColor.black);

      _gameState.resign(myColor);
      
      // Show overlay immediately for resignation
      _showGameOverAndScheduleAutoQuit();
      
      if (widget.onlineRoomId != null) {
        // Only update status - stream listener will handle recording
        widget.onlineService!.resignGame(widget.onlineRoomId!, myColor);
      }
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_moveScrollController.hasClients) {
        _moveScrollController.animateTo(
          _moveScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMoveHistory() {
    return Container(
      height: 40,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Left Arrow
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white54, size: 20),
            padding: EdgeInsets.zero,
            onPressed: () {
              _moveScrollController.animateTo(
                _moveScrollController.offset - 100,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
          
          // Scrollable Moves
          Expanded(
            child: ListView.builder(
              controller: _moveScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: _gameState.history.length,
              itemBuilder: (context, index) {
                final move = _gameState.history[index];
                final moveNumber = (index / 2).floor() + 1;
                final isWhite = index % 2 == 0;
                
                // Format: e2-e4
                final startFile = String.fromCharCode(97 + move.start.x);
                final startRank = 10 - move.start.y;
                final endFile = String.fromCharCode(97 + move.end.x);
                final endRank = 10 - move.end.y;
                final moveText = "$startFile$startRank-$endFile$endRank";

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: index == _gameState.history.length - 1 
                          ? const Color(0xFFD4AF37).withOpacity(0.5) 
                          : Colors.white10,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (isWhite)
                        Text("$moveNumber. ", style: GoogleFonts.robotoMono(color: Colors.white38, fontSize: 12)),
                      Text(
                        moveText,
                        style: GoogleFonts.robotoMono(
                          color: index == _gameState.history.length - 1 ? const Color(0xFFD4AF37) : Colors.white70,
                          fontWeight: index == _gameState.history.length - 1 ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Right Arrow
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
            padding: EdgeInsets.zero,
            onPressed: () {
              _moveScrollController.animateTo(
                _moveScrollController.offset + 100,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleDrawClaim() {
    setState(() {
      _gameState.claimDraw();
    });
  }
  
  Widget _buildBoardBackground(double squareSize, {String theme = 'classic', bool showCoords = true}) {
    final colors = _getThemeColors(theme);
    final lightColor = colors['light']!;
    final darkColor = colors['dark']!;
    final bool amIWhite = widget.onlineRoomId == null ? true : widget.isWhite;

    return Container(
      width: squareSize * 10,
      height: squareSize * 10,
      child: Stack(
        children: [
          // Grid of squares
          Column(
            children: List.generate(10, (y) {
              return Row(
                children: List.generate(10, (x) {
                  final isLight = (x + y) % 2 == 0;
                  return Container(
                    width: squareSize,
                    height: squareSize,
                    color: isLight ? lightColor : darkColor,
                  );
                }),
              );
            }),
          ),
          
          // Coordinate Labels (Optional)
          if (showCoords) ...[
            // Ranks (Numbers 1-10)
            ...List.generate(10, (y) {
              final rank = amIWhite ? (10 - y) : (y + 1);
              return Positioned(
                left: 2,
                top: y * squareSize + 2,
                child: Text(
                  rank.toString(),
                  style: TextStyle(
                    fontSize: 8,
                    color: (y % 2 == 0) ? darkColor.withOpacity(0.5) : lightColor.withOpacity(0.5),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
            // Files (Letters a-j)
            ...List.generate(10, (x) {
              final file = String.fromCharCode((amIWhite ? x : 9 - x) + 97);
              return Positioned(
                right: (9 - x) * squareSize + 2,
                bottom: 2,
                child: Text(
                  file,
                  style: TextStyle(
                    fontSize: 8,
                    color: (x % 2 != 0) ? darkColor.withOpacity(0.5) : lightColor.withOpacity(0.5),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Map<String, Color> _getThemeColors(String theme) {
    switch (theme) {
      case 'classic':
        return {
          'light': const Color(0xFFEBECD0),
          'dark': const Color(0xFF779556),
        };
      case 'wood':
        return {
          'light': const Color(0xFFDDB88C),
          'dark': const Color(0xFFA66D4F),
        };
      case 'emerald':
        return {
          'light': const Color(0xFFE0E0E0),
          'dark': const Color(0xFF00695C),
        };
      case 'onyx':
      default:
        return {
          'light': const Color(0xFF333333),
          'dark': const Color(0xFF1A1A1A),
        };
    }
  }

  Widget _buildPiecesLayer(double squareSize) {
    final bool amIWhite = widget.onlineRoomId == null ? true : widget.isWhite;
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: List.generate(10, (rawY) {
        return Row(
          mainAxisSize: MainAxisSize.max,
          children: List.generate(10, (rawX) {
            final x = amIWhite ? rawX : 9 - rawX;
            final y = amIWhite ? rawY : 9 - rawY;
            final pos = Position(x, y);
            final piece = _gameState.board.getPiece(pos);

            return SizedBox(
              width: squareSize,
              height: squareSize,
              child: piece == null ? null : IgnorePointer(
                child: _buildPieceWidget(piece, squareSize),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildPieceWidget(DynamoPiece piece, double squareSize) {
    final typeName = piece.type.toString().split('.').last;
    final colorSuffix = piece.color == PlayerColor.white ? 'w' : 'b';
    String assetName = '${typeName}_$colorSuffix.png'.toLowerCase(); 
    
    // Debug Log: Prove that we are actually trying to build this piece
    // print('� BUILDING: $assetName'); 

    // STRATEGY: Simple Image Widget (HTML <img> tag)
    // We verified the URL works manually. Now we put it in a standard Image widget.
    // We removed BoxDecoration because it might be interacting poorly with the CPU renderer.
    // We added a background color to confirm layout existence.
    // STRATEGY: Platform View (HTML <img> Tag Injection)
    // The Flutter rendering engine is bypassed. We inject a native HTML element.
    // This is the "Nuclear Option" for web rendering issues.
    
    // Construct the viewType that matches what we registered in main.dart
    final viewType = 'piece_${typeName}_${colorSuffix}';
    
    return Container(
      width: squareSize,
      height: squareSize,
      child: PlatformAssetImage(
        assetPath: 'assets/pieces/$assetName',
        viewType: viewType,
      ),
    );
  }

  String _getPieceIcon(DynamoPiece piece) {
    switch (piece.type) {
      case PieceType.king: return piece.color == PlayerColor.white ? '♔' : '♚';
      case PieceType.queen: return piece.color == PlayerColor.white ? '♕' : '♛';
      case PieceType.missile: return '☢';
      case PieceType.rook: return piece.color == PlayerColor.white ? '♖' : '♜';
      case PieceType.bishop: return piece.color == PlayerColor.white ? '♗' : '♝';
      case PieceType.knight: return piece.color == PlayerColor.white ? '♘' : '♞';
      case PieceType.pawn: return piece.color == PlayerColor.white ? '♙' : '♟';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _invitationTimeoutTimer?.cancel();
    _gameSubscription?.cancel();
    _invitationSubscription?.cancel();
    _chatSubscription?.cancel();
    _messageClearTimer?.cancel();
    if (widget.onlineRoomId != null && 
        widget.tournamentId == null && 
        !widget.onlineRoomId!.startsWith('tm_') &&
        (_gameState.status == GameStatus.playing || _firebaseGameStatus == 'waiting') && 
        !widget.isSpectator) {
       widget.onlineService?.leaveGame(widget.onlineRoomId!);
    }
    super.dispose();
  }
}
