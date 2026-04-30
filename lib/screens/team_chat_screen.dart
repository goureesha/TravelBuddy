import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';

class TeamChatScreen extends StatefulWidget {
  final String teamId;
  final String teamName;
  const TeamChatScreen({super.key, required this.teamId, required this.teamName});

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    ChatService.sendMessage(widget.teamId, text);
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.teamName,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Team Chat',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── MESSAGES ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: ChatService.getMessages(widget.teamId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 64, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4)),
                        ),
                        Text(
                          'Say hello to your team!',
                          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.24), fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == currentUid;
                    final showAvatar = !isMe &&
                        (index == docs.length - 1 ||
                            (docs[index + 1].data() as Map<String, dynamic>)['senderId'] !=
                                data['senderId']);

                    return _messageBubble(
                      data: data,
                      isMe: isMe,
                      showAvatar: showAvatar,
                    );
                  },
                );
              },
            ),
          ),

          // ── INPUT BAR ──
          Container(
            padding: EdgeInsets.fromLTRB(
              12, 8, 8, MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: GoogleFonts.inter(color: Colors.white),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.24)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A73E8), Color(0xFF00BFA5)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble({
    required Map<String, dynamic> data,
    required bool isMe,
    required bool showAvatar,
  }) {
    final senderName = data['senderName'] as String? ?? 'Unknown';
    final senderPhoto = data['senderPhoto'] as String? ?? '';
    final text = data['text'] as String? ?? '';
    final timestamp = data['timestamp'] as Timestamp?;
    final time = timestamp != null
        ? DateFormat('h:mm a').format(timestamp.toDate())
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (other users)
          if (!isMe)
            SizedBox(
              width: 32,
              child: showAvatar
                  ? CircleAvatar(
                      radius: 14,
                      backgroundImage: senderPhoto.isNotEmpty
                          ? NetworkImage(senderPhoto)
                          : null,
                      backgroundColor: Colors.white.withOpacity(0.12),
                      child: senderPhoto.isEmpty
                          ? Text(
                              senderName[0].toUpperCase(),
                              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
                            )
                          : null,
                    )
                  : null,
            ),

          const SizedBox(width: 4),

          // Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFF1A73E8).withOpacity(0.25)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        senderName.split(' ').first,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00BFA5),
                        ),
                      ),
                    ),
                  Text(
                    text,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
