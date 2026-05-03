import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/notification_bell.dart';

class TravelJournalScreen extends StatefulWidget {
  const TravelJournalScreen({super.key});
  @override
  State<TravelJournalScreen> createState() => _TravelJournalScreenState();
}

class _TravelJournalScreenState extends State<TravelJournalScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference get _journalRef =>
      FirebaseFirestore.instance.collection('users').doc(_uid).collection('journal_entries');

  Future<void> _addEntry() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String mood = '😊';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1C2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('New Entry', style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mood selector
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                for (final m in ['😊', '🤩', '😌', '😢', '😤', '🥱'])
                  GestureDetector(
                    onTap: () => setS(() => mood = m),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: mood == m ? const Color(0xFF1A73E8).withOpacity(0.2) : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: mood == m ? const Color(0xFF1A73E8) : Colors.transparent, width: 2),
                      ),
                      child: Text(m, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Title (e.g. Day 1 in Goa)',
                  hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
                  filled: true, fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bodyCtrl,
                maxLines: 5,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Write about your day...',
                  hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
                  filled: true, fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                await _journalRef.add({
                  'title': titleCtrl.text.trim(),
                  'body': bodyCtrl.text.trim(),
                  'mood': mood,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final d = ts.toDate();
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Travel Journal', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _journalRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          final entries = snapshot.data?.docs ?? [];

          if (entries.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_stories_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 12),
              Text('Your journal is empty', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
              Text('Tap + to write your first entry', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
            ]));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final data = entries[i].data() as Map<String, dynamic>;
              final title = data['title'] as String? ?? '';
              final body = data['body'] as String? ?? '';
              final mood = data['mood'] as String? ?? '😊';
              final ts = data['createdAt'] as Timestamp?;

              return Dismissible(
                key: Key(entries[i].id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                ),
                onDismissed: (_) => entries[i].reference.delete(),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(mood, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(title,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
                      Text(_timeAgo(ts), style: GoogleFonts.inter(color: Colors.white24, fontSize: 11)),
                    ]),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(body, style: GoogleFonts.inter(color: Colors.white54, fontSize: 13, height: 1.5),
                          maxLines: 4, overflow: TextOverflow.ellipsis),
                    ],
                  ]),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        backgroundColor: const Color(0xFF1A73E8),
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
    );
  }
}
