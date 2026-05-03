import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class TripPostDetailScreen extends StatefulWidget {
  final String postId;
  const TripPostDetailScreen({super.key, required this.postId});
  @override
  State<TripPostDetailScreen> createState() => _TripPostDetailScreenState();
}

class _TripPostDetailScreenState extends State<TripPostDetailScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  bool _liked = false;

  DocumentReference get _postRef => FirebaseFirestore.instance.collection('community_trips').doc(widget.postId);

  static const _typeColors = {
    'Beach': Color(0xFF00ACC1), 'Mountain': Color(0xFF5C6BC0), 'Cultural': Color(0xFFFF6D00),
    'Weekend': Color(0xFF43A047), 'Pilgrimage': Color(0xFFFF8F00), 'Road Trip': Color(0xFF1A73E8),
    'Adventure': Color(0xFFE53935),
  };

  Future<void> _toggleLike() async {
    setState(() => _liked = !_liked);
    await _postRef.update({'likes': FieldValue.increment(_liked ? 1 : -1)});
  }

  Future<void> _cloneTrip(Map<String, dynamic> d) async {
    await FirebaseFirestore.instance.collection('users').doc(_uid).collection('planned_trips').add({
      'destination': d['destination'] ?? d['title'],
      'startDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
      'endDate': Timestamp.fromDate(DateTime.now().add(Duration(days: 7 + ((d['duration'] as num?)?.toInt() ?? 3)))),
      'notes': 'Cloned from community: ${d['title']}\n\n${(d['dayWise'] as List?)?.map((day) => '${day['title']}: ${day['places']}').join('\n') ?? ''}',
      'budget': (d['totalCost'] as num?)?.toDouble() ?? 0,
      'clonedFrom': widget.postId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Trip cloned to your plans!', style: GoogleFonts.inter()), backgroundColor: const Color(0xFF00BFA5)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _postRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final d = snap.data!.data() as Map<String, dynamic>;
          final title = d['title'] as String? ?? '';
          final dest = d['destination'] as String? ?? '';
          final type = d['tripType'] as String? ?? 'Road Trip';
          final duration = (d['duration'] as num?)?.toInt() ?? 0;
          final cost = (d['totalCost'] as num?)?.toDouble() ?? 0;
          final likes = (d['likes'] as num?)?.toInt() ?? 0;
          final rating = (d['rating'] as num?)?.toDouble() ?? 0;
          final author = d['authorName'] as String? ?? 'Traveler';
          final season = d['bestSeason'] as String? ?? '';
          final costBreak = d['costBreakdown'] as Map<String, dynamic>? ?? {};
          final dayWise = List<Map<String, dynamic>>.from(d['dayWise'] ?? []);
          final hotels = List<Map<String, dynamic>>.from(d['hotels'] ?? []);
          final roads = List<Map<String, dynamic>>.from(d['roads'] ?? []);
          final avoidList = List<String>.from(d['thingsToAvoid'] ?? []);
          final packList = List<String>.from(d['packingList'] ?? []);
          final tags = List<String>.from(d['tags'] ?? []);
          final color = _typeColors[type] ?? const Color(0xFF1A73E8);

          return CustomScrollView(slivers: [
            // Hero header
            SliverAppBar(
              expandedHeight: 200, pinned: true,
              backgroundColor: const Color(0xFF0D1117),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.3), const Color(0xFF0D1117)],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                  child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(height: 40),
                    Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                    Text(dest, style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _tag('$duration days'), _tag('₹${(cost / 1000).toStringAsFixed(0)}k'), _tag(type),
                      if (rating > 0) _tag('${rating.toStringAsFixed(1)} ⭐'),
                    ]),
                  ])),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _liked ? Colors.redAccent : Colors.white54),
                  onPressed: _toggleLike,
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.white54, size: 20),
                  onPressed: () => _cloneTrip(d),
                ),
              ],
            ),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Author & meta
                Row(children: [
                  CircleAvatar(radius: 14, backgroundColor: color.withOpacity(0.2),
                      child: Text(author.isNotEmpty ? author[0].toUpperCase() : '?',
                          style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 8),
                  Text('by $author', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                  const Spacer(),
                  Icon(Icons.favorite_rounded, color: Colors.redAccent.withOpacity(0.6), size: 14),
                  Text(' $likes', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                  if (season.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Text('📅 $season', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                  ],
                ]),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, children: tags.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text('#$t', style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                  )).toList()),
                ],

                // Cost Breakdown
                if (costBreak.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _section('💰 Cost Breakdown — ₹${cost.toStringAsFixed(0)}'),
                  const SizedBox(height: 8),
                  ...costBreak.entries.where((e) => (e.value as num) > 0).map((e) {
                    final v = (e.value as num).toDouble();
                    final pct = cost > 0 ? v / cost : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        SizedBox(width: 80, child: Text(e.key[0].toUpperCase() + e.key.substring(1),
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12))),
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(value: pct, minHeight: 6,
                              backgroundColor: Colors.white.withOpacity(0.04),
                              valueColor: AlwaysStoppedAnimation(color)),
                        )),
                        const SizedBox(width: 10),
                        Text('₹${v.toStringAsFixed(0)}', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    );
                  }),
                ],

                // Day-wise itinerary
                if (dayWise.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _section('📋 Day-by-Day Itinerary'),
                  const SizedBox(height: 8),
                  ...List.generate(dayWise.length, (i) {
                    final day = dayWise[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withOpacity(0.12)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Day ${i + 1}: ${day['title'] ?? ''}',
                            style: GoogleFonts.inter(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
                        if ((day['places'] as String? ?? '').isNotEmpty) _dayLine('📍', day['places']),
                        if ((day['stay'] as String? ?? '').isNotEmpty) _dayLine('🏨', day['stay']),
                        if ((day['food'] as String? ?? '').isNotEmpty) _dayLine('🍽️', day['food']),
                        if ((day['transport'] as String? ?? '').isNotEmpty) _dayLine('🚗', day['transport']),
                        if ((day['tips'] as String? ?? '').isNotEmpty) _dayLine('💡', day['tips']),
                        if ((day['avoid'] as String? ?? '').isNotEmpty) _dayLine('⚠️', day['avoid']),
                      ]),
                    );
                  }),
                ],

                // Hotels
                if (hotels.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _section('🏨 Hotels & Stays'),
                  const SizedBox(height: 8),
                  ...hotels.map((h) => Container(
                    margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(h['name'] ?? '', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
                        if ((h['cost'] as num? ?? 0) > 0)
                          Text('₹${(h['cost'] as num).toStringAsFixed(0)}/night',
                              style: GoogleFonts.inter(color: const Color(0xFF00BFA5), fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                      if ((h['location'] as String? ?? '').isNotEmpty)
                        Text('📍 ${h['location']}', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                      if ((h['review'] as String? ?? '').isNotEmpty)
                        Text('"${h['review']}"', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
                    ]),
                  )),
                ],

                // Roads
                if (roads.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _section('🛣️ Road Conditions'),
                  const SizedBox(height: 8),
                  ...roads.map((r) => Container(
                    margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r['name'] ?? '', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      if ((r['condition'] as String? ?? '').isNotEmpty)
                        Text('Condition: ${r['condition']}', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                      if ((r['tips'] as String? ?? '').isNotEmpty)
                        Text('💡 ${r['tips']}', style: GoogleFonts.inter(color: const Color(0xFF00BFA5), fontSize: 12)),
                      if ((r['danger'] as String? ?? '').isNotEmpty)
                        Text('⚠️ ${r['danger']}', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12)),
                    ]),
                  )),
                ],

                // Things to avoid
                if (avoidList.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _section('🚫 Things to Avoid'),
                  const SizedBox(height: 8),
                  ...avoidList.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('• ', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                      Expanded(child: Text(a, style: GoogleFonts.inter(color: Colors.white70, fontSize: 13))),
                    ]),
                  )),
                ],

                // Packing
                if (packList.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _section('🎒 Packing List'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: packList.map((p) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                    child: Text(p, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                  )).toList()),
                ],

                // Clone button
                const SizedBox(height: 30),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: () => _cloneTrip(d),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text('Clone to My Trips', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: color,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                )),
                const SizedBox(height: 30),
              ]),
            )),
          ]);
        },
      ),
    );
  }

  Widget _section(String text) => Text(text, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800));

  Widget _tag(String text) => Container(
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
  );

  Widget _dayLine(String emoji, String? text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$emoji ', style: const TextStyle(fontSize: 13)),
      Expanded(child: Text(text ?? '', style: GoogleFonts.inter(color: Colors.white60, fontSize: 12))),
    ]),
  );
}
