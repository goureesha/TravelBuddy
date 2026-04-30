import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/team_service.dart';
import 'team_detail_screen.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  // ════════════════════════════════════
  // CREATE TEAM
  // ════════════════════════════════════
  void _showCreateTeamDialog() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C2128),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Team',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Give your travel team a name',
              style: GoogleFonts.inter(color: Colors.white.withOpacity(0.54)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Road Trip Squad',
                hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.group_rounded, color: Colors.white.withOpacity(0.3)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(ctx);
                  final teamId = await TeamService.createTeam(name);
                  if (teamId != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Team "$name" created!'),
                        backgroundColor: const Color(0xFF00BFA5),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Create Team',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════
  // JOIN TEAM
  // ════════════════════════════════════
  void _showJoinTeamDialog() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C2128),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Join Team',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-character invite code',
              style: GoogleFonts.inter(color: Colors.white.withOpacity(0.54)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 8,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                hintText: '------',
                hintStyle: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.2),
                  fontSize: 24,
                  letterSpacing: 8,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  final code = controller.text.trim();
                  if (code.length != 6) return;
                  Navigator.pop(ctx);
                  final teamId = await TeamService.joinTeam(code);
                  if (!mounted) return;
                  if (teamId != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Joined team successfully!'),
                        backgroundColor: Color(0xFF00BFA5),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid invite code'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Join Team',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════
  // BUILD
  // ════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Your Teams',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  _headerButton(Icons.add_rounded, 'Create', _showCreateTeamDialog),
                  const SizedBox(width: 8),
                  _headerButton(Icons.login_rounded, 'Join', _showJoinTeamDialog),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Team list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: TeamService.getMyTeams(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return _emptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return _teamCard(docs[index].id, data);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF1A73E8)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamCard(String teamId, Map<String, dynamic> data) {
    final members = List.from(data['members'] ?? []);
    final memberDetails = Map<String, dynamic>.from(data['memberDetails'] ?? {});
    final inviteCode = data['inviteCode'] ?? '';
    final isAdmin = data['createdBy'] == FirebaseAuth.instance.currentUser?.uid;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamDetailScreen(teamId: teamId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.06),
              Colors.white.withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A73E8), Color(0xFF00BFA5)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      (data['name'] ?? 'T')[0].toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'] ?? 'Unnamed Team',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${members.length} member${members.length == 1 ? '' : 's'}${isAdmin ? ' · Admin' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                // Invite code chip
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Invite code copied: $inviteCode'),
                        backgroundColor: const Color(0xFF1A73E8),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF1A73E8)),
                        const SizedBox(width: 4),
                        Text(
                          inviteCode,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A73E8),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Member avatars
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: members.take(8).map<Widget>((uid) {
                  final detail = memberDetails[uid] as Map<String, dynamic>?;
                  final photo = detail?['photoUrl'] as String?;
                  final name = detail?['name'] as String? ?? '?';
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundImage: (photo != null && photo.isNotEmpty)
                          ? NetworkImage(photo)
                          : null,
                      backgroundColor: Colors.white.withOpacity(0.12),
                      child: (photo == null || photo.isEmpty)
                          ? Text(
                              name[0].toUpperCase(),
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline_rounded, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            'No teams yet',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.54),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a team or join one\nwith an invite code',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white.withOpacity(0.3)),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _showCreateTeamDialog,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Create'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _showJoinTeamDialog,
                icon: const Icon(Icons.login_rounded, size: 20),
                label: const Text('Join'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00BFA5),
                  side: const BorderSide(color: Color(0xFF00BFA5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
