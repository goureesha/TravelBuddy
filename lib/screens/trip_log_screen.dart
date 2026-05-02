import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/trip_log_service.dart';
import '../services/team_service.dart';
import '../widgets/notification_bell.dart';

class TripLogScreen extends StatefulWidget {
  const TripLogScreen({super.key});

  @override
  State<TripLogScreen> createState() => _TripLogScreenState();
}

class _TripLogScreenState extends State<TripLogScreen> {
  String? _selectedTeamId;
  String _selectedLabel = 'Personal';

  void _pickMode() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Select Mode', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFF00BFA5), child: Icon(Icons.person, color: Colors.white, size: 20)),
            title: Text('Personal', style: GoogleFonts.inter(color: Colors.white)),
            trailing: _selectedTeamId == null ? const Icon(Icons.check_circle, color: Color(0xFF00BFA5)) : null,
            onTap: () { setState(() { _selectedTeamId = null; _selectedLabel = 'Personal'; }); Navigator.pop(ctx); },
          ),
          const Divider(color: Colors.white12, height: 1),
          StreamBuilder<QuerySnapshot>(
            stream: TeamService.getMyTeams(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()));
              final teams = snapshot.data!.docs;
              if (teams.isEmpty) return const SizedBox.shrink();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: teams.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFF1A73E8), child: Icon(Icons.group, color: Colors.white, size: 20)),
                    title: Text(data['name'] ?? '', style: GoogleFonts.inter(color: Colors.white)),
                    trailing: _selectedTeamId == doc.id ? const Icon(Icons.check_circle, color: Color(0xFF1A73E8)) : null,
                    onTap: () { setState(() { _selectedTeamId = doc.id; _selectedLabel = data['name'] ?? 'Team'; }); Navigator.pop(ctx); },
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showAddCheckpoint() {
    final placeCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log Checkpoint', style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: placeCtrl,
              autofocus: true,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Place name',
                labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              style: GoogleFonts.inter(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFA5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (placeCtrl.text.trim().isEmpty) return;
              await TripLogService.logCheckpoint(
                teamId: _selectedTeamId,
                placeName: placeCtrl.text.trim(),
                notes: notesCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Log', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
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
        title: Text('Trip Log', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          const NotificationBell(),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: _pickMode,
            icon: Icon(
              _selectedTeamId == null ? Icons.person_rounded : Icons.group_rounded,
              size: 18, color: const Color(0xFF00BFA5),
            ),
            label: Text(_selectedLabel, style: GoogleFonts.inter(color: const Color(0xFF00BFA5), fontSize: 13)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: TripLogService.getTripLog(_selectedTeamId),
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
                  Icon(Icons.timeline_rounded, size: 64, color: Colors.white.withOpacity(0.12)),
                  const SizedBox(height: 12),
                  Text('No checkpoints yet', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 80),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final place = data['placeName'] as String? ?? '';
              final notes = data['notes'] as String? ?? '';
              final userName = data['userName'] as String? ?? '';
              final timestamp = data['timestamp'] as Timestamp?;
              final timeStr = timestamp != null ? DateFormat('hh:mm a').format(timestamp.toDate()) : '';
              final dateStr = timestamp != null ? DateFormat('dd MMM').format(timestamp.toDate()) : '';

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                ),
                onDismissed: (_) => TripLogService.deleteEntry(_selectedTeamId, doc.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(place, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                          Text(timeStr, style: GoogleFonts.inter(color: Colors.white30, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(userName, style: GoogleFonts.inter(color: Colors.white24, fontSize: 11)),
                          const SizedBox(width: 12),
                          Text(dateStr, style: GoogleFonts.inter(color: Colors.white24, fontSize: 11)),
                        ],
                      ),
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(notes, style: GoogleFonts.inter(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCheckpoint,
        backgroundColor: const Color(0xFF00BFA5),
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: Text('Log Checkpoint', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
