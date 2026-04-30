import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/team_service.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  String? _selectedTeamId;
  String? _selectedTeamName;
  final _firestore = FirebaseFirestore.instance;

  void _pickTeam() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StreamBuilder<QuerySnapshot>(
        stream: TeamService.getMyTeams(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
          final teams = snapshot.data!.docs;
          if (teams.isEmpty) return SizedBox(height: 200, child: Center(child: Text('No teams', style: GoogleFonts.inter(color: Colors.white54))));
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Select Team', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...teams.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFF1A73E8), child: Icon(Icons.group, color: Colors.white, size: 20)),
                    title: Text(data['name'] ?? '', style: GoogleFonts.inter(color: Colors.white)),
                    onTap: () { setState(() { _selectedTeamId = doc.id; _selectedTeamName = data['name']; }); Navigator.pop(ctx); },
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addItem() async {
    if (_selectedTeamId == null) return;
    final ctrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Item', style: GoogleFonts.inter(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. Pack sunscreen',
            hintStyle: GoogleFonts.inter(color: Colors.white24),
            filled: true, fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await _firestore.collection('teams').doc(_selectedTeamId!).collection('checklist').add({
                'text': ctrl.text.trim(),
                'checked': false,
                'addedBy': FirebaseAuth.instance.currentUser?.displayName ?? 'Unknown',
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Add', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Checklist', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: _pickTeam,
            icon: const Icon(Icons.group_rounded, size: 18, color: Color(0xFF00BFA5)),
            label: Text(_selectedTeamName ?? 'Pick Team', style: GoogleFonts.inter(color: const Color(0xFF00BFA5), fontSize: 13)),
          ),
        ],
      ),
      body: _selectedTeamId == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.checklist_rounded, size: 64, color: Colors.white.withOpacity(0.12)),
                  const SizedBox(height: 16),
                  Text('Select a team', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _pickTeam, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Pick Team', style: GoogleFonts.inter(color: Colors.white))),
                ],
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('teams').doc(_selectedTeamId!).collection('checklist').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final items = snapshot.data?.docs ?? [];

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.playlist_add_rounded, size: 64, color: Colors.white.withOpacity(0.12)),
                        const SizedBox(height: 12),
                        Text('No items yet', style: GoogleFonts.inter(color: Colors.white38)),
                        const SizedBox(height: 4),
                        Text('Add packing items, to-dos, etc.', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
                      ],
                    ),
                  );
                }

                // Sort: unchecked first
                items.sort((a, b) {
                  final ac = (a.data() as Map<String, dynamic>)['checked'] == true ? 1 : 0;
                  final bc = (b.data() as Map<String, dynamic>)['checked'] == true ? 1 : 0;
                  return ac.compareTo(bc);
                });

                final total = items.length;
                final done = items.where((d) => (d.data() as Map<String, dynamic>)['checked'] == true).length;

                return Column(
                  children: [
                    // Progress bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('$done / $total completed', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                              const Spacer(),
                              Text('${total > 0 ? (done / total * 100).toInt() : 0}%', style: GoogleFonts.inter(color: const Color(0xFF00BFA5), fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: total > 0 ? done / total : 0,
                              minHeight: 6,
                              backgroundColor: Colors.white.withOpacity(0.08),
                              valueColor: const AlwaysStoppedAnimation(Color(0xFF00BFA5)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Items
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final doc = items[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final isChecked = data['checked'] == true;

                          return Dismissible(
                            key: Key(doc.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) => doc.reference.delete(),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161B22),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isChecked ? Colors.green.withOpacity(0.15) : Colors.white.withOpacity(0.06)),
                              ),
                              child: ListTile(
                                leading: GestureDetector(
                                  onTap: () => doc.reference.update({'checked': !isChecked}),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 28, height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isChecked ? const Color(0xFF00BFA5) : Colors.transparent,
                                      border: Border.all(color: isChecked ? const Color(0xFF00BFA5) : Colors.white24, width: 2),
                                    ),
                                    child: isChecked ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                                  ),
                                ),
                                title: Text(
                                  data['text'] ?? '',
                                  style: GoogleFonts.inter(
                                    color: isChecked ? Colors.white30 : Colors.white,
                                    fontWeight: FontWeight.w500,
                                    decoration: isChecked ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                subtitle: Text(
                                  'by ${data['addedBy'] ?? ''}',
                                  style: GoogleFonts.inter(color: Colors.white.withOpacity(0.15), fontSize: 11),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: _selectedTeamId != null
          ? FloatingActionButton(
              onPressed: _addItem,
              backgroundColor: const Color(0xFF00BFA5),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }
}
