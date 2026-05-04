import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/notification_bell.dart';
import 'trip_post_detail_screen.dart';
import 'create_trip_post_screen.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});
  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  String _filter = 'All';
  String _sort = 'newest';
  final _searchCtrl = TextEditingController();

  static const _types = ['All', 'Beach', 'Mountain', 'Cultural', 'Weekend', 'Pilgrimage', 'Road Trip', 'Adventure'];

  static const _typeEmojis = {
    'Beach': '🏖️', 'Mountain': '🏔️', 'Cultural': '🏰', 'Weekend': '☕',
    'Pilgrimage': '🙏', 'Road Trip': '🚗', 'Adventure': '🧗', 'All': '🌍',
  };

  CollectionReference get _postsRef => FirebaseFirestore.instance.collection('community_trips');

  Query _buildQuery() {
    Query q = _postsRef;
    if (_filter != 'All') q = q.where('tripType', isEqualTo: _filter);
    switch (_sort) {
      case 'newest': q = q.orderBy('createdAt', descending: true); break;
      case 'liked': q = q.orderBy('likes', descending: true); break;
      case 'cheapest': q = q.orderBy('totalCost', descending: false); break;
      case 'shortest': q = q.orderBy('duration', descending: false); break;
      default: q = q.orderBy('createdAt', descending: true);
    }
    return q.limit(50);
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Community', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, size: 20),
            color: const Color(0xFF1C2128),
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => [
              _sortItem('newest', 'Newest First'),
              _sortItem('liked', 'Most Liked'),
              _sortItem('cheapest', 'Cheapest'),
              _sortItem('shortest', 'Shortest'),
            ],
          ),
          const NotificationBell(), const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search destinations...', hintStyle: GoogleFonts.inter(color: Colors.white24),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white24, size: 20),
              filled: true, fillColor: const Color(0xFF161B22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        // Type chips
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _types.map((t) {
              final sel = t == _filter;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  avatar: Text(_typeEmojis[t] ?? '🌍', style: const TextStyle(fontSize: 14)),
                  label: Text(t, style: GoogleFonts.inter(fontSize: 11, color: sel ? Colors.white : Colors.white54, fontWeight: FontWeight.w600)),
                  selected: sel, selectedColor: const Color(0xFF1A73E8),
                  backgroundColor: const Color(0xFF161B22),
                  side: BorderSide(color: sel ? const Color(0xFF1A73E8) : Colors.white.withOpacity(0.08)),
                  onSelected: (_) => setState(() => _filter = t),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Feed
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildQuery().snapshots(),
            builder: (context, snap) {
              var docs = snap.data?.docs ?? [];

              // Client-side search filter
              final search = _searchCtrl.text.trim().toLowerCase();
              if (search.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final title = (data['title'] as String? ?? '').toLowerCase();
                  final dest = (data['destination'] as String? ?? '').toLowerCase();
                  return title.contains(search) || dest.contains(search);
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('🌍', style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text('No trips shared yet', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
                  Text('Be the first to share!', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTripPostScreen())),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text('Share Your Trip', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8)),
                  ),
                ]));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, i) => _tripCard(docs[i]),
              );
            },
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTripPostScreen())),
        backgroundColor: const Color(0xFF1A73E8),
        icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
        label: Text('Share Trip', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _tripCard(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final title = d['title'] as String? ?? 'Untitled Trip';
    final dest = d['destination'] as String? ?? '';
    final type = d['tripType'] as String? ?? '';
    final duration = (d['duration'] as num?)?.toInt() ?? 0;
    final cost = (d['totalCost'] as num?)?.toDouble() ?? 0;
    final likes = (d['likes'] as num?)?.toInt() ?? 0;
    final views = (d['views'] as num?)?.toInt() ?? 0;
    final author = d['authorName'] as String? ?? 'Traveler';
    final rating = (d['rating'] as num?)?.toDouble() ?? 0;
    final dayCount = (d['dayWise'] as List?)?.length ?? 0;

    return GestureDetector(
      onTap: () {
        // Increment views
        doc.reference.update({'views': FieldValue.increment(1)});
        Navigator.push(context, MaterialPageRoute(builder: (_) => TripPostDetailScreen(postId: doc.id)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header gradient
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  type == 'Beach' ? const Color(0xFF00ACC1) :
                  type == 'Mountain' ? const Color(0xFF5C6BC0) :
                  type == 'Cultural' ? const Color(0xFFFF6D00) :
                  const Color(0xFF1A73E8),
                  const Color(0xFF0D1117),
                ],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Text(_typeEmojis[type] ?? '🌍', style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(dest, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
              ])),
            ]),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(children: [
              Row(children: [
                _chip('${duration}d', Icons.timer_rounded),
                const SizedBox(width: 6),
                _chip('₹${(cost / 1000).toStringAsFixed(0)}k', Icons.currency_rupee_rounded),
                const SizedBox(width: 6),
                if (dayCount > 0) _chip('$dayCount places', Icons.place_rounded),
                const Spacer(),
                if (rating > 0) Row(children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 14),
                  Text(' ${rating.toStringAsFixed(1)}', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                ]),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                CircleAvatar(radius: 10, backgroundColor: const Color(0xFF1A73E8).withOpacity(0.2),
                    child: Text(author.isNotEmpty ? author[0].toUpperCase() : '?',
                        style: GoogleFonts.inter(color: const Color(0xFF1A73E8), fontSize: 10, fontWeight: FontWeight.bold))),
                const SizedBox(width: 6),
                Text(author, style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                const Spacer(),
                Icon(Icons.favorite_rounded, color: likes > 0 ? Colors.redAccent : Colors.white24, size: 14),
                Text(' $likes', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                const SizedBox(width: 10),
                const Icon(Icons.visibility_rounded, color: Colors.white24, size: 14),
                Text(' $views', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Colors.white38),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  PopupMenuItem<String> _sortItem(String value, String label) {
    return PopupMenuItem(value: value, child: Text(label,
        style: GoogleFonts.inter(color: _sort == value ? const Color(0xFF1A73E8) : Colors.white70, fontSize: 13)));
  }
}
