import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/models.dart';
import '../core/fen_converter.dart';
import 'platform_asset_image.dart';

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
  int _currentMoveIndex = -1; // -1 means starting position
  late String _startingFen;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Correct 10x10 starting FEN without spaces in the board part
    _startingFen = "rnbqmmqbnr/pppppppppp/10/10/10/10/10/10/PPPPPPPPPP/RNBQMMQBNR w - -";
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
                final x = index % 10;
                final y = (index / 10).floor();
                final piece = board[y][x];
                final isDark = (x + y) % 2 != 0;
                
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
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("MOVE LOG", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.bold)),
                if (_moves.isEmpty)
                  const Icon(Icons.history_toggle_off, color: Colors.white24, size: 16),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: isMobile ? 300 : 600),
            child: _moves.isEmpty 
              ? Center(
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
                          style: GoogleFonts.montserrat(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold),
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
                )
              : ListView.builder(
                  shrinkWrap: true,
                  controller: _scrollController,
                  itemCount: _moves.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildMoveItem(-1, "STARTING POSITION", "");
                    }
                    final move = _moves[index - 1];
                    final from = Map<String, dynamic>.from(move['from']);
                    final to = Map<String, dynamic>.from(move['to']);
                    final fromX = (from['x'] as num).toInt();
                    final fromY = (from['y'] as num).toInt();
                    final toX = (to['x'] as num).toInt();
                    final toY = (to['y'] as num).toInt();
                    final String prevFen = (index - 1) == 0 ? _startingFen : _moves[index - 2]['fen'];
                    final prevBoard = FenConverter.fromFen(prevFen);
                    final piece = prevBoard[fromY][fromX];
                    
                    String p = '';
                    if (piece != null) {
                      if (piece.type == PieceType.king) p = 'K';
                      else if (piece.type == PieceType.queen) p = 'Q';
                      else if (piece.type == PieceType.missile) p = 'M';
                      else if (piece.type == PieceType.rook) p = 'R';
                      else if (piece.type == PieceType.bishop) p = 'B';
                      else if (piece.type == PieceType.knight) p = 'N';
                    }
                    
                    bool isCapture = false;
                    if (piece != null && prevBoard[toY][toX] != null) {
                      isCapture = true;
                    } else if (piece?.type == PieceType.pawn && fromX != toX) {
                      isCapture = true;
                    }
                    
                    String moveText;
                    final endFile = String.fromCharCode(97 + toX);
                    final endRank = 10 - toY;

                    if (piece?.type == PieceType.king && (toX - fromX).abs() >= 2) {
                      moveText = toX > fromX ? "0-0" : "0-0-0";
                    } else if (isCapture) {
                       if (piece?.type == PieceType.pawn) {
                          final startFile = String.fromCharCode(97 + fromX);
                          moveText = "${startFile}x$endFile$endRank";
                       } else {
                          moveText = "${p}x$endFile$endRank";
                       }
                    } else {
                       moveText = "$p$endFile$endRank";
                    }
                    return _buildMoveItem(index - 1, moveText, move['player']?.toString().toUpperCase() ?? "");
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoveItem(int index, String text, String player) {
    final isSelected = _currentMoveIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentMoveIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.1) : Colors.transparent,
          border: Border(left: BorderSide(color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent, width: 3)),
        ),
        child: Row(
          children: [
            Text(index == -1 ? "0." : "${(index / 2).floor() + 1}.", style: const TextStyle(color: Colors.white24, fontSize: 12)),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
            if (player.isNotEmpty)
              Text(player, style: TextStyle(color: player == "WHITE" ? Colors.white38 : Colors.black38, fontSize: 9, fontWeight: FontWeight.bold)),
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
