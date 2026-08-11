import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/position_storage_service.dart';
import '../core/fen_converter.dart';
import '../core/models.dart';
import 'board_screen.dart';
import 'platform_asset_image.dart';

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
    final titleController = TextEditingController();
    final fenController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
        ),
        title: Text(
          "SAVE NEW POSITION",
          style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: GoogleFonts.montserrat(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Title / Name",
                labelStyle: GoogleFonts.montserrat(color: Colors.white54),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD4AF37))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fenController,
              style: GoogleFonts.montserrat(color: Colors.white),
              decoration: InputDecoration(
                labelText: "FEN Notation",
                labelStyle: GoogleFonts.montserrat(color: Colors.white54),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD4AF37))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: GoogleFonts.montserrat(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (fenController.text.trim().isNotEmpty) {
                await _service.savePosition(titleController.text, fenController.text.trim());
                if (mounted) Navigator.pop(context);
                _loadPositions();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black),
            child: Text("SAVE", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          ),
        ],
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
