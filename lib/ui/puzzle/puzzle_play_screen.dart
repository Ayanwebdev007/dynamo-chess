import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models.dart';
import '../../core/board.dart';
import '../../core/rules_engine.dart';
import '../../core/fen_converter.dart';
import '../../core/audio_service.dart';
import '../../core/puzzle_service.dart';
import '../../core/saved_puzzles_service.dart';
import '../platform_asset_image.dart';
import '../board_painter.dart';

class PuzzlePlayScreen extends StatefulWidget {
  final Puzzle puzzle;
  final VoidCallback onSolved;

  const PuzzlePlayScreen({
    super.key,
    required this.puzzle,
    required this.onSolved,
  });

  @override
  State<PuzzlePlayScreen> createState() => _PuzzlePlayScreenState();
}

class _PuzzlePlayScreenState extends State<PuzzlePlayScreen> {
  late DynamoBoard _board;
  late PlayerColor _currentTurn;
  int _currentMoveIndex = 0;
  bool _isSolved = false;
  bool _madeWrongMove = false;
  int _userMoveCount = 0;

  // Selected Board State
  Position? _selectedPosition;
  List<Position> _validMoves = [];
  Position? _lastMoveStart;
  Position? _lastMoveEnd;
  List<List<PuzzleMove>> _candidateSolutionLines = [];

  // Screen State
  bool _showSuccessOverlay = false;
  bool _showFailOverlay = false;
  bool _isSaved = false;

