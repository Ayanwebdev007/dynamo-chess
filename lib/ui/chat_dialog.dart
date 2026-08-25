import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/online_service.dart';

class ChatDialog extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final String currentUserName;
  final OnlineService onlineService;

  const ChatDialog({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.currentUserName,
    required this.onlineService,
  });

  @override
  State<ChatDialog> createState() => _ChatDialogState();
}

class _ChatDialogState extends State<ChatDialog> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  late StreamSubscription _chatSubscription;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _chatSubscription = widget.onlineService.getChatStream(widget.roomId).listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        if (mounted) {
          setState(() {
            _messages.add(data);
          });
          // Auto-scroll to bottom
          Timer(const Duration(milliseconds: 100), () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _chatSubscription.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onlineService.sendChatMessage(
        widget.roomId,
        widget.currentUserId,
        widget.currentUserName,
        text,
      );
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "GAME CHAT",
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFFD4AF37),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.white10),
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        "No messages yet. Say hi!",
                        style: GoogleFonts.montserrat(color: Colors.white24, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg['senderId'] == widget.currentUserId;
                        return _buildMessageBubble(msg, isMe);
                      },
                    ),
            ),
            // Quick preset message chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickChip("Good game! 🤝"),
                  const SizedBox(width: 6),
                  _buildQuickChip("Well played! 👏"),
                  const SizedBox(width: 6),
                  _buildQuickChip("Rematch? 🔄"),
                  const SizedBox(width: 6),
                  _buildQuickChip("Great match! 🏆"),
                  const SizedBox(width: 6),
                  _buildQuickChip("Thanks! 👍"),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: GoogleFonts.montserrat(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      hintStyle: GoogleFonts.montserrat(color: Colors.white24, fontSize: 14),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFFD4AF37),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.black, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String text) {
    return InkWell(
      onTap: () {
        widget.onlineService.sendChatMessage(
          widget.roomId,
          widget.currentUserId,
          widget.currentUserName,
          text,
        );
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
        ),
        child: Text(
          text,
          style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                msg['senderName'] ?? "Opponent",
                style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontSize: 10),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFFD4AF37).withOpacity(0.2) : Colors.white10,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(15),
                topRight: const Radius.circular(15),
                bottomLeft: Radius.circular(isMe ? 15 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 15),
              ),
              border: Border.all(
                color: isMe ? const Color(0xFFD4AF37).withOpacity(0.3) : Colors.white10,
              ),
            ),
            child: Text(
              msg['text'] ?? "",
              style: GoogleFonts.montserrat(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
