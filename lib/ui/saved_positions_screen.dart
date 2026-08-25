import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/position_storage_service.dart';
import '../core/fen_converter.dart';
import '../core/models.dart';
import 'board_screen.dart';
import 'platform_asset_image.dart';

import '../core/board.dart';

class SavedPositionsScreen extends StatefulWidget {
  const SavedPositionsScreen({super.key});

  @override
  State<SavedPositionsScreen> createState() => _SavedPositionsScreenState();
}

class _SavedPositionsScreenState extends State<SavedPositionsScreen> {
  final PositionStorageService _service = PositionStorageService();
  List<SavedPosition> _positions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPositions();
  }

  Future<void> _loadPositions() async {
    setState(() => _isLoading = true);
    final data = await _service.getSavedPositions();
    if (mounted) {
      setState(() {
        _positions = data;
        _isLoading = false;
      });
    }
  }

  void _showAddFenDialog() {
    showDialog(
      context: context,
      builder: (context) => PositionEditorDialog(
        onSave: (title, fen) async {
          await _service.savePosition(title, fen);
          _loadPositions();
        },
      ),
    );
  }

  void _loadPositionIntoGame(SavedPosition pos) {
    final startTurn = FenConverter.getTurn(pos.fen);
    final isWhiteTurn = startTurn == PlayerColor.white;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BoardScreen(
          settings: GameSettings.rapid10,
          isVsComputer: true,
          isWhite: isWhiteTurn,
          initialFen: pos.fen,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFD4AF37)),
          onPressed: () => Navigator.pop(context),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "SAVED POSITIONS",
            style: GoogleFonts.cinzel(
              color: const Color(0xFFD4AF37),
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: Color(0xFFD4AF37)),
            onPressed: _showAddFenDialog,
            tooltip: "Add Position FEN",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _positions.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _positions.length,
                  itemBuilder: (context, index) {
                    final item = _positions[index];
                    final turn = FenConverter.getTurn(item.fen);
                    return _buildPositionCard(item, turn);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bookmark_outline, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            "NO SAVED POSITIONS",
            style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Save positions during matches to practice or analyze later.",
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(color: Colors.white30, fontSize: 12),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddFenDialog,
            icon: const Icon(Icons.add),
            label: Text("ADD FEN POSITION", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionCard(SavedPosition item, PlayerColor turn) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 550;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMiniBoard(item.fen, constraints.maxWidth),
                  const SizedBox(width: 20),
                  Expanded(child: _buildCardDetails(item, turn)),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(child: _buildMiniBoard(item.fen, constraints.maxWidth)),
                const SizedBox(height: 16),
                _buildCardDetails(item, turn),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMiniBoard(String fen, double availableWidth) {
    final grid = FenConverter.fromFen(fen);
    final maxBoardWidth = (availableWidth - 32).clamp(140.0, 240.0);
    final squareSize = maxBoardWidth / 10;

    return Container(
      width: maxBoardWidth,
      height: maxBoardWidth,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5), width: 1.5),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(10, (y) {
          return Row(
            children: List.generate(10, (x) {
              final isLight = (x + y) % 2 == 0;
              final piece = grid[y][x];
              return Container(
                width: squareSize,
                height: squareSize,
                color: isLight ? const Color(0xFFEBECD0) : const Color(0xFF779556),
                child: piece == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.all(0.5),
                        child: PlatformAssetImage(
                          assetPath: 'assets/pieces/${piece.type.toString().split('.').last}_${piece.color == PlayerColor.white ? 'w' : 'b'}.png'.toLowerCase(),
                          viewType: 'mini_piece_${piece.type.toString().split('.').last}_${piece.color == PlayerColor.white ? 'w' : 'b'}',
                        ),
                      ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildCardDetails(SavedPosition item, PlayerColor turn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                item.title,
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFD4AF37),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              item.createdAt,
              style: GoogleFonts.montserrat(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: turn == PlayerColor.white ? Colors.white24 : Colors.black87,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5)),
              ),
              child: Text(
                turn == PlayerColor.white ? "WHITE TO MOVE" : "BLACK TO MOVE",
                style: GoogleFonts.montserrat(
                  color: turn == PlayerColor.white ? Colors.white : const Color(0xFFD4AF37),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SelectableText(
          item.fen,
          style: GoogleFonts.robotoMono(color: Colors.white54, fontSize: 10),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _loadPositionIntoGame(item),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text("PLAY POSITION", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.white54, size: 20),
              tooltip: "Copy FEN",
              onPressed: () {
                Clipboard.setData(ClipboardData(text: item.fen));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("FEN copied to clipboard!", style: GoogleFonts.montserrat()),
                    backgroundColor: const Color(0xFFD4AF37),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              tooltip: "Delete Position",
              onPressed: () async {
                await _service.deletePosition(item.id);
                _loadPositions();
              },
            ),
          ],
        ),
      ],
    );
  }
}

class PositionEditorDialog extends StatefulWidget {
  final Function(String title, String fen) onSave;

  const PositionEditorDialog({super.key, required this.onSave});

  @override
  State<PositionEditorDialog> createState() => _PositionEditorDialogState();
}

class _PositionEditorDialogState extends State<PositionEditorDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _fenController = TextEditingController();
  late DynamoBoard _board;
  PlayerColor _startTurn = PlayerColor.white;
  PieceType? _selectedType = PieceType.queen;
  PlayerColor? _selectedColor = PlayerColor.white;

  @override
  void initState() {
    super.initState();
    _board = DynamoBoard();
    _board.initializeBoard();
    _updateFen();
  }

  void _updateFen() {
    final fen = FenConverter.toFen(_board.grid, _startTurn);
    _fenController.text = fen;
  }

  void _onSquareTapped(Position pos) {
    setState(() {
      if (_selectedColor == null || _selectedType == null) {
        _board.setPiece(pos, null);
      } else {
        _board.setPiece(pos, DynamoPiece(type: _selectedType!, color: _selectedColor!));
      }
      _updateFen();
    });
  }

  void _loadStandardBoard() {
    setState(() {
      _board = DynamoBoard();
      _board.initializeBoard();
      _updateFen();
    });
  }

  void _clearBoard() {
    setState(() {
      _board = DynamoBoard();
      _updateFen();
    });
  }

  void _applyFenInput(String fen) {
    if (fen.trim().isEmpty) return;
    try {
      final newGrid = FenConverter.fromFen(fen.trim());
      final turn = FenConverter.getTurn(fen.trim());
      setState(() {
        _board.grid = newGrid;
        _startTurn = turn;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("FEN applied successfully!"),
          backgroundColor: Color(0xFFD4AF37),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Invalid Dynamo FEN: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "BOARD EDITOR & FEN",
                    style: GoogleFonts.cinzel(
                      color: const Color(0xFFD4AF37),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & Turn Row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _titleController,
                            style: GoogleFonts.montserrat(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: "Position Title",
                              labelStyle: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12),
                              hintText: "e.g., Endgame Practice #1",
                              hintStyle: GoogleFonts.montserrat(color: Colors.white24, fontSize: 12),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.03),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.white12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<PlayerColor>(
                            value: _startTurn,
                            dropdownColor: const Color(0xFF2A2A2A),
                            decoration: InputDecoration(
                              labelText: "To Move",
                              labelStyle: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.03),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.white12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: PlayerColor.white,
                                child: Text("White", style: TextStyle(color: Colors.white, fontSize: 13)),
                              ),
                              DropdownMenuItem(
                                value: PlayerColor.black,
                                child: Text("Black", style: TextStyle(color: Colors.white, fontSize: 13)),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _startTurn = val;
                                  _updateFen();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quick Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _quickActionButton("Starting Setup", Icons.refresh, _loadStandardBoard),
                        _quickActionButton("Clear Board", Icons.clear_all, _clearBoard),
                        _quickActionButton("Copy FEN", Icons.copy, () {
                          Clipboard.setData(ClipboardData(text: _fenController.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("FEN copied to clipboard!"),
                              backgroundColor: Color(0xFFD4AF37),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Board + Piece Palettes
                    Center(
                      child: Column(
                        children: [
                          _buildPiecePalette(PlayerColor.black),
                          const SizedBox(height: 8),
                          _buildBoardWidget(),
                          const SizedBox(height: 8),
                          _buildPiecePalette(PlayerColor.white),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // FEN input / live display
                    Text(
                      "DYNAMO CHESS FEN NOTATION",
                      style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _fenController,
                            style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 11),
                            decoration: InputDecoration(
                              hintText: "Paste or edit Dynamo FEN...",
                              hintStyle: GoogleFonts.robotoMono(color: Colors.white24, fontSize: 11),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.03),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.white12),
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
                          onPressed: () => _applyFenInput(_fenController.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
                            foregroundColor: const Color(0xFFD4AF37),
                            side: const BorderSide(color: Color(0xFFD4AF37)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text("APPLY", style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Footer actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white60,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("CANCEL", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final title = _titleController.text.trim().isEmpty
                            ? "Custom Position"
                            : _titleController.text.trim();
                        final fen = _fenController.text.trim();
                        if (fen.isNotEmpty) {
                          widget.onSave(title, fen);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("SAVE POSITION", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFD4AF37)),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPiecePalette(PlayerColor color) {
    final types = [
      PieceType.pawn,
      PieceType.knight,
      PieceType.bishop,
      PieceType.missile,
      PieceType.rook,
      PieceType.queen,
      PieceType.king,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...types.map((type) => _buildPaletteItem(type, color)),
          if (color == PlayerColor.white) ...[
            const SizedBox(width: 6),
            _buildEraserItem(),
          ],
        ],
      ),
    );
  }

  Widget _buildPaletteItem(PieceType type, PlayerColor color) {
    final isSelected = _selectedColor == color && _selectedType == type;
    final typeName = type.toString().split('.').last;
    final colorSuffix = color == PlayerColor.white ? 'w' : 'b';
    final assetName = '${typeName}_$colorSuffix.png'.toLowerCase();

    return InkWell(
      onTap: () {
        setState(() {
          _selectedColor = color;
          _selectedType = type;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: PlatformAssetImage(
          assetPath: 'assets/pieces/$assetName',
          viewType: 'palette_item_${typeName}_$colorSuffix',
        ),
      ),
    );
  }

  Widget _buildEraserItem() {
    final isSelected = _selectedColor == null;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedColor = null;
          _selectedType = null;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.redAccent.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.redAccent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: const Icon(Icons.cleaning_services, size: 16, color: Colors.white70),
      ),
    );
  }

  Widget _buildBoardWidget() {
    const double size = 280;
    const double squareSize = size / 10;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5), width: 1.5),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background squares & tap detection
          Column(
            children: List.generate(10, (y) {
              return Row(
                children: List.generate(10, (x) {
                  final isLight = (x + y) % 2 == 0;
                  final pos = Position(x, y);

                  return GestureDetector(
                    onTap: () => _onSquareTapped(pos),
                    child: Container(
                      width: squareSize,
                      height: squareSize,
                      color: isLight ? const Color(0xFFEBECD0) : const Color(0xFF779556),
                    ),
                  );
                }),
              );
            }),
          ),

          // Piece layer
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
                              padding: const EdgeInsets.all(2),
                              child: PlatformAssetImage(
                                assetPath: 'assets/pieces/${piece.type.toString().split('.').last}_${piece.color == PlayerColor.white ? 'w' : 'b'}.png'.toLowerCase(),
                                viewType: 'editor_piece_${pos.x}_${pos.y}',
                              ),
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
  }
}
