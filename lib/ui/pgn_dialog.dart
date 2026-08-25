import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/models.dart';
import '../core/pgn_service.dart';

class PgnDialog extends StatefulWidget {
  final String whitePlayer;
  final String blackPlayer;
  final String result;
  final List<MoveRecord> history;
  final String event;
  final String? timeControl;
  final String? termination;
  final String? initialFen;

  const PgnDialog({
    super.key,
    required this.whitePlayer,
    required this.blackPlayer,
    required this.result,
    required this.history,
    this.event = "Dynamo Chess Match",
    this.timeControl,
    this.termination,
    this.initialFen,
  });

  @override
  State<PgnDialog> createState() => _PgnDialogState();
}

class _PgnDialogState extends State<PgnDialog> {
  late String _pgnText;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _pgnText = PgnService.generatePgn(
      whitePlayer: widget.whitePlayer,
      blackPlayer: widget.blackPlayer,
      result: widget.result,
      history: widget.history,
      event: widget.event,
      timeControl: widget.timeControl,
      termination: widget.termination,
      initialFen: widget.initialFen,
    );
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _pgnText));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
            const SizedBox(width: 8),
            Text("PGN copied to clipboard!", style: GoogleFonts.montserrat()),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        duration: const Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _downloadPgn() async {
    final sanitizedWhite = widget.whitePlayer.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final sanitizedBlack = widget.blackPlayer.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = "${sanitizedWhite}_vs_${sanitizedBlack}_dynamo.pgn";

    final success = await PgnService.downloadPgnFile(_pgnText, fileName);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Downloading $fileName...", style: GoogleFonts.montserrat()),
          backgroundColor: const Color(0xFFD4AF37),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      // Fallback: Copy to clipboard if direct file download is restricted
      _copyToClipboard();
    }
  }

  void _shareGame() {
    final shareText = "🎮 Dynamo Chess Match: ${widget.whitePlayer} vs ${widget.blackPlayer}\n"
        "Result: ${widget.result}\n"
        "Moves: ${widget.history.length}\n\n"
        "PGN:\n$_pgnText";

    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.share, color: Color(0xFFD4AF37), size: 18),
            const SizedBox(width: 8),
            Text("Game summary & PGN copied for sharing!", style: GoogleFonts.montserrat()),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141814),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
      ),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.file_download_outlined, color: Color(0xFFD4AF37), size: 24),
                    const SizedBox(width: 10),
                    Text(
                      "PGN & GAME EXPORT",
                      style: GoogleFonts.cinzel(
                        color: const Color(0xFFD4AF37),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Match Info Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${widget.whitePlayer} (White) vs ${widget.blackPlayer} (Black)",
                          style: GoogleFonts.montserrat(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Total Moves: ${widget.history.length} • Result: ${widget.result}",
                          style: GoogleFonts.montserrat(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // PGN Text Box
            Container(
              height: 180,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _pgnText,
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFFD4AF37),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _copyToClipboard,
                    icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
                    label: Text(
                      _copied ? "COPIED" : "COPY PGN",
                      style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _downloadPgn,
                    icon: const Icon(Icons.download, size: 16),
                    label: Text(
                      "SAVE PGN",
                      style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD4AF37),
                      side: const BorderSide(color: Color(0xFFD4AF37)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _shareGame,
                  icon: const Icon(Icons.share, color: Color(0xFFD4AF37), size: 20),
                  tooltip: "Share Game",
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.white12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
