import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models.dart';
import '../../core/board.dart';
import '../../core/rules_engine.dart';
import '../../core/fen_converter.dart';
import '../../core/puzzle_service.dart';
import '../platform_asset_image.dart';

enum CreatorStep { setup, recording, review }

class AdminPuzzleCreator extends StatefulWidget {
  final Puzzle? existingPuzzle;
  const AdminPuzzleCreator({super.key, this.existingPuzzle});

  @override
  State<AdminPuzzleCreator> createState() => _AdminPuzzleCreatorState();
}

class _AdminPuzzleCreatorState extends State<AdminPuzzleCreator> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _fenController = TextEditingController();
  final _prevStartController = TextEditingController();
  final _prevEndController = TextEditingController();

  CreatorStep _step = CreatorStep.setup;
  PlayerColor _startTurn = PlayerColor.white;
  int _movesToWin = 1;

  // Board Setup State
  final DynamoBoard _board = DynamoBoard();
  PieceType? _selectedPaletteType;
  PlayerColor? _selectedPaletteColor; // null means eraser tool is selected

  // Recording State
  PlayerColor _currentTurn = PlayerColor.white;
  Position? _selectedPosition;
  List<Position> _validMoves = [];
  final List<PuzzleMove> _recordedMoves = [];
  List<PuzzleMove> _mainSolutionMoves = [];
  final List<List<PuzzleMove>> _alternativeSolutions = [];
  int _recordingLineIndex = 0; // 0 = main line, 1+ = alt line
  String _initialFen = '';

  // Review Playback State
  int _reviewMoveIndex = 0;
  Position? _lastMoveStart;
  Position? _lastMoveEnd;

  @override
  void initState() {
    super.initState();
    if (widget.existingPuzzle != null) {
      final p = widget.existingPuzzle!;
      _titleController.text = p.title;
      _descController.text = p.description;
      _startTurn = p.startTurn;
      _movesToWin = p.movesToWin;
      _initialFen = p.initialFen;
      _board.grid = FenConverter.fromFen(p.initialFen);
      _mainSolutionMoves = List.from(p.solutionMoves);
      _alternativeSolutions.addAll(p.alternativeSolutions.map((line) => List<PuzzleMove>.from(line)));
      if (p.previousMove != null) {
        _prevStartController.text = _toCoord(p.previousMove!.start);
        _prevEndController.text = _toCoord(p.previousMove!.end);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _fenController.dispose();
    _prevStartController.dispose();
    _prevEndController.dispose();
    super.dispose();
  }

  Position? _parseCoord(String input) {
    input = input.trim().toLowerCase();
    if (input.length < 2) return null;
    final fileChar = input[0];
    final rankStr = input.substring(1);
    final files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'];
    final x = files.indexOf(fileChar);
    final rank = int.tryParse(rankStr);
    if (x == -1 || rank == null || rank < 1 || rank > 10) return null;
    final y = 10 - rank;
    return Position(x, y);
  }

  void _onSquareTapped(Position pos) {
    if (_step == CreatorStep.setup) {
      setState(() {
        if (_selectedPaletteColor == null) {
          // Eraser active
          _board.setPiece(pos, null);
        } else {
          // Place piece
          final type = _selectedPaletteType!;
          final color = _selectedPaletteColor!;

          // Prevent pawns on the first or last rank
          if (type == PieceType.pawn && (pos.y == 0 || pos.y == 9)) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Pawns cannot be placed on the first or last rank."),
                backgroundColor: Colors.redAccent,
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }

          // Count current pieces of this color (excluding the square we are placing on)
          int totalColorPieces = 0;
          int typeCount = 0;
          for (int y = 0; y < 10; y++) {
            for (int x = 0; x < 10; x++) {
              final p = _board.getPiece(Position(x, y));
              if (p != null && p.color == color && Position(x, y) != pos) {
                totalColorPieces++;
                if (p.type == type) {
                  typeCount++;
                }
              }
            }
          }

          // Enforce piece limits
          if (totalColorPieces >= 20) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Cannot place more than 20 pieces for ${color.name.toUpperCase()}."),
                backgroundColor: Colors.redAccent,
              ),
            );
            return;
          }

          int limit = 19;
          if (type == PieceType.king) limit = 1;
          else if (type == PieceType.pawn) limit = 10;

          if (typeCount >= limit) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Cannot place more than $limit ${type.name.toUpperCase()}s for ${color.name.toUpperCase()}."),
                backgroundColor: Colors.redAccent,
              ),
            );
            return;
          }

          // If placing a King, auto-move/reposition the existing King of the same color
          if (type == PieceType.king) {
            for (int y = 0; y < 10; y++) {
              for (int x = 0; x < 10; x++) {
                final oldPiece = _board.getPiece(Position(x, y));
                if (oldPiece != null &&
                    oldPiece.type == PieceType.king &&
                    oldPiece.color == color) {
                  _board.setPiece(Position(x, y), null);
                }
              }
            }
          }

          _board.setPiece(
            pos,
            DynamoPiece(
              type: type,
              color: color,
            ),
          );
        }
      });
    } else if (_step == CreatorStep.recording) {
      if (_validMoves.contains(pos) && _selectedPosition != null) {
        _checkAndExecuteRecordMove(_selectedPosition!, pos);
        return;
      }

      final piece = _board.getPiece(pos);
      if (piece != null && piece.color == _currentTurn) {
        setState(() {
          _selectedPosition = pos;
          _validMoves = RulesEngine.getLegalMoves(
            pos,
            _board,
            lastMove: _recordedMoves.isNotEmpty
                ? MoveRecord(
                    start: _recordedMoves.last.start,
                    end: _recordedMoves.last.end,
                    pieceType: _board.getPiece(_recordedMoves.last.end)?.type ?? PieceType.pawn,
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
  }

  void _checkAndExecuteRecordMove(Position start, Position end) {
    final piece = _board.getPiece(start);
    if (piece == null) return;

    final isPromotion = piece.type == PieceType.pawn &&
        ((piece.color == PlayerColor.white && end.y == 0) ||
            (piece.color == PlayerColor.black && end.y == 9));

    if (isPromotion) {
      _showPromotionDialog((selectedType) {
        _executeRecordMove(start, end, promotionPiece: selectedType);
      });
    } else {
      _executeRecordMove(start, end);
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

  void _executeRecordMove(Position start, Position end, {PieceType? promotionPiece}) {
    final piece = _board.getPiece(start);
    if (piece == null) return;

    setState(() {
      // Execute on board
      final finalPiece = promotionPiece != null
          ? DynamoPiece(type: promotionPiece, color: piece.color)
          : piece;
      _board.setPiece(end, finalPiece);
      _board.setPiece(start, null);

      // Record move
      _recordedMoves.add(PuzzleMove(start: start, end: end, promotionPiece: promotionPiece));

      // Switch turn
      _currentTurn = (_currentTurn == PlayerColor.white)
          ? PlayerColor.black
          : PlayerColor.white;

      _selectedPosition = null;
      _validMoves = [];

      // Check if recording is complete
      final requiredMovesCount = 2 * _movesToWin - 1;
      if (_recordedMoves.length >= requiredMovesCount) {
        if (_recordingLineIndex == 0) {
          _mainSolutionMoves = List.from(_recordedMoves);
        } else {
          final altIndex = _recordingLineIndex - 1;
          if (altIndex < _alternativeSolutions.length) {
            _alternativeSolutions[altIndex] = List.from(_recordedMoves);
          } else {
            _alternativeSolutions.add(List.from(_recordedMoves));
          }
        }
        _step = CreatorStep.review;
        _reviewMoveIndex = _recordedMoves.length;
        _updateReviewBoard();
      }
    });
  }

  void _undoLastMove() {
    if (_recordedMoves.isEmpty) return;
    setState(() {
      _recordedMoves.removeLast();
      
      // Rebuild board state up to new length of _recordedMoves
      _board.grid = FenConverter.fromFen(_initialFen);
      for (final mv in _recordedMoves) {
        final piece = _board.getPiece(mv.start);
        if (piece != null) {
          final targetPiece = mv.promotionPiece != null
              ? DynamoPiece(type: mv.promotionPiece!, color: piece.color)
              : piece;
          _board.setPiece(mv.end, targetPiece);
          _board.setPiece(mv.start, null);
        }
      }

      // Revert turn
      _currentTurn = (_currentTurn == PlayerColor.white)
          ? PlayerColor.black
          : PlayerColor.white;

      _selectedPosition = null;
      _validMoves = [];
    });
  }

  String? _getSetupValidationError() {
    int whiteKings = 0;
    int blackKings = 0;
    Position? whiteKingPos;
    Position? blackKingPos;

    int whiteCount = 0;
    int blackCount = 0;
    final whiteTypes = <PieceType, int>{};
    final blackTypes = <PieceType, int>{};
    for (var t in PieceType.values) {
      whiteTypes[t] = 0;
      blackTypes[t] = 0;
    }

    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 10; x++) {
        final p = _board.getPiece(Position(x, y));
        if (p != null) {
          if (p.color == PlayerColor.white) {
            whiteCount++;
            whiteTypes[p.type] = (whiteTypes[p.type] ?? 0) + 1;
            if (p.type == PieceType.king) {
              whiteKings++;
              whiteKingPos = Position(x, y);
            }
          } else {
            blackCount++;
            blackTypes[p.type] = (blackTypes[p.type] ?? 0) + 1;
            if (p.type == PieceType.king) {
              blackKings++;
              blackKingPos = Position(x, y);
            }
          }
        }
      }
    }

    if (whiteKings == 0 && blackKings == 0) {
      return "A puzzle must have a White King and a Black King.";
    }
    if (whiteKings == 0) {
      return "A puzzle must have a White King.";
    }
    if (blackKings == 0) {
      return "A puzzle must have a Black King.";
    }

    // Kings cannot be adjacent
    if (whiteKingPos != null && blackKingPos != null) {
      final isAdjacent = (whiteKingPos.x - blackKingPos.x).abs() <= 1 &&
          (whiteKingPos.y - blackKingPos.y).abs() <= 1;
      if (isAdjacent) {
        return "Kings cannot be placed on adjacent squares.";
      }
    }

    // Check piece limits
    if (whiteCount > 20) return "White has too many pieces (max 20).";
    if (blackCount > 20) return "Black has too many pieces (max 20).";

    if ((whiteTypes[PieceType.pawn] ?? 0) > 10) return "White has too many pawns (max 10).";
    if ((blackTypes[PieceType.pawn] ?? 0) > 10) return "Black has too many pawns (max 10).";

    // Inactive player's King cannot be in check
    final inactiveColor = (_startTurn == PlayerColor.white)
        ? PlayerColor.black
        : PlayerColor.white;
    if (RulesEngine.isCheck(inactiveColor, _board)) {
      return "The inactive player's King (${inactiveColor.name.toUpperCase()}) cannot be in check.";
    }

    // Starting player must have legal moves (no initial checkmate/stalemate)
    final hasMoves = RulesEngine.hasLegalMoves(_startTurn, _board);
    if (!hasMoves) {
      return "The starting player (${_startTurn.name.toUpperCase()}) has no legal moves (checkmate or stalemate).";
    }

    // Check if solution moves count matches Moves to Win target
    final requiredMovesCount = 2 * _movesToWin - 1;
    if (_mainSolutionMoves.isNotEmpty && _mainSolutionMoves.length != requiredMovesCount) {
      return "Existing solution (${_mainSolutionMoves.length} moves) does not match 'Moves to Win' setting ($requiredMovesCount moves total). Please re-record solution.";
    }

    return null;
  }

  void _startRecording() {
    if (!_formKey.currentState!.validate()) return;
    if (_getSetupValidationError() != null) return;

    setState(() {
      _initialFen = FenConverter.toFen(_board.grid, _startTurn);
      _currentTurn = _startTurn;
      _step = CreatorStep.recording;
      _recordedMoves.clear();
      _selectedPosition = null;
      _validMoves = [];
      _lastMoveStart = null;
      _lastMoveEnd = null;
    });
  }

  void _resetRecording() {
    setState(() {
      _board.grid = FenConverter.fromFen(_initialFen);
      _currentTurn = _startTurn;
      _step = CreatorStep.recording;
      _recordedMoves.clear();
      _selectedPosition = null;
      _validMoves = [];
      _lastMoveStart = null;
      _lastMoveEnd = null;
    });
  }

  void _reviewPrev() {
    if (_reviewMoveIndex > 0) {
      setState(() {
        _reviewMoveIndex--;
        _updateReviewBoard();
      });
    }
  }

  void _reviewNext() {
    final activeMoves = _mainSolutionMoves.isNotEmpty ? _mainSolutionMoves : _recordedMoves;
    if (_reviewMoveIndex < activeMoves.length) {
      setState(() {
        _reviewMoveIndex++;
        _updateReviewBoard();
      });
    }
  }

  void _updateReviewBoard() {
    final activeMoves = _mainSolutionMoves.isNotEmpty ? _mainSolutionMoves : _recordedMoves;
    _board.grid = FenConverter.fromFen(_initialFen);
    for (int i = 0; i < _reviewMoveIndex; i++) {
      if (i >= activeMoves.length) break;
      final mv = activeMoves[i];
      final piece = _board.getPiece(mv.start);
      if (piece != null) {
        final targetPiece = mv.promotionPiece != null
            ? DynamoPiece(type: mv.promotionPiece!, color: piece.color)
            : piece;
        _board.setPiece(mv.end, targetPiece);
        _board.setPiece(mv.start, null);
      }
    }
    if (_reviewMoveIndex > 0 && _reviewMoveIndex <= activeMoves.length) {
      _lastMoveStart = activeMoves[_reviewMoveIndex - 1].start;
      _lastMoveEnd = activeMoves[_reviewMoveIndex - 1].end;
    } else {
      _lastMoveStart = null;
      _lastMoveEnd = null;
    }
  }

  void _clearBoard() {
    setState(() {
      _board.grid = List.generate(10, (_) => List.generate(10, (_) => null));
    });
  }

  void _loadStandardBoard() {
    setState(() {
      _board.grid = List.generate(10, (_) => List.generate(10, (_) => null));
      _board.initializeBoard();
    });
  }

  void _loadFen() {
    final fen = _fenController.text.trim();
    if (fen.isEmpty) return;
    try {
      final newGrid = FenConverter.fromFen(fen);
      final turn = FenConverter.getTurn(fen);
      setState(() {
        _board.grid = newGrid;
        _startTurn = turn;
        _fenController.clear();
      });
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("FEN loaded successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Invalid FEN format: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _copyFen() {
    final fen = FenConverter.toFen(_board.grid, _startTurn);
    Clipboard.setData(ClipboardData(text: fen));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("FEN configuration copied to clipboard!")),
    );
  }

  void _startRecordingAlternativeLine() {
    setState(() {
      _board.grid = FenConverter.fromFen(_initialFen);
      _currentTurn = _startTurn;
      _step = CreatorStep.recording;
      _recordedMoves.clear();
      _recordingLineIndex = _alternativeSolutions.length + 1;
      _selectedPosition = null;
      _validMoves = [];
      _lastMoveStart = null;
      _lastMoveEnd = null;
    });
  }

  void _deleteAlternativeLine(int index) {
    setState(() {
      _alternativeSolutions.removeAt(index);
    });
  }

  void _savePuzzle() async {
    final mainMoves = _mainSolutionMoves.isNotEmpty ? _mainSolutionMoves : _recordedMoves;

    PuzzleMove? prevMove;
    final startPos = _parseCoord(_prevStartController.text);
    final endPos = _parseCoord(_prevEndController.text);
    if (startPos != null && endPos != null) {
      prevMove = PuzzleMove(start: startPos, end: endPos);
    }

    final puzzleId = widget.existingPuzzle?.id ?? PuzzleService().generatePuzzleId();

    final puzzle = Puzzle(
      id: puzzleId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      initialFen: _initialFen,
      movesToWin: _movesToWin,
      startTurn: _startTurn,
      solutionMoves: mainMoves,
      alternativeSolutions: _alternativeSolutions,
      previousMove: prevMove,
    );

    try {
      await PuzzleService().savePuzzle(puzzle);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Puzzle saved successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving puzzle: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _toCoord(Position pos) {
    final files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'];
    final file = files[pos.x];
    final rank = 10 - pos.y;
    return '$file$rank';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      appBar: AppBar(
        title: Text(
          "PUZZLE CREATOR",
          style: GoogleFonts.cinzel(
            color: const Color(0xFFD4AF37),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Step progress indicator header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            child: _buildWizardHeader(),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Side: Settings / Wizard Steps controls
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_step == CreatorStep.setup) ...[
                            Text(
                              "PUZZLE DETAILS",
                              style: GoogleFonts.cinzel(
                                color: const Color(0xFFD4AF37),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildTextField(_titleController, "Title", "e.g. Back Rank Mate"),
                            const SizedBox(height: 16),
                            _buildTextField(_descController, "Description", "e.g. White to move and checkmate in 2 moves.", maxLines: 3),
                            const SizedBox(height: 24),
                            _buildTurnDropdown(),
                            const SizedBox(height: 24),
                            _buildMovesDropdown(),
                            const SizedBox(height: 24),
                            
                            // Previous Move (Optional)
                            Text(
                              "PREVIOUS MOVE BEFORE PUZZLE (OPTIONAL)",
                              style: GoogleFonts.cinzel(
                                color: const Color(0xFFD4AF37),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Opponent's move right before puzzle turn (e.g. e7 to e5).",
                              style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _prevStartController,
                                    style: GoogleFonts.montserrat(color: Colors.white, fontSize: 13),
                                    decoration: InputDecoration(
                                      labelText: "Start Square",
                                      labelStyle: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12),
                                      hintText: "e.g. e7",
                                      hintStyle: GoogleFonts.montserrat(color: Colors.white24, fontSize: 12),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.02),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _prevEndController,
                                    style: GoogleFonts.montserrat(color: Colors.white, fontSize: 13),
                                    decoration: InputDecoration(
                                      labelText: "End Square",
                                      labelStyle: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12),
                                      hintText: "e.g. e5",
                                      hintStyle: GoogleFonts.montserrat(color: Colors.white24, fontSize: 12),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.02),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            
                            // FEN Actions
                            Text(
                              "FEN CONFIGURATION",
                              style: GoogleFonts.cinzel(
                                color: const Color(0xFFD4AF37),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _fenController,
                                    style: GoogleFonts.montserrat(color: Colors.white, fontSize: 12),
                                    decoration: InputDecoration(
                                      hintText: "Paste FEN code here",
                                      hintStyle: GoogleFonts.montserrat(color: Colors.white24, fontSize: 12),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.02),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _loadFen,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD4AF37),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text("LOAD", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _copyFen,
                                icon: const Icon(Icons.copy, size: 14),
                                label: const Text("COPY CURRENT BOARD FEN"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white60,
                                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Board quick setup
                            Text(
                              "BOARD UTILITIES",
                              style: GoogleFonts.cinzel(
                                color: const Color(0xFFD4AF37),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _loadStandardBoard,
                                    icon: const Icon(Icons.grid_on, size: 14),
                                    label: const Text("STANDARD"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: BorderSide(color: Colors.white.withOpacity(0.15)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _clearBoard,
                                    icon: const Icon(Icons.layers_clear, size: 14),
                                    label: const Text("CLEAR"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.redAccent,
                                      side: const BorderSide(color: Colors.redAccent),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 48),

                            // Realtime Error Label & Proceed Button
                            Builder(
                              builder: (context) {
                                final error = _getSetupValidationError();
                                if (error != null) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            error,
                                            style: GoogleFonts.montserrat(
                                              color: Colors.redAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "Board configuration valid.",
                                            style: GoogleFonts.montserrat(
                                              color: Colors.greenAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                            ),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _getSetupValidationError() == null ? _startRecording : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD4AF37),
                                  foregroundColor: Colors.black,
                                  disabledBackgroundColor: Colors.white.withOpacity(0.05),
                                  disabledForegroundColor: Colors.white24,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _mainSolutionMoves.isNotEmpty ? "RE-RECORD SOLUTION MOVES" : "PROCEED TO RECORD SOLUTION",
                                  style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            if (_mainSolutionMoves.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: OutlinedButton(
                                  onPressed: _getSetupValidationError() == null
                                      ? () => setState(() => _step = CreatorStep.review)
                                      : null,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    "SKIP TO PREVIEW & SAVE (KEEP EXISTING MOVES)",
                                    style: GoogleFonts.montserrat(
                                        fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ],
                          
                          if (_step == CreatorStep.recording) ...[
                            Text(
                              "RECORD SOLUTION MOVES",
                              style: GoogleFonts.cinzel(
                                color: const Color(0xFFD4AF37),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Interactively play the solution sequence directly on the chessboard.",
                              style: GoogleFonts.montserrat(color: Colors.white60, fontSize: 13),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37).withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.15)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _currentTurn == PlayerColor.white ? Colors.white : Colors.black,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Text(
                                      _currentTurn.name.toUpperCase(),
                                      style: GoogleFonts.montserrat(
                                        color: _currentTurn == PlayerColor.white ? Colors.black : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "PLAYING MOVE ${_recordedMoves.length + 1} OF ${2 * _movesToWin - 1}",
                                          style: GoogleFonts.montserrat(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          _recordedMoves.length % 2 == 0
                                              ? "Play the winning move for the user."
                                              : "Play the defensive reply for the opponent.",
                                          style: GoogleFonts.montserrat(
                                            color: Colors.white54,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Moves history timeline list
                            Text(
                              _recordedMoves.isNotEmpty
                                  ? "RECORDED SEQUENCE"
                                  : (_mainSolutionMoves.isNotEmpty ? "EARLIER SET SOLUTION MOVES" : "RECORDED SEQUENCE"),
                              style: GoogleFonts.cinzel(
                                color: const Color(0xFFD4AF37),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildMovesHistoryListFor(_recordedMoves.isNotEmpty
                                ? _recordedMoves
                                : (_mainSolutionMoves.isNotEmpty ? _mainSolutionMoves : [])),
                            const SizedBox(height: 32),
                            
                            // Control buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _recordedMoves.isNotEmpty ? _undoLastMove : null,
                                    icon: const Icon(Icons.undo, size: 16),
                                    label: const Text("UNDO LAST"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD4AF37),
                                      foregroundColor: Colors.black,
                                      disabledBackgroundColor: Colors.white.withOpacity(0.03),
                                      disabledForegroundColor: Colors.white12,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _step = CreatorStep.setup;
                                        _board.grid = FenConverter.fromFen(_initialFen);
                                        _recordedMoves.clear();
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.redAccent,
                                      side: const BorderSide(color: Colors.redAccent),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text("ABANDON"),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          if (_step == CreatorStep.review) ...[
                            Text(
                              "REVIEW SOLUTION",
                              style: GoogleFonts.cinzel(
                                color: const Color(0xFFD4AF37),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Preview and step through the moves to confirm correct configuration.",
                              style: GoogleFonts.montserrat(color: Colors.white60, fontSize: 13),
                            ),
                            const SizedBox(height: 24),
                            
                            // Playback controls widget
                            Builder(
                              builder: (context) {
                                final activeMoves = _mainSolutionMoves.isNotEmpty ? _mainSolutionMoves : _recordedMoves;
                                return Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.01),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withOpacity(0.03)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.navigate_before, color: Colors.white70, size: 32),
                                        onPressed: _reviewMoveIndex > 0 ? _reviewPrev : null,
                                      ),
                                      const SizedBox(width: 24),
                                      Text(
                                        "Move $_reviewMoveIndex of ${activeMoves.length}",
                                        style: GoogleFonts.montserrat(
                                          color: const Color(0xFFD4AF37),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      IconButton(
                                        icon: const Icon(Icons.navigate_next, color: Colors.white70, size: 32),
                                        onPressed: _reviewMoveIndex < activeMoves.length ? _reviewNext : null,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 32),
                            
                             Text(
                              "MAIN SOLUTION LINE",
                              style: GoogleFonts.cinzel(
                                color: const Color(0xFFD4AF37),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildMovesHistoryListFor(_mainSolutionMoves.isNotEmpty ? _mainSolutionMoves : _recordedMoves),
                            const SizedBox(height: 24),
                            if (_alternativeSolutions.isNotEmpty) ...[
                              Text(
                                "ALTERNATIVE VARIATION LINES",
                                style: GoogleFonts.cinzel(
                                  color: const Color(0xFFD4AF37),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...List.generate(_alternativeSolutions.length, (altIdx) {
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
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Variation ${altIdx + 2}",
                                            style: GoogleFonts.montserrat(
                                              color: const Color(0xFFD4AF37),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                            onPressed: () => _deleteAlternativeLine(altIdx),
                                          ),
                                        ],
                                      ),
                                      _buildMovesHistoryListFor(_alternativeSolutions[altIdx]),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 16),
                            ],
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _startRecordingAlternativeLine,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text("+ ADD ALTERNATIVE SOLUTION LINE"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFD4AF37),
                                  side: const BorderSide(color: Color(0xFFD4AF37)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Publish buttons
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _savePuzzle,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  "SAVE & PUBLISH PUZZLE",
                                  style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _resetRecording,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text("RE-RECORD MOVES"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: BorderSide(color: Colors.white.withOpacity(0.15)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Right Side: Chess Board and Piece Palette
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.black.withOpacity(0.2),
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Left Side: White Palette
                              if (_step == CreatorStep.setup) ...[
                                _buildVerticalPalette(PlayerColor.white),
                                const SizedBox(width: 32),
                              ],

                              // Center: Chess Board and Eraser Tool
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildBoard(),
                                  if (_step == CreatorStep.setup) ...[
                                    const SizedBox(height: 24),
                                    _buildEraserButton(),
                                  ],
                                ],
                              ),

                              // Right Side: Black Palette
                              if (_step == CreatorStep.setup) ...[
                                const SizedBox(width: 32),
                                _buildVerticalPalette(PlayerColor.black),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWizardHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildWizardStep(1, "SETUP DETAILS", CreatorStep.setup),
          _buildWizardConnector(),
          _buildWizardStep(2, "RECORD MOVES", CreatorStep.recording),
          _buildWizardConnector(),
          _buildWizardStep(3, "PREVIEW & SAVE", CreatorStep.review),
        ],
      ),
    );
  }

  Widget _buildWizardStep(int number, String label, CreatorStep step) {
    final isActive = _step == step;
    final isDone = _step.index > step.index;
    
    Color stepColor = Colors.white24;
    if (isActive) {
      stepColor = const Color(0xFFD4AF37);
    } else if (isDone) {
      stepColor = Colors.greenAccent;
    }

    return InkWell(
      onTap: () {
        if (_getSetupValidationError() == null) {
          setState(() {
            _step = step;
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: stepColor.withOpacity(0.1),
                border: Border.all(color: stepColor, width: 2),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 16, color: Colors.greenAccent)
                    : Text(
                        "$number",
                        style: GoogleFonts.montserrat(
                          color: stepColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.cinzel(
                color: isActive ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWizardConnector() {
    return Expanded(
      child: Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.white.withOpacity(0.05),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.montserrat(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.montserrat(color: Colors.white54, fontSize: 14),
        hintText: hint,
        hintStyle: GoogleFonts.montserrat(color: Colors.white24, fontSize: 14),
        filled: true,
        fillColor: Colors.white.withOpacity(0.02),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return "$label is required";
        return null;
      },
    );
  }

  Widget _buildTurnDropdown() {
    return DropdownButtonFormField<PlayerColor>(
      value: _startTurn,
      dropdownColor: const Color(0xFF1E1E1E),
      decoration: InputDecoration(
        labelText: "Starting Turn",
        labelStyle: GoogleFonts.montserrat(color: Colors.white54, fontSize: 14),
        filled: true,
        fillColor: Colors.white.withOpacity(0.02),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
        ),
      ),
      items: const [
        DropdownMenuItem(
          value: PlayerColor.white,
          child: Text("White", style: TextStyle(color: Colors.white)),
        ),
        DropdownMenuItem(
          value: PlayerColor.black,
          child: Text("Black", style: TextStyle(color: Colors.white)),
        ),
      ],
      onChanged: _step != CreatorStep.setup
          ? null
          : (val) {
              if (val != null) setState(() => _startTurn = val);
            },
    );
  }

  Widget _buildMovesDropdown() {
    return DropdownButtonFormField<int>(
      value: _movesToWin,
      dropdownColor: const Color(0xFF1E1E1E),
      decoration: InputDecoration(
        labelText: "Moves to Win",
        labelStyle: GoogleFonts.montserrat(color: Colors.white54, fontSize: 14),
        filled: true,
        fillColor: Colors.white.withOpacity(0.02),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
        ),
      ),
      items: List.generate(10, (index) => index + 1).map((m) {
        return DropdownMenuItem(
          value: m,
          child: Text("$m Move${m > 1 ? "s" : ""}", style: const TextStyle(color: Colors.white)),
        );
      }).toList(),
      onChanged: _step != CreatorStep.setup
          ? null
          : (val) {
              if (val != null) setState(() => _movesToWin = val);
            },
    );
  }

  Widget _buildBoard() {
    const lightColor = Color(0xFFEBECD0);
    const darkColor = Color(0xFF779556);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth.clamp(300.0, 520.0);
        final squareSize = size / 10;

        return Container(
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
              // Grid Background
              Column(
                children: List.generate(10, (y) {
                  return Row(
                    children: List.generate(10, (x) {
                      final isLight = (x + y) % 2 == 0;
                      final pos = Position(x, y);

                      // Determine highlight color
                      Color? highlight;
                      if (_step == CreatorStep.recording) {
                        if (_selectedPosition == pos) {
                          highlight = const Color(0xFF64B5F6).withOpacity(0.6); // Selected
                        } else if (_validMoves.contains(pos)) {
                          highlight = const Color(0xFF81C784).withOpacity(0.6); // Legal move target
                        }
                      } else if (_step == CreatorStep.review) {
                        if (_lastMoveStart == pos || _lastMoveEnd == pos) {
                          highlight = const Color(0xFFD4AF37).withOpacity(0.4); // Highlight played review move
                        }
                      }

                      return GestureDetector(
                        onTap: () => _onSquareTapped(pos),
                        child: Container(
                          width: squareSize,
                          height: squareSize,
                          color: highlight ?? (isLight ? lightColor : darkColor),
                        ),
                      );
                    }),
                  );
                }),
              ),

              // Pieces
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
                              : Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: _buildPieceWidget(piece),
                                ),
                        );
                      }),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPieceWidget(DynamoPiece piece) {
    final typeName = piece.type.toString().split('.').last;
    final colorSuffix = piece.color == PlayerColor.white ? 'w' : 'b';
    String assetName = '${typeName}_$colorSuffix.png'.toLowerCase();
    final viewType = 'creator_piece_${typeName}_${colorSuffix}';

    return PlatformAssetImage(
      assetPath: 'assets/pieces/$assetName',
      viewType: viewType,
    );
  }

  Widget _buildVerticalPalette(PlayerColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            color == PlayerColor.white ? "WHITE" : "BLACK",
            style: GoogleFonts.montserrat(
              color: const Color(0xFFD4AF37),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          ...PieceType.values.map((type) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _buildPaletteButton(type, color),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPaletteButton(PieceType type, PlayerColor color) {
    final isSelected = _selectedPaletteType == type && _selectedPaletteColor == color;
    final typeName = type.toString().split('.').last;
    final colorSuffix = color == PlayerColor.white ? 'w' : 'b';
    String assetName = '${typeName}_$colorSuffix.png'.toLowerCase();

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaletteType = type;
          _selectedPaletteColor = color;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: PlatformAssetImage(
          assetPath: 'assets/pieces/$assetName',
          viewType: 'palette_${typeName}_$colorSuffix',
        ),
      ),
    );
  }

  Widget _buildEraserButton() {
    final isSelected = _selectedPaletteColor == null;

    return OutlinedButton.icon(
      onPressed: () {
        setState(() {
          _selectedPaletteType = null;
          _selectedPaletteColor = null;
        });
      },
      icon: const Icon(Icons.cleaning_services, size: 16),
      label: const Text("ERASER TOOL"),
      style: OutlinedButton.styleFrom(
        foregroundColor: isSelected ? const Color(0xFFD4AF37) : Colors.white60,
        side: BorderSide(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.white12,
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  String _formatMoveText(PuzzleMove move) {
    String text = "${_toCoord(move.start)} → ${_toCoord(move.end)}";
    if (move.promotionPiece != null) {
      final code = move.promotionPiece!.name.substring(0, 1).toUpperCase();
      text += " (=$code)";
    }
    return text;
  }

  Widget _buildMovesHistoryList() {
    return _buildMovesHistoryListFor(_recordedMoves);
  }

  Widget _buildMovesHistoryListFor(List<PuzzleMove> moves) {
    if (moves.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            "No moves recorded yet.",
            style: GoogleFonts.montserrat(color: Colors.white24, fontSize: 13),
          ),
        ),
      );
    }

    final pairsCount = (moves.length / 2).ceil();
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.all(12),
        itemCount: pairsCount,
        itemBuilder: (context, index) {
          final moveNum = index + 1;
          final whiteMoveIndex = index * 2;
          final blackMoveIndex = index * 2 + 1;

          final whiteMove = moves[whiteMoveIndex];
          final blackMove = blackMoveIndex < moves.length
              ? moves[blackMoveIndex]
              : null;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    "$moveNum.",
                    style: GoogleFonts.montserrat(
                      color: const Color(0xFFD4AF37),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatMoveText(whiteMove),
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (blackMove != null)
                  Expanded(
                    child: Text(
                      _formatMoveText(blackMove),
                      style: GoogleFonts.montserrat(
                        color: Colors.white60,
                        fontSize: 13,
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
    );
  }
}
