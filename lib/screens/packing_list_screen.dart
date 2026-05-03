import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/notification_bell.dart';

class PackingListScreen extends StatefulWidget {
  const PackingListScreen({super.key});

  @override
  State<PackingListScreen> createState() => _PackingListScreenState();
}

class _PackingListScreenState extends State<PackingListScreen> {
  static final _firestore = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference get _listsRef =>
      _firestore.collection('users').doc(_uid).collection('packing_lists');

  void _showAddItem(String listId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Item', style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. Charger, Sunscreen...',
            hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await _listsRef.doc(listId).collection('items').add({
                'name': ctrl.text.trim(),
                'packed': false,
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

  void _showCreateList() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Packing List', style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. Goa Trip, Office Trip...',
            hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await _listsRef.add({
                'name': ctrl.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Create', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
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
        title: Text('Packing Lists', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _listsRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final lists = snapshot.data?.docs ?? [];

          if (lists.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.luggage_rounded, size: 64, color: Colors.white.withOpacity(0.12)),
                  const SizedBox(height: 12),
                  Text('No packing lists', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Create one for your next trip!', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final listDoc = lists[index];
              final listData = listDoc.data() as Map<String, dynamic>;
              final listName = listData['name'] as String? ?? 'Unnamed';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  leading: const Icon(Icons.luggage_rounded, color: Color(0xFF00BFA5), size: 22),
                  title: Text(listName, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_rounded, color: Color(0xFF00BFA5), size: 20),
                        onPressed: () => _showAddItem(listDoc.id),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: Colors.white.withOpacity(0.3), size: 20),
                        onPressed: () => _listsRef.doc(listDoc.id).delete(),
                      ),
                    ],
                  ),
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: _listsRef.doc(listDoc.id).collection('items').orderBy('createdAt').snapshots(),
                      builder: (context, itemSnap) {
                        final items = itemSnap.data?.docs ?? [];
                        if (items.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('No items yet — tap + to add', style: GoogleFonts.inter(color: Colors.white24, fontSize: 12)),
                          );
                        }
                        return Column(
                          children: items.map((itemDoc) {
                            final itemData = itemDoc.data() as Map<String, dynamic>;
                            final packed = itemData['packed'] as bool? ?? false;
                            return CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: const Color(0xFF00BFA5),
                              checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              value: packed,
                              onChanged: (val) {
                                _listsRef.doc(listDoc.id).collection('items').doc(itemDoc.id).update({'packed': val});
                              },
                              title: Text(
                                itemData['name'] ?? '',
                                style: GoogleFonts.inter(
                                  color: packed ? Colors.white24 : Colors.white70,
                                  fontSize: 13,
                                  decoration: packed ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              secondary: IconButton(
                                icon: Icon(Icons.close_rounded, size: 16, color: Colors.white.withOpacity(0.2)),
                                onPressed: () => _listsRef.doc(listDoc.id).collection('items').doc(itemDoc.id).delete(),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateList,
        backgroundColor: const Color(0xFF00BFA5),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('New List', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
