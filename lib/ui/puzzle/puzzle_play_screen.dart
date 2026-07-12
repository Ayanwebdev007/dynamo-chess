import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models.dart';
import '../../core/board.dart';
import '../../core/rules_engine.dart';
import '../../core/fen_converter.dart';
import '../../core/audio_service.dart';
import '../../core/puzzle_service.dart';
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

  // Selected Board State
  Position? _selectedPosition;
  List<Position> _validMoves = [];
  Position? _lastMoveStart;
  Position? _lastMoveEnd;

  // Screen State
  bool _showSuccessOverlay = false;

  @override
  void initState() {
    super.initState();
    _resetPuzzle();
  }

  void _resetPuzzle() {
    setState(() {
      _board = DynamoBoard();
      _board.grid = FenConverter.fromFen(widget.puzzle.initialFen);
      _currentTurn = widget.puzzle.startTurn;
      _currentMoveIndex = 0;
      _isSolved = false;
      _showSuccessOverlay = false;
      _selectedPosition = null;
      _validMoves = [];
      _lastMoveStart = null;
      _lastMoveEnd = null;
    });
  }

  void _onSquareTapped(Position pos) {
    if (_isSolved || _currentTurn != widget.puzzle.startTurn) return;

    if (_validMoves.contains(pos) && _selectedPosition != null) {
      _executeUserMove(_selectedPosition!, pos);
      return;
    }

    final piece = _board.getPiece(pos);
    if (piece != null && piece.color == _currentTurn) {
      setState(() {
        _selectedPosition = pos;
        _validMoves = RulesEngine.getLegalMoves(
          pos,
          _board,
          lastMove: _currentMoveIndex > 0
              ? MoveRecord(
                  start: widget.puzzle.solutionMoves[_currentMoveIndex - 1].start,
                  end: widget.puzzle.solutionMoves[_currentMoveIndex - 1].end,
                  pieceType: _board.getPiece(widget.puzzle.solutionMoves[_currentMoveIndex - 1].end)?.type ?? PieceType.pawn,
                  isCapture: false,
                )
              : null,
        );
      });
    } else {
      setState(() {
        _selectedPosition = null;
        _validMoves = [];
      });
    }
  }

  void _executeUserMove(Position start, Position end) {
    // Check if correct move
    final expectedMove = widget.puzzle.solutionMoves[_currentMoveIndex];
    final isCorrect = start == expectedMove.start && end == expectedMove.end;

    if (!isCorrect) {
      // Revert/Alert
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Incorrect move. Try again! Board reset to starting position."),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      _resetPuzzle();
      return;
    }

    final piece = _board.getPiece(start);
    final target = _board.getPiece(end);

    setState(() {
      // Play sound
      if (target != null) {
        AudioService().playCapture();
      } else {
        AudioService().playMove();
      }

      // Execute on board
      _board.setPiece(end, piece);
      _board.setPiece(start, null);

      _lastMoveStart = start;
      _lastMoveEnd = end;

      _currentMoveIndex++;
      _selectedPosition = null;
      _validMoves = [];

      // Check if complete
      if (_currentMoveIndex >= widget.puzzle.solutionMoves.length) {
        _onPuzzleCompleted();
      } else {
        // Trigger Opponent Move
        _currentTurn = (_currentTurn == PlayerColor.white)
            ? PlayerColor.black
            : PlayerColor.white;
        
        Timer(const Duration(milliseconds: 800), _executeOpponentMove);
      }
    });
  }

  void _executeOpponentMove() {
    if (_isSolved || _currentMoveIndex >= widget.puzzle.solutionMoves.length) return;

    final expectedMove = widget.puzzle.solutionMoves[_currentMoveIndex];
    final piece = _board.getPiece(expectedMove.start);
    final target = _board.getPiece(expectedMove.end);

    if (piece == null) return;

    setState(() {
      if (target != null) {
        AudioService().playCapture();
      } else {
        AudioService().playMove();
      }

      _board.setPiece(expectedMove.end, piece);
      _board.setPiece(expectedMove.start, null);

      _lastMoveStart = expectedMove.start;
      _lastMoveEnd = expectedMove.end;

      _currentMoveIndex++;
      _currentTurn = widget.puzzle.startTurn; // Hand turn back to user
      
      // Check if complete (just in case)
      if (_currentMoveIndex >= widget.puzzle.solutionMoves.length) {
        _onPuzzleCompleted();
      }
    });
  }

  void _onPuzzleCompleted() {
    AudioService().playGameOver();
    widget.onSolved();
    setState(() {
      _isSolved = true;
      _showSuccessOverlay = true;
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
                      Text(
                        "SOLVE CHALLENGE",
                        style: GoogleFonts.cinzel(
                          color: const Color(0xFFD4AF37),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        onPressed: _resetPuzzle,
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
            final x = (details.localPosition.dx / squareSize).floor();
            final y = (details.localPosition.dy / squareSize).floor();
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
                      isWhite: true,
                      theme: 'classic',
                    ),
                  ),
                ),

                // Layer 3: Pieces
                IgnorePointer(
                  child: Column(
                    children: List.generate(10, (y) {
                      return Row(
                        children: List.generate(10, (x) {
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
                      isWhite: true,
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
}
