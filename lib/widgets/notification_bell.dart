import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../screens/team_chat_screen.dart';

/// Reusable notification bell + chat icon for any AppBar or header.
/// Shows red dot when there are unread team messages.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('teams')
          .where('members', arrayContains: uid)
          .snapshots(),
      builder: (context, teamSnap) {
        final teams = teamSnap.data?.docs ?? [];
        if (teams.isEmpty) {
          return _buildIcon(context, hasUnread: false, teamId: null, teamName: null);
        }

        // Check unread across all teams
        return _MultiTeamUnreadChecker(
          teamDocs: teams,
          builder: (hasUnread, latestTeamId, latestTeamName) {
            return _buildIcon(
              context,
              hasUnread: hasUnread,
              teamId: latestTeamId,
              teamName: latestTeamName,
            );
          },
        );
      },
    );
  }

  Widget _buildIcon(BuildContext context, {
    required bool hasUnread,
    required String? teamId,
    required String? teamName,
  }) {
    return GestureDetector(
      onTap: () {
        if (teamId != null && teamName != null) {
          ChatService.markAsRead(teamId);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => TeamChatScreen(
              teamId: teamId,
              teamName: teamName,
            ),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Join a team to start chatting'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.notifications_rounded,
                color: Colors.white.withOpacity(0.7), size: 22),
            if (hasUnread)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF161B22), width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Checks unread status across multiple teams
class _MultiTeamUnreadChecker extends StatefulWidget {
  final List<QueryDocumentSnapshot> teamDocs;
  final Widget Function(bool hasUnread, String? teamId, String? teamName) builder;

  const _MultiTeamUnreadChecker({
    required this.teamDocs,
    required this.builder,
  });

  @override
  State<_MultiTeamUnreadChecker> createState() => _MultiTeamUnreadCheckerState();
}

class _MultiTeamUnreadCheckerState extends State<_MultiTeamUnreadChecker> {
  bool _hasUnread = false;
  String? _latestTeamId;
  String? _latestTeamName;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _listenAll();
  }

  @override
  void didUpdateWidget(covariant _MultiTeamUnreadChecker old) {
    super.didUpdateWidget(old);
    if (old.teamDocs.length != widget.teamDocs.length) {
      _cancelAll();
      _listenAll();
    }
  }

  void _listenAll() {
    // Find the team with the most recent message for navigation
    Timestamp? latest;
    for (final doc in widget.teamDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final lastMsg = data['lastMessageAt'] as Timestamp?;
      if (lastMsg != null && (latest == null || lastMsg.compareTo(latest) > 0)) {
        latest = lastMsg;
        _latestTeamId = doc.id;
        _latestTeamName = data['name'] as String? ?? 'Team';
      }
    }

    // Default to first team if no messages yet
    if (_latestTeamId == null && widget.teamDocs.isNotEmpty) {
      final first = widget.teamDocs.first;
      _latestTeamId = first.id;
      _latestTeamName = (first.data() as Map<String, dynamic>)['name'] as String? ?? 'Team';
    }

    // Listen for unread on each team
    for (final doc in widget.teamDocs) {
      final sub = ChatService.hasUnread(doc.id).listen((unread) {
        if (unread && mounted) {
          setState(() {
            _hasUnread = true;
            // Update latest team to the one with unread
            _latestTeamId = doc.id;
            _latestTeamName = (doc.data() as Map<String, dynamic>)['name'] as String? ?? 'Team';
          });
        }
      });
      _subs.add(sub);
    }
  }

  void _cancelAll() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  @override
  void dispose() {
    _cancelAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_hasUnread, _latestTeamId, _latestTeamName);
  }
}