  Timer? _autoPlayTimer;
  Timer? _opponentTimer;
  Timer? _failTimer;

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _opponentTimer?.cancel();
    _failTimer?.cancel();
    super.dispose();
  }

  bool get isUserWhite => widget.puzzle.startTurn == PlayerColor.white;

  String _toCoord(Position pos) {
    final files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'];
    if (pos.x < 0 || pos.x >= 10 || pos.y < 0 || pos.y >= 10) return "??";
    final file = files[pos.x];
    final rank = 10 - pos.y;
    return '$file$rank';
  }

  String _formatMoveText(PuzzleMove move) {
    String text = "${_toCoord(move.start)} → ${_toCoord(move.end)}";
    if (move.promotionPiece != null) {
      final code = move.promotionPiece!.name.substring(0, 1).toUpperCase();
      text += " (=$code)";
    }
    return text;
  }

  void _autoPlaySolution() {
    _autoPlayTimer?.cancel();
    _resetPuzzle();

    int stepIndex = 0;
    _autoPlayTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (stepIndex >= widget.puzzle.solutionMoves.length) {
        timer.cancel();
        setState(() {
          _isSolved = true;
        });
        return;
      }

      final move = widget.puzzle.solutionMoves[stepIndex];
      final piece = _board.getPiece(move.start);
      final target = _board.getPiece(move.end);

      setState(() {
        if (target != null) {
          AudioService().playCapture();
        } else {
          AudioService().playMove();
        }

        final isPromotion = (piece != null &&
                piece.type == PieceType.pawn &&
                ((piece.color == PlayerColor.white && move.end.y == 0) ||
                    (piece.color == PlayerColor.black && move.end.y == 9))) ||
            move.promotionPiece != null;

        final finalPiece = isPromotion && piece != null
            ? DynamoPiece(
                type: move.promotionPiece ?? PieceType.queen,
                color: piece.color,
              )
            : piece;

        _board.setPiece(move.end, finalPiece);
        _board.setPiece(move.start, null);
        _lastMoveStart = move.start;
        _lastMoveEnd = move.end;

        stepIndex++;
      });
    });
  }

  void _showSolutionModal() {
    setState(() {
      _showFailOverlay = false;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final allSolutions = widget.puzzle.allSolutions;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb, color: Color(0xFFD4AF37), size: 24),
                      const SizedBox(width: 10),
                      Text(
                        "PUZZLE SOLUTION",
                        style: GoogleFonts.cinzel(
                          color: const Color(0xFFD4AF37),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "Valid solution sequence(s) for this challenge:",
                style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allSolutions.length,
                  itemBuilder: (context, lineIndex) {
                    final solutionMoves = allSolutions[lineIndex];
                    final pairsCount = (solutionMoves.length / 2).ceil();
                    final title = lineIndex == 0 ? "Main Line" : "Variation ${lineIndex + 1}";

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.montserrat(
                              color: const Color(0xFFD4AF37),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pairsCount,
                            itemBuilder: (context, index) {
                              final moveNum = index + 1;
                              final whiteMoveIndex = index * 2;
                              final blackMoveIndex = index * 2 + 1;

                              final whiteMove = solutionMoves[whiteMoveIndex];
                              final blackMove = blackMoveIndex < solutionMoves.length
                                  ? solutionMoves[blackMoveIndex]
                                  : null;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 28,
                                      child: Text(
                                        "$moveNum.",
                                        style: GoogleFonts.montserrat(
                                          color: const Color(0xFFD4AF37),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _formatMoveText(whiteMove),
                                        style: GoogleFonts.montserrat(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (blackMove != null)
                                      Expanded(
                                        child: Text(
                                          _formatMoveText(blackMove),
                                          style: GoogleFonts.montserrat(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                      )
                                    else
                                      const Spacer(),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _autoPlaySolution();
                      },
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text("AUTOPLAY ON BOARD"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _initPuzzle();
    _checkSavedStatus();
  }

  Future<void> _checkSavedStatus() async {
    final isSaved = await SavedPuzzlesService().isPuzzleSaved(widget.puzzle.id);
    if (mounted) setState(() => _isSaved = isSaved);
  }

  Future<void> _toggleSave() async {
    final nowSaved = await SavedPuzzlesService().toggleSavePuzzle(widget.puzzle.id);
    if (mounted) {
      setState(() => _isSaved = nowSaved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nowSaved ? 'Puzzle bookmarked!' : 'Puzzle bookmark removed', style: GoogleFonts.montserrat()),
          backgroundColor: const Color(0xFFD4AF37),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _initPuzzle() {
    _resetPuzzle();
  }

  void _resetPuzzle() {
    _autoPlayTimer?.cancel();
    _opponentTimer?.cancel();
    _failTimer?.cancel();
    setState(() {
      _board = DynamoBoard();
      _board.grid = FenConverter.fromFen(widget.puzzle.initialFen);
      _currentTurn = widget.puzzle.startTurn;
      _currentMoveIndex = 0;
      _isSolved = false;
      _madeWrongMove = false;
      _userMoveCount = 0;
      _showSuccessOverlay = false;
      _showFailOverlay = false;
      _selectedPosition = null;
      _validMoves = [];
      _candidateSolutionLines = List.from(widget.puzzle.allSolutions);
      if (widget.puzzle.previousMove != null) {
        _lastMoveStart = widget.puzzle.previousMove!.start;
        _lastMoveEnd = widget.puzzle.previousMove!.end;
      } else {
        _lastMoveStart = null;
        _lastMoveEnd = null;
      }
    });
  }

  void _onSquareTapped(Position pos) {
    if (_isSolved || _showFailOverlay) return;
    // Only allow taps during the user's turn
    if (_currentTurn != widget.puzzle.startTurn) return;

    _autoPlayTimer?.cancel();

    if (_validMoves.contains(pos) && _selectedPosition != null) {
      _checkAndExecuteUserMove(_selectedPosition!, pos);
      return;
    }

    final piece = _board.getPiece(pos);
    if (piece != null && piece.color == _currentTurn && _currentTurn == widget.puzzle.startTurn) {
      MoveRecord? lastMoveRecord;
      if (_currentMoveIndex > 0) {
        final prevMove = _candidateSolutionLines.isNotEmpty
            ? _candidateSolutionLines.first[_currentMoveIndex - 1]
            : widget.puzzle.solutionMoves[_currentMoveIndex - 1];
        lastMoveRecord = MoveRecord(
          start: prevMove.start,
          end: prevMove.end,
          pieceType: _board.getPiece(prevMove.end)?.type ?? PieceType.pawn,
          isCapture: false,
        );
      } else if (widget.puzzle.previousMove != null) {
        final prevMove = widget.puzzle.previousMove!;
        lastMoveRecord = MoveRecord(
          start: prevMove.start,
          end: prevMove.end,
          pieceType: _board.getPiece(prevMove.end)?.type ?? PieceType.pawn,
          isCapture: false,
        );
      }

      setState(() {
        _selectedPosition = pos;
        _validMoves = RulesEngine.getLegalMoves(
          pos,
          _board,
          lastMove: lastMoveRecord,
        );
      });
    } else {
      setState(() {
        _selectedPosition = null;
        _validMoves = [];
      });
    }
  }

  void _checkAndExecuteUserMove(Position start, Position end) {
    final piece = _board.getPiece(start);
    if (piece == null) return;

    final isPromotion = piece.type == PieceType.pawn &&
        ((piece.color == PlayerColor.white && end.y == 0) ||
            (piece.color == PlayerColor.black && end.y == 9));

    if (isPromotion) {
      _showPromotionDialog((selectedType) {
        _executeUserMove(start, end, chosenPromotion: selectedType);
      });
    } else {
      _executeUserMove(start, end);
    }
  }

  void _showPromotionDialog(Function(PieceType) onSelect) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
        ),
        title: Text(
          "PROMOTION",
          style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _promotionOption(PieceType.queen, "QUEEN", onSelect),
            _promotionOption(PieceType.missile, "MISSILE", onSelect),
            _promotionOption(PieceType.rook, "ROOK", onSelect),
            _promotionOption(PieceType.bishop, "BISHOP", onSelect),
            _promotionOption(PieceType.knight, "KNIGHT", onSelect),
          ],
        ),
      ),
    );
  }

  Widget _promotionOption(PieceType type, String label, Function(PieceType) onSelect) {
    return ListTile(
      title: Text(label, style: GoogleFonts.montserrat(color: Colors.white)),
      onTap: () {
        Navigator.of(context).pop();
        onSelect(type);
      },
    );
  }

  void _executeUserMove(Position start, Position end, {PieceType? chosenPromotion}) {
    // Find candidate solution line(s) matching move at _currentMoveIndex
    final matchingLines = _candidateSolutionLines.where((line) {
      if (_currentMoveIndex >= line.length) return false;
      final moveAtIdx = line[_currentMoveIndex];
      final isPosMatch = start == moveAtIdx.start && end == moveAtIdx.end;
      bool isPromoMatch = true;
      if (moveAtIdx.promotionPiece != null) {
        isPromoMatch = chosenPromotion == moveAtIdx.promotionPiece;
      }
      return isPosMatch && isPromoMatch;
    }).toList();

    final isCorrect = matchingLines.isNotEmpty;
    final piece = _board.getPiece(start);
    final target = _board.getPiece(end);

    _failTimer?.cancel();
    _opponentTimer?.cancel();

    if (!isCorrect) {
      // Immediate rejection of incorrect move
      final finalPiece = chosenPromotion != null && piece != null
          ? DynamoPiece(type: chosenPromotion, color: piece.color)
          : piece;

      setState(() {
        _madeWrongMove = true;
        _board.setPiece(end, finalPiece);
        _board.setPiece(start, null);
        _lastMoveStart = start;
        _lastMoveEnd = end;
        _selectedPosition = null;
        _validMoves = [];
        _isSolved = true;
      });

      AudioService().playGameOver();

      _failTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            _showFailOverlay = true;
          });
        }
      });
      return;
    }

    _candidateSolutionLines = matchingLines;

    setState(() {
      // Play sound
      if (target != null) {
        AudioService().playCapture();
      } else {
        AudioService().playMove();
      }

      // Execute the move on the board
      final finalPiece = chosenPromotion != null && piece != null
          ? DynamoPiece(type: chosenPromotion, color: piece.color)
          : piece;
      _board.setPiece(end, finalPiece);
      _board.setPiece(start, null);

      _lastMoveStart = start;
      _lastMoveEnd = end;

      _currentMoveIndex++;
      _userMoveCount++;
      _selectedPosition = null;
      _validMoves = [];

      final currentLine = _candidateSolutionLines.first;
      final targetUserMoves = (currentLine.length + 1) ~/ 2;

      // Check if user has completed all their moves
      if (_userMoveCount >= targetUserMoves) {
        _onPuzzleCompleted();
      } else if (_currentMoveIndex < currentLine.length) {
        // Trigger Opponent Move
        _currentTurn = (_currentTurn == PlayerColor.white)
            ? PlayerColor.black
            : PlayerColor.white;
        
        _opponentTimer = Timer(const Duration(milliseconds: 800), _executeOpponentMove);
      } else {
        // No more solution moves but user hasn't finished — puzzle ends
        _onPuzzleCompleted();
      }
    });
  }

  void _executeOpponentMove() {
    if (!mounted || _isSolved || _showFailOverlay || _currentTurn == widget.puzzle.startTurn) return;
    if (_candidateSolutionLines.isEmpty) return;
    final currentLine = _candidateSolutionLines.first;
    if (_currentMoveIndex >= currentLine.length) return;

    final expectedMove = currentLine[_currentMoveIndex];
    final piece = _board.getPiece(expectedMove.start);
    final target = _board.getPiece(expectedMove.end);

    // Opponent piece validation: piece must exist and belong to opponent
    final opponentColor = widget.puzzle.startTurn == PlayerColor.white
        ? PlayerColor.black
        : PlayerColor.white;

    if (piece == null || piece.color != opponentColor) {
      setState(() {
        _currentMoveIndex++;
        _currentTurn = widget.puzzle.startTurn;
        final targetUserMoves = (currentLine.length + 1) ~/ 2;
        // If no more moves, end the puzzle
        if (_userMoveCount >= targetUserMoves || _currentMoveIndex >= currentLine.length) {
          _onPuzzleCompleted();
        }
      });
      return;
    }

    // Keep candidate lines that match this opponent move
    _candidateSolutionLines = _candidateSolutionLines.where((line) {
      if (_currentMoveIndex >= line.length) return false;
      final m = line[_currentMoveIndex];
      return m.start == expectedMove.start &&
          m.end == expectedMove.end &&
          m.promotionPiece == expectedMove.promotionPiece;
    }).toList();

    setState(() {
      if (target != null) {
        AudioService().playCapture();
      } else {
        AudioService().playMove();
      }

      final isOpponentPromotion = (piece.type == PieceType.pawn &&
              ((piece.color == PlayerColor.white && expectedMove.end.y == 0) ||
                  (piece.color == PlayerColor.black && expectedMove.end.y == 9))) ||
          expectedMove.promotionPiece != null;

      final finalPiece = isOpponentPromotion
          ? DynamoPiece(
              type: expectedMove.promotionPiece ?? PieceType.queen,
              color: piece.color,
            )
          : piece;

      _board.setPiece(expectedMove.end, finalPiece);
      _board.setPiece(expectedMove.start, null);

      _lastMoveStart = expectedMove.start;
      _lastMoveEnd = expectedMove.end;

      _currentMoveIndex++;
      _currentTurn = widget.puzzle.startTurn; // Hand turn back to user
      
      final targetUserMoves = (currentLine.length + 1) ~/ 2;
      // Check if all user moves are done
      if (_userMoveCount >= targetUserMoves || _currentMoveIndex >= currentLine.length) {
        _onPuzzleCompleted();
      }
    });
  }

  void _onPuzzleCompleted() {
    _opponentTimer?.cancel();
    _failTimer?.cancel();
    AudioService().playGameOver();
    setState(() {
      _isSolved = true;
      if (_madeWrongMove) {
        _showFailOverlay = true;
      } else {
        widget.onSolved();
        _showSuccessOverlay = true;
      }
    });
  }

  Position? _findKing(PlayerColor color) {
    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 10; x++) {
        final piece = _board.getPiece(Position(x, y));
        if (piece != null && piece.type == PieceType.king && piece.color == color) {
          return Position(x, y);
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.5,
                colors: [
                  Color(0xFF1E3A20), // Dark green glow
                  Color(0xFF0A0E0A), // Black
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "SOLVE CHALLENGE",
                            style: GoogleFonts.cinzel(
                              color: const Color(0xFFD4AF37),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.lightbulb_outline, color: Color(0xFFD4AF37)),
                            onPressed: _showSolutionModal,
                            tooltip: "View Answer",
                          ),
                          IconButton(
                            icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: const Color(0xFFD4AF37)),
                            onPressed: _toggleSave,
                            tooltip: _isSaved ? "Remove Bookmark" : "Save Puzzle",
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.white70),
                            onPressed: _resetPuzzle,
                            tooltip: "Reset Puzzle",
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white10),

                // Puzzle info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    children: [
                      Text(
                        widget.puzzle.title.toUpperCase(),
                        style: GoogleFonts.cinzel(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${widget.puzzle.movesToWin} Move${widget.puzzle.movesToWin > 1 ? "s" : ""} to Win",
                        style: GoogleFonts.montserrat(
                          color: const Color(0xFFD4AF37),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.puzzle.description,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                      if (widget.puzzle.previousMove != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.history, size: 14, color: Color(0xFFD4AF37)),
                              const SizedBox(width: 6),
                              Text(
                                "Previous Move: ${_toCoord(widget.puzzle.previousMove!.start)} → ${_toCoord(widget.puzzle.previousMove!.end)}",
                                style: GoogleFonts.montserrat(
                                  color: const Color(0xFFD4AF37),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const Spacer(),

                // Board Screen
                Center(
                  child: _buildBoardWidget(),
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),

          if (_showSuccessOverlay) _buildSuccessOverlay(),
          if (_showFailOverlay) _buildFailOverlay(),
        ],
      ),
    );
  }

  Widget _buildBoardWidget() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth.clamp(300.0, 500.0);
        final squareSize = size / 10;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final rawX = (details.localPosition.dx / squareSize).floor();
            final rawY = (details.localPosition.dy / squareSize).floor();
            final x = isUserWhite ? rawX : 9 - rawX;
            final y = isUserWhite ? rawY : 9 - rawY;
            _onSquareTapped(Position(x, y));
          },
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Layer 1: Squares Background
                _buildBoardBackground(squareSize),

                // Layer 2: Highlights
                IgnorePointer(
                  child: CustomPaint(
                    size: Size(size, size),
                    painter: BoardHighlightPainter(
                      board: _board,
                      selectedPosition: _selectedPosition,
                      showLastMove: true,
                      lastMoveStart: _lastMoveStart,
                      lastMoveEnd: _lastMoveEnd,
                      checkPos: RulesEngine.isCheck(_currentTurn, _board)
                          ? _findKing(_currentTurn)
                          : null,
                      isWhite: isUserWhite,
                      theme: 'classic',
                    ),
                  ),
                ),

                // Layer 3: Pieces
                IgnorePointer(
                  child: Column(
                    children: List.generate(10, (rawY) {
                      return Row(
                        children: List.generate(10, (rawX) {
                          final x = isUserWhite ? rawX : 9 - rawX;
                          final y = isUserWhite ? rawY : 9 - rawY;
                          final pos = Position(x, y);
                          final piece = _board.getPiece(pos);

                          return SizedBox(
                            width: squareSize,
                            height: squareSize,
                            child: piece == null
                                ? null
                                : PlatformAssetImage(
                                    assetPath: 'assets/pieces/${piece.type.name}_${piece.color == PlayerColor.white ? "w" : "b"}.png',
                                    viewType: 'puzzle_piece_${piece.type.name}_${piece.color == PlayerColor.white ? "w" : "b"}',
                                  ),
                          );
                        }),
                      );
                    }),
                  ),
                ),

                // Layer 4: Foreground Hints
                IgnorePointer(
                  child: CustomPaint(
                    size: Size(size, size),
                    painter: BoardForegroundPainter(
                      board: _board,
                      validMoves: _validMoves,
                      isWhite: isUserWhite,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoardBackground(double squareSize) {
    const lightColor = Color(0xFFEBECD0);
    const darkColor = Color(0xFF779556);

    return Column(
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
    );
  }

  Widget _buildSuccessOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, color: Colors.greenAccent, size: 64),
              const SizedBox(height: 24),
              Text(
                "CHALLENGE SOLVED",
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Superb execution! The tactical configuration was successfully resolved.",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(fontSize: 13, color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  'CONTINUE',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFailOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE57373), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE57373).withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.close_rounded, color: Color(0xFFE57373), size: 64),
              const SizedBox(height: 24),
              Text(
                "INCORRECT",
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "That wasn't the winning sequence. Study the position and try again!",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(fontSize: 13, color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 32),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _resetPuzzle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE57373),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        'TRY AGAIN',
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showSolutionModal,
                      icon: const Icon(Icons.lightbulb_outline, size: 18),
                      label: const Text('VIEW ANSWER'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD4AF37),
                        side: const BorderSide(color: Color(0xFFD4AF37)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
