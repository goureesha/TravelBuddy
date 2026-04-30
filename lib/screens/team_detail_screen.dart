import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../services/team_service.dart';
import 'team_chat_screen.dart';

class TeamDetailScreen extends StatelessWidget {
  final String teamId;
  const TeamDetailScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: TeamService.getTeam(teamId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Team')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final teamName = data['name'] ?? 'Team';
        final inviteCode = data['inviteCode'] ?? '';
        final members = List<String>.from(data['members'] ?? []);
        final memberDetails = Map<String, dynamic>.from(data['memberDetails'] ?? {});
        final isAdmin = data['createdBy'] == currentUid;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // App bar with team name
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                backgroundColor: const Color(0xFF161B22),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    teamName,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A73E8), Color(0xFF00BFA5)],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.explore_rounded,
                        size: 64,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
                actions: [
                  if (isAdmin)
                    PopupMenuButton(
                      icon: const Icon(Icons.more_vert),
                      color: const Color(0xFF1C2128),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
                              SizedBox(width: 8),
                              Text('Delete Team', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) async {
                        if (value == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1C2128),
                              title: const Text('Delete Team?', style: TextStyle(color: Colors.white)),
                              content: const Text(
                                'This will permanently delete the team for all members.',
                                style: TextStyle(color: Colors.white60),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await TeamService.deleteTeam(teamId);
                            if (context.mounted) Navigator.pop(context);
                          }
                        }
                      },
                    ),
                ],
              ),

              // Invite code section
              SliverToBoxAdapter(
                child: _inviteSection(context, inviteCode, teamName),
              ),

              // Members header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Text(
                    'Members (${members.length})',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),

              // Members list
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final uid = members[index];
                    final detail = memberDetails[uid] as Map<String, dynamic>?;
                    return _memberTile(
                      context,
                      uid: uid,
                      name: detail?['name'] ?? 'Unknown',
                      email: detail?['email'] ?? '',
                      photoUrl: detail?['photoUrl'] ?? '',
                      role: detail?['role'] ?? 'member',
                      isCurrentUser: uid == currentUid,
                    );
                  },
                  childCount: members.length,
                ),
              ),

              // Leave team button
              if (!isAdmin)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await TeamService.leaveTeam(teamId);
                        if (context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.exit_to_app_rounded),
                      label: const Text('Leave Team'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeamChatScreen(
                    teamId: teamId,
                    teamName: teamName,
                  ),
                ),
              );
            },
            backgroundColor: const Color(0xFF1A73E8),
            child: const Icon(Icons.chat_rounded, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _inviteSection(BuildContext context, String code, String teamName) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A73E8).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A73E8).withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(
            'Invite Code',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            code,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A73E8),
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied!'),
                        backgroundColor: Color(0xFF1A73E8),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    SharePlus.instance.share(
                      ShareParams(
                        text: 'Join my travel team "$teamName" on Travel Buddy!\nCode: $code',
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _memberTile(
    BuildContext context, {
    required String uid,
    required String name,
    required String email,
    required String photoUrl,
    required String role,
    required bool isCurrentUser,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? Colors.white.withOpacity(0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            backgroundColor: Colors.white12,
            child: photoUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white60),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (isCurrentUser)
                      Text(
                        ' (You)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white40,
                        ),
                      ),
                  ],
                ),
                Text(
                  email,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white40,
                  ),
                ),
              ],
            ),
          ),
          if (role == 'admin')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6D00).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Admin',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFF6D00),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
