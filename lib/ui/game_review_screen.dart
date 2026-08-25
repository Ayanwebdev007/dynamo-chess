import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/models.dart';
import '../core/fen_converter.dart';
import '../core/pgn_service.dart';
import 'platform_asset_image.dart';
import 'pgn_dialog.dart';

class GameReviewScreen extends StatefulWidget {
  final Map<String, dynamic> gameData;
  final String opponentName;
  final String myColor;
  final String? whitePlayerName;
  final String? blackPlayerName;

  const GameReviewScreen({
    super.key,
    required this.gameData,
    required this.opponentName,
    required this.myColor,
    this.whitePlayerName,
    this.blackPlayerName,
  });

  @override
  State<GameReviewScreen> createState() => _GameReviewScreenState();
}

class _GameReviewScreenState extends State<GameReviewScreen> {
  late List<Map<String, dynamic>> _moves;
  List<String> _formattedMoves = [];
  int _currentMoveIndex = -1; // -1 means starting position
  late String _startingFen;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Correct 10x10 starting FEN matching Dynamo Chess piece order:
    // Rook, Knight, Bishop, Missile (Dynamo), Queen, King, Missile (Dynamo), Bishop, Knight, Rook
    _startingFen = widget.gameData['initialFen']?.toString() ??
        "rnbmqkmbnr/pppppppppp/10/10/10/10/10/10/PPPPPPPPPP/RNBMQKMBNR w - -";
    _parseMoves();
  }

  void _parseMoves() {
    final history = widget.gameData['moveHistory'];
    if (history == null) {
      _moves = [];
      return;
    }

    final Map<dynamic, dynamic> historyMap = Map.from(history);
    _moves = historyMap.entries.map((e) => Map<String, dynamic>.from(e.value)).toList();
    
    // Sort by timestamp
    _moves.sort((a, b) => (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0));
    
    // Default to the last move
    if (_moves.isNotEmpty) {
      _currentMoveIndex = _moves.length - 1;
    }
    _formattedMoves = PgnService.getFormattedMovesList(_buildMoveRecords(), initialFen: _startingFen);
  }

  List<MoveRecord> _buildMoveRecords() {
    List<MoveRecord> records = [];
    for (int i = 0; i < _moves.length; i++) {
      final move = _moves[i];
      final fromMap = move['from'] as Map?;
      final toMap = move['to'] as Map?;
      if (fromMap == null || toMap == null) continue;

      final fromX = fromMap['x'] as int;
      final fromY = fromMap['y'] as int;
      final toX = toMap['x'] as int;
      final toY = toMap['y'] as int;

      final prevFen = i == 0 ? _startingFen : _moves[i - 1]['fen'] as String;
      final prevBoard = FenConverter.fromFen(prevFen);
      final piece = prevBoard[fromY][fromX];
      final targetPiece = prevBoard[toY][toX];
      final isCapture = targetPiece != null || (piece?.type == PieceType.pawn && fromX != toX);

      PieceType pieceType = piece?.type ?? PieceType.pawn;
      if (move['pieceType'] != null) {
        final ptStr = move['pieceType'].toString().toLowerCase();
        pieceType = PieceType.values.firstWhere(
          (t) => t.name == ptStr,
          orElse: () => piece?.type ?? PieceType.pawn,
        );
      }

      records.add(MoveRecord(
        start: Position(fromX, fromY),
        end: Position(toX, toY),
        pieceType: pieceType,
        isCapture: isCapture,
        capturedPieceType: targetPiece?.type,
      ));
    }
    return records;
  }

  void _showPgnDialog() {
    final isWhite = widget.myColor == 'white';
    final whiteName = widget.whitePlayerName ?? (isWhite ? "You" : widget.opponentName);
    final blackName = widget.blackPlayerName ?? (isWhite ? widget.opponentName : "You");
    final result = widget.gameData['result']?.toString() ?? 'draw';
    final method = widget.gameData['method']?.toString() ?? 'normal';

    showDialog(
      context: context,
      builder: (context) => PgnDialog(
        whitePlayer: whiteName,
        blackPlayer: blackName,
        result: result,
        history: _buildMoveRecords(),
        event: "Dynamo Chess Match Review",
        termination: method,
        initialFen: _startingFen,
      ),
    );
  }

  String get _currentFen {
    if (_currentMoveIndex == -1) return _startingFen;
    return _moves[_currentMoveIndex]['fen'];
  }

  @override
  Widget build(BuildContext context) {
    final board = FenConverter.fromFen(_currentFen);
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("GAME REVIEW", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Color(0xFFD4AF37)),
            tooltip: "Export PGN",
            onPressed: _showPgnDialog,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth > 800;
          
          if (isWide) {
            return Column(
              children: [
                _buildMatchHeader(isMobile: false),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Center(child: _buildBoard(board))),
                          const SizedBox(width: 32),
                          Expanded(flex: 2, child: _buildMoveHistoryList(isMobile: false)),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildControls(isMobile: false),
              ],
            );
          }

          // Mobile-First Vertical Layout
          return Column(
            children: [
              _buildMatchHeader(isMobile: true),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildBoard(board),
                      _buildMoveHistoryList(isMobile: true),
                      const SizedBox(height: 100), // Space for fixed bottom controls
                    ],
                  ),
                ),
              ),
              _buildControls(isMobile: true),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMatchHeader({required bool isMobile}) {
    final result = widget.gameData['result']?.toUpperCase() ?? "COMPLETED";
    final wName = widget.whitePlayerName ?? (widget.myColor == 'white' ? "YOU" : widget.opponentName);
    final bName = widget.blackPlayerName ?? (widget.myColor == 'white' ? widget.opponentName : "YOU");
    final method = widget.gameData['method']?.toString().toUpperCase() ?? "COMPLETED";
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPlayerInfo(wName, PlayerColor.white, isMobile),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40),
            child: Column(
              children: [
                Text(result, style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontWeight: FontWeight.w900, fontSize: isMobile ? 14 : 18)),
                Text(method, style: GoogleFonts.montserrat(color: Colors.white24, fontSize: 8, letterSpacing: 1.2)),
              ],
            ),
          ),
          _buildPlayerInfo(bName, PlayerColor.black, isMobile),
        ],
      ),
    );
  }

  Widget _buildPlayerInfo(String name, PlayerColor color, bool isMobile) {
    return Column(
      children: [
        CircleAvatar(
          radius: isMobile ? 14 : 20,
          backgroundColor: color == PlayerColor.white ? Colors.white10 : Colors.black,
          child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?", style: TextStyle(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: isMobile ? 10 : 14)),
        ),
        const SizedBox(height: 4),
        Text(name, style: GoogleFonts.montserrat(color: Colors.white70, fontSize: isMobile ? 9 : 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  bool get isUserWhite => widget.myColor.toLowerCase() != 'black';

  Widget _buildBoard(List<List<DynamoPiece?>> board) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, spreadRadius: 10),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final squareSize = constraints.maxWidth / 10;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 10,
                childAspectRatio: 1.0,
              ),
              itemCount: 100,
              itemBuilder: (context, index) {
                final rawX = index % 10;
                final rawY = (index / 10).floor();
                final x = isUserWhite ? rawX : 9 - rawX;
                final y = isUserWhite ? rawY : 9 - rawY;
                final piece = board[y][x];
                final isDark = (rawX + rawY) % 2 != 0;
                
                return Container(
                  color: isDark ? const Color(0xFF779556) : const Color(0xFFEBECD0),
                  child: piece == null ? null : _buildPiece(piece, squareSize),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPiece(DynamoPiece piece, double size) {
    final typeName = piece.type.toString().split('.').last;
    final colorSuffix = piece.color == PlayerColor.white ? 'w' : 'b';
    final assetName = '${typeName}_$colorSuffix.png'.toLowerCase();
    
    return Center(
      child: PlatformAssetImage(
        assetPath: 'assets/pieces/$assetName',
        viewType: 'piece_${typeName}_${colorSuffix}',
        width: size * 0.8,
        height: size * 0.8,
      ),
    );
  }

  Widget _buildMoveHistoryList({required bool isMobile}) {
    return Container(
      margin: EdgeInsets.all(isMobile ? 12 : 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "MOVE LOG",
                  style: GoogleFonts.cinzel(
                    color: const Color(0xFFD4AF37),
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_moves.isNotEmpty)
                  Text(
                    "${_moves.length} moves",
                    style: GoogleFonts.montserrat(color: Colors.white38, fontSize: 11),
                  )
                else
                  const Icon(Icons.history_toggle_off, color: Colors.white24, size: 16),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          isMobile
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: _buildMoveListView(),
                )
              : Expanded(
                  child: _buildMoveListView(),
                ),
        ],
      ),
    );
  }

  Widget _buildMoveListView() {
    if (_moves.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, color: Colors.white24, size: 32),
              const SizedBox(height: 16),
              Text(
                "HISTORY NOT RECORDED",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Match DNA recording was enabled today.",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(color: Colors.white12, fontSize: 8),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _moves.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildMoveItem(-1, "STARTING POSITION", "");
        }
        final move = _moves[index - 1];
        final moveText = (index - 1) < _formattedMoves.length
            ? _formattedMoves[index - 1]
            : "Move $index";
        return _buildMoveItem(index - 1, moveText, move['player']?.toString().toUpperCase() ?? "");
      },
    );
  }

  Widget _buildMoveItem(int index, String text, String player) {
    final isSelected = _currentMoveIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentMoveIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.12) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                index == -1 ? "•" : "${(index / 2).floor() + 1}.",
                style: GoogleFonts.robotoMono(color: Colors.white38, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.robotoMono(
                  color: isSelected ? const Color(0xFFD4AF37) : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            if (player.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  player,
                  style: GoogleFonts.montserrat(
                    color: Colors.white60,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E0A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
        boxShadow: isMobile ? [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, -5))] : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _controlButton(Icons.first_page, () => setState(() => _currentMoveIndex = -1), isMobile),
          SizedBox(width: isMobile ? 12 : 24),
          _controlButton(Icons.chevron_left, () {
            if (_currentMoveIndex > -1) setState(() => _currentMoveIndex--);
          }, isMobile),
          SizedBox(width: isMobile ? 16 : 40),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 6 : 10),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "MOVE ${_currentMoveIndex + 1}/${_moves.length}",
              style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 14),
            ),
          ),
          SizedBox(width: isMobile ? 16 : 40),
          _controlButton(Icons.chevron_right, () {
            if (_currentMoveIndex < _moves.length - 1) setState(() => _currentMoveIndex++);
          }, isMobile),
          SizedBox(width: isMobile ? 12 : 24),
          _controlButton(Icons.last_page, () => setState(() => _currentMoveIndex = _moves.length - 1), isMobile),
        ],
      ),
    );
  }

  Widget _controlButton(IconData icon, VoidCallback? onTap, bool isMobile) {
    return IconButton(
      icon: Icon(icon, color: const Color(0xFFD4AF37), size: isMobile ? 24 : 32),
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}
