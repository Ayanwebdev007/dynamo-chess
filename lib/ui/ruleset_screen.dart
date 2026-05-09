import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../core/models.dart';
import '../core/board.dart';
import '../core/rules_engine.dart';
import 'board_painter.dart';
import 'platform_asset_image.dart';

class RulesetScreen extends StatefulWidget {
  const RulesetScreen({super.key});

  @override
  State<RulesetScreen> createState() => _RulesetScreenState();
}

class _RulesetScreenState extends State<RulesetScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  late AnimationController _bgPulseController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<RuleProtocol> _protocols = [
    RuleProtocol(
      protocolId: "DYNAMO-001",
      title: "100-SQUARE THEATER",
      description: "Operation Dynamo expands the standard battlefield to a 10x10 strategic grid. Files I and J are added, creating a vast arena for long-range tactical maneuvers and deep flanking operations.",
      setup: (board) {
        // No pieces, just show grid
      },
      highlights: [
        // Highlight Files I and J
        ...List.generate(10, (y) => Position(8, y)),
        ...List.generate(10, (y) => Position(9, y)),
      ],
    ),
    RuleProtocol(
      protocolId: "DYNAMO-002",
      title: "HEAVY ARSENAL",
      description: "Each commander deploys 20 high-specialty units. The arsenal includes 10 Pawns and 10 Pieces, introducing two additional Knights and two devastating hybrid Missiles for maximum tactical density.",
      setup: (board) => board.initializeBoard(),
      highlights: [
        Position(3, 9), Position(6, 9), // Missiles White
        Position(1, 9), Position(8, 9), // Extra Knights White (relative to 8x8)
      ],
    ),
    RuleProtocol(
      protocolId: "DYNAMO-003",
      title: "THE MISSILE UNIT",
      description: "The Missile (Dynamo) is a dual-capability strike unit. It combines the diagonal range of a Bishop with the L-leap mobility of a Knight. It is the most versatile offensive asset in the Dynamo armory.",
      setup: (board) {
        board.setPiece(Position(4, 4), const DynamoPiece(type: PieceType.missile, color: PlayerColor.white));
      },
      highlights: [
        Position(3, 3), Position(2, 2), Position(1, 1), Position(0, 0),
        Position(5, 5), Position(6, 6), Position(7, 7), Position(8, 8), Position(9, 9),
        Position(3, 5), Position(2, 6), Position(1, 7), Position(0, 8),
        Position(5, 3), Position(6, 2), Position(7, 1), Position(8, 0),
        Position(2, 3), Position(2, 5), Position(3, 2), Position(3, 6),
        Position(5, 2), Position(5, 6), Position(6, 3), Position(6, 5),
      ],
      selectedPos: Position(4, 4),
    ),
    RuleProtocol(
      protocolId: "DYNAMO-004",
      title: "TRIPLE-SQUARE SURGE",
      description: "Infantry units (Pawns) can execute an explosive deployment jump from their starting rank. They have the capability to advance 1, 2, or even 3 squares forward in a single maneuver.",
      setup: (board) {
        board.setPiece(Position(4, 8), const DynamoPiece(type: PieceType.pawn, color: PlayerColor.white));
      },
      highlights: [Position(4, 7), Position(4, 6), Position(4, 5)],
      selectedPos: Position(4, 8),
    ),
    RuleProtocol(
      protocolId: "DYNAMO-005",
      title: "INTERCEPT EN-PASSANT",
      description: "If an enemy pawn uses an accelerated jump (2 or 3 squares) to bypass your unit's threat zone, you may execute an 'En-Passant' interception on the immediately following move.",
      setup: (board) {
        board.setPiece(Position(3, 3), const DynamoPiece(type: PieceType.pawn, color: PlayerColor.white));
        board.setPiece(Position(4, 4), const DynamoPiece(type: PieceType.pawn, color: PlayerColor.black));
      },
      highlights: [Position(4, 2)],
      lastMoveStart: Position(4, 1),
      lastMoveEnd: Position(4, 4),
      selectedPos: Position(3, 3),
    ),
    RuleProtocol(
      protocolId: "DYNAMO-006",
      title: "DEEP CASTLING",
      description: "The King executes a 3-square maneuver toward the Rook during castling. This provides deeper security in the expanded 10x10 theater, placing the Commander behind a stronger defensive line.",
      setup: (board) {
        board.setPiece(Position(5, 9), const DynamoPiece(type: PieceType.king, color: PlayerColor.white));
        board.setPiece(Position(9, 9), const DynamoPiece(type: PieceType.rook, color: PlayerColor.white));
      },
      highlights: [Position(8, 9)],
      selectedPos: Position(5, 9),
    ),
    RuleProtocol(
      protocolId: "DYNAMO-007",
      title: "ELITE PROMOTION",
      description: "Pawns reaching the 10th rank are eligible for field promotion. They may be upgraded to any piece, including the formidable Missile, ensuring late-game dominance.",
      setup: (board) {
        board.setPiece(Position(4, 1), const DynamoPiece(type: PieceType.pawn, color: PlayerColor.white));
      },
      highlights: [Position(4, 0)],
      selectedPos: Position(4, 1),
    ),
    RuleProtocol(
      protocolId: "DYNAMO-008",
      title: "ASSET VALUATIONS",
      description: "Strategic Protocol Values: Pawn (1), Knight (3), Bishop (3), Rook (5), Missile (7), Queen (9). Use these metrics to assess mission risk and trade-off profitability.",
      setup: (board) {
        board.setPiece(Position(0, 5), const DynamoPiece(type: PieceType.pawn, color: PlayerColor.white));
        board.setPiece(Position(2, 5), const DynamoPiece(type: PieceType.knight, color: PlayerColor.white));
        board.setPiece(Position(4, 5), const DynamoPiece(type: PieceType.missile, color: PlayerColor.white));
        board.setPiece(Position(6, 5), const DynamoPiece(type: PieceType.rook, color: PlayerColor.white));
        board.setPiece(Position(8, 5), const DynamoPiece(type: PieceType.queen, color: PlayerColor.white));
      },
    ),
    RuleProtocol(
      protocolId: "DYNAMO-009",
      title: "THE CORNER STRANGLE",
      description: "The Missile is the only single unit in the Dynamo arsenal capable of delivering a solo checkmate to a cornered King. It is the ultimate endgame closer.",
      setup: (board) {
        board.setPiece(Position(9, 0), const DynamoPiece(type: PieceType.king, color: PlayerColor.black));
        board.setPiece(Position(7, 1), const DynamoPiece(type: PieceType.missile, color: PlayerColor.white));
      },
      highlights: [Position(9, 0)],
      selectedPos: Position(7, 1),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bgPulseController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _bgPulseController.dispose();
    _fadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    HapticFeedback.lightImpact();
    setState(() => _currentPage = index);
    _fadeController.reset();
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B08),
      body: Stack(
        children: [
          _buildAtmosphericBackground(),
          _buildTacticalScanlines(),
          SafeArea(
            child: Column(
              children: [
                _buildTopNavigation(),
                _buildMissionProgress(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _protocols.length,
                    itemBuilder: (context, index) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildProtocolSlide(_protocols[index]),
                      );
                    },
                  ),
                ),
                _buildPagingControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtmosphericBackground() {
    return AnimatedBuilder(
      animation: _bgPulseController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.4),
              radius: 1.8 + (0.4 * _bgPulseController.value),
              colors: [
                Color.lerp(const Color(0xFF0E240F), const Color(0xFF163217), _bgPulseController.value)!,
                const Color(0xFF080B08),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTacticalScanlines() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.015,
          child: Column(
            children: List.generate(
              120,
              (i) => Container(height: 1, color: Colors.white, margin: const EdgeInsets.only(bottom: 3)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopNavigation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            children: [
              Text(
                "FIELD MANUAL",
                style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 6),
              ),
              Text(
                "DYNAMO OPERATIONAL PROCEDURES",
                style: GoogleFonts.montserrat(color: Colors.white12, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ],
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildMissionProgress() {
    return Container(
      height: 2,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(1)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: (_currentPage + 1) / _protocols.length,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37),
            boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.5), blurRadius: 10)],
          ),
        ),
      ),
    );
  }

  Widget _buildProtocolSlide(RuleProtocol protocol) {
    final board = DynamoBoard();
    protocol.setup(board);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth > 950;
        
        if (isDesktop) {
          return Row(
            children: [
              Expanded(flex: 4, child: Padding(padding: const EdgeInsets.all(60.0), child: _buildProtocolText(protocol, true))),
              Expanded(flex: 6, child: Center(child: _buildTacticalBoard(protocol, board, 580))),
            ],
          );
        } else {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                _buildTacticalBoard(protocol, board, constraints.maxWidth * 0.88),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildProtocolText(protocol, false),
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildProtocolText(RuleProtocol protocol, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(protocol.protocolId, style: GoogleFonts.robotoMono(color: const Color(0xFFD4AF37), fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          Text(
            protocol.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(color: Colors.white, fontSize: isDesktop ? 28 : 18, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          Container(width: 50, height: 1.5, color: const Color(0xFFD4AF37).withOpacity(0.5)),
          const SizedBox(height: 20),
          Text(
            protocol.description,
            textAlign: isDesktop ? TextAlign.left : TextAlign.center,
            style: GoogleFonts.montserrat(color: Colors.white60, fontSize: isDesktop ? 15 : 13, height: 1.7, fontWeight: FontWeight.w400, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalBoard(RuleProtocol protocol, DynamoBoard board, double size) {
    final double adjustedSize = (size ~/ 10) * 10.0;
    final double squareSize = adjustedSize / 10;
    
    return Container(
      width: adjustedSize,
      height: adjustedSize,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 40)],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int y = 0; y < 10; y++)
            for (int x = 0; x < 10; x++)
              Positioned(
                left: x * squareSize,
                top: y * squareSize,
                width: squareSize,
                height: squareSize,
                child: Container(
                  decoration: BoxDecoration(
                    color: (x + y) % 2 == 0 ? const Color(0xFFF0F1D8) : const Color(0xFF88A668),
                    border: Border.all(color: Colors.black.withOpacity(0.02), width: 0.5),
                  ),
                ),
              ),

          CustomPaint(
            size: Size(adjustedSize, adjustedSize),
            painter: BoardHighlightPainter(
              board: board,
              selectedPosition: protocol.selectedPos,
              lastMoveStart: protocol.lastMoveStart,
              lastMoveEnd: protocol.lastMoveEnd,
              showLastMove: true,
            ),
          ),

          _buildPieceManifest(board, squareSize),

          CustomPaint(
            size: Size(adjustedSize, adjustedSize),
            painter: BoardForegroundPainter(
              board: board,
              validMoves: protocol.highlights ?? [],
            ),
          ),

          _buildHUDBrackets(adjustedSize),
        ],
      ),
    );
  }

  Widget _buildPieceManifest(DynamoBoard board, double squareSize) {
    List<Widget> manifest = [];
    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 10; x++) {
        final piece = board.getPiece(Position(x, y));
        if (piece != null) {
          manifest.add(
            Positioned(
              left: x * squareSize,
              top: y * squareSize,
              width: squareSize,
              height: squareSize,
              child: Container(
                alignment: Alignment.center,
                child: PlatformAssetImage(
                  assetPath: "assets/pieces/${piece.type.name}_${piece.color == PlayerColor.white ? 'w' : 'b'}.png", 
                  viewType: piece.type.name,
                  width: squareSize * 0.9,
                  height: squareSize * 0.9,
                ),
              ),
            ),
          );
        }
      }
    }
    return Stack(children: manifest);
  }

  Widget _buildHUDBrackets(double size) {
    return CustomPaint(
      size: Size(size, size),
      painter: _TacticalBracketsPainter(color: const Color(0xFFD4AF37).withOpacity(0.5)),
    );
  }

  Widget _buildPagingControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildNavArrow(Icons.arrow_back_ios_new, _currentPage > 0 ? () => _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOut) : null),
          const SizedBox(width: 40),
          Text(
            "${_currentPage + 1} / ${_protocols.length}",
            style: GoogleFonts.robotoMono(color: const Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 4),
          ),
          const SizedBox(width: 40),
          _buildNavArrow(Icons.arrow_forward_ios, _currentPage < _protocols.length - 1 ? () => _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOut) : null),
        ],
      ),
    );
  }

  Widget _buildNavArrow(IconData icon, VoidCallback? onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: onTap == null ? Colors.white10 : const Color(0xFFD4AF37), size: 18),
    );
  }
}

class RuleProtocol {
  final String protocolId;
  final String title;
  final String description;
  final Function(DynamoBoard) setup;
  final List<Position>? highlights;
  final Position? selectedPos;
  final Position? lastMoveStart;
  final Position? lastMoveEnd;

  RuleProtocol({
    required this.protocolId,
    required this.title,
    required this.description,
    required this.setup,
    this.highlights,
    this.selectedPos,
    this.lastMoveStart,
    this.lastMoveEnd,
  });
}

class _TacticalBracketsPainter extends CustomPainter {
  final Color color;
  _TacticalBracketsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
    const l = 15.0;
    canvas.drawLine(Offset.zero, const Offset(l, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, l), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - l, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, l), paint);
    canvas.drawLine(Offset(0, size.height), Offset(l, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - l), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - l, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - l), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
