import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'trip_post_detail_screen.dart';

class TripCompareScreen extends StatefulWidget {
  const TripCompareScreen({super.key});
  @override
  State<TripCompareScreen> createState() => _TripCompareScreenState();
}

class _TripCompareScreenState extends State<TripCompareScreen> {
  Map<String, dynamic>? _tripA, _tripB;
  String? _idA, _idB;

  CollectionReference get _postsRef => FirebaseFirestore.instance.collection('community_trips');

  Future<void> _pickTrip(bool isA) async {
    final snap = await _postsRef.orderBy('createdAt', descending: true).limit(30).get();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Select Trip ${isA ? "A" : "B"}', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...snap.docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final title = d['title'] as String? ?? 'Untitled';
            final dest = d['destination'] as String? ?? '';
            final cost = (d['totalCost'] as num?)?.toDouble() ?? 0;
            final dur = (d['duration'] as num?)?.toInt() ?? 0;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: const Color(0xFF1A73E8).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text('🌍', style: const TextStyle(fontSize: 20))),
              ),
              title: Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text('$dest • ${dur}d • ₹${cost.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
              onTap: () {
                setState(() {
                  if (isA) { _tripA = d; _idA = doc.id; } else { _tripB = d; _idB = doc.id; }
                });
                Navigator.pop(ctx);
              },
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(title: Text('Compare Trips', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Trip selection
          Row(children: [
            Expanded(child: _tripSelector(_tripA, 'Trip A', true, const Color(0xFF1A73E8))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('VS', style: TextStyle(color: Colors.white24, fontSize: 16, fontWeight: FontWeight.w900)),
            ),
            Expanded(child: _tripSelector(_tripB, 'Trip B', false, const Color(0xFFFF6D00))),
          ]),
          const SizedBox(height: 20),

          if (_tripA != null && _tripB != null) ...[
            // Comparison rows
            _compareRow('Total Cost', '₹${_val(_tripA!, 'totalCost')}', '₹${_val(_tripB!, 'totalCost')}',
                _num(_tripA!, 'totalCost'), _num(_tripB!, 'totalCost'), true),
            _compareRow('Duration', '${_tripA!['duration']}d', '${_tripB!['duration']}d',
                _num(_tripA!, 'duration'), _num(_tripB!, 'duration'), true),
            _compareRow('Daily Cost', '₹${_dailyCost(_tripA!)}', '₹${_dailyCost(_tripB!)}',
                double.tryParse(_dailyCost(_tripA!)) ?? 0, double.tryParse(_dailyCost(_tripB!)) ?? 0, true),
            _compareRow('Rating', '${(_num(_tripA!, 'rating')).toStringAsFixed(1)} ⭐', '${(_num(_tripB!, 'rating')).toStringAsFixed(1)} ⭐',
                _num(_tripA!, 'rating'), _num(_tripB!, 'rating'), false),
            _compareRow('Likes', '${_tripA!['likes'] ?? 0}', '${_tripB!['likes'] ?? 0}',
                _num(_tripA!, 'likes'), _num(_tripB!, 'likes'), false),
            _compareRow('Hotels', '${((_tripA!['hotels'] as List?) ?? []).length}', '${((_tripB!['hotels'] as List?) ?? []).length}',
                ((_tripA!['hotels'] as List?) ?? []).length.toDouble(), ((_tripB!['hotels'] as List?) ?? []).length.toDouble(), false),

            // Cost breakdown comparison
            const SizedBox(height: 20),
            Text('Cost Breakdown', style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ..._compareCosts(),

            // Verdict
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFF7C4DFF).withOpacity(0.15), const Color(0xFF0D1117)]),
                borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.2)),
              ),
              child: Column(children: [
                Text('📊 Quick Verdict', style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _verdict('Budget Friendly', _num(_tripA!, 'totalCost') <= _num(_tripB!, 'totalCost') ? 'A' : 'B'),
                _verdict('More Detailed', ((_tripA!['dayWise'] as List?) ?? []).length >= ((_tripB!['dayWise'] as List?) ?? []).length ? 'A' : 'B'),
                _verdict('Higher Rated', _num(_tripA!, 'rating') >= _num(_tripB!, 'rating') ? 'A' : 'B'),
                _verdict('More Liked', _num(_tripA!, 'likes') >= _num(_tripB!, 'likes') ? 'A' : 'B'),
              ]),
            ),
          ] else ...[
            const SizedBox(height: 60),
            Center(child: Column(children: [
              Text('⚖️', style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('Select two trips to compare', style: GoogleFonts.inter(color: Colors.white38, fontSize: 14)),
            ])),
          ],
        ],
      ),
    );
  }

  Widget _tripSelector(Map<String, dynamic>? trip, String label, bool isA, Color color) {
    return GestureDetector(
      onTap: () => _pickTrip(isA),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: trip != null ? color.withOpacity(0.08) : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: trip != null ? color.withOpacity(0.3) : Colors.white.withOpacity(0.08)),
        ),
        child: trip != null
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trip['title'] ?? '', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                Text('${trip['destination'] ?? ''}', style: GoogleFonts.inter(color: color, fontSize: 11)),
                Text('${trip['duration']}d • ₹${_val(trip, 'totalCost')}', style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
                // View detail link
                GestureDetector(
                  onTap: () {
                    final id = isA ? _idA : _idB;
                    if (id != null) Navigator.push(context, MaterialPageRoute(builder: (_) => TripPostDetailScreen(postId: id)));
                  },
                  child: Text('View details →', style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ])
            : Column(children: [
                Icon(Icons.add_circle_rounded, color: color, size: 28),
                const SizedBox(height: 4),
                Text(label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
              ]),
      ),
    );
  }

  Widget _compareRow(String label, String valA, String valB, double numA, double numB, bool lowerBetter) {
    final aWins = lowerBetter ? numA <= numB : numA >= numB;
    final bWins = lowerBetter ? numB <= numA : numB >= numA;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Row(children: [
        Text(valA, style: GoogleFonts.inter(
            color: aWins ? const Color(0xFF00BFA5) : Colors.white54, fontSize: 13,
            fontWeight: aWins ? FontWeight.w800 : FontWeight.w400)),
        Expanded(child: Center(child: Text(label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)))),
        Text(valB, style: GoogleFonts.inter(
            color: bWins && !aWins ? const Color(0xFF00BFA5) : Colors.white54, fontSize: 13,
            fontWeight: bWins && !aWins ? FontWeight.w800 : FontWeight.w400)),
      ]),
    );
  }

  List<Widget> _compareCosts() {
    final catsA = _tripA!['costBreakdown'] as Map<String, dynamic>? ?? {};
    final catsB = _tripB!['costBreakdown'] as Map<String, dynamic>? ?? {};
    final allCats = {...catsA.keys, ...catsB.keys};

    return allCats.map((cat) {
      final a = (catsA[cat] as num?)?.toDouble() ?? 0;
      final b = (catsB[cat] as num?)?.toDouble() ?? 0;
      final maxVal = [a, b].reduce((a, b) => a > b ? a : b);

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cat[0].toUpperCase() + cat.substring(1), style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 3),
          Row(children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: maxVal > 0 ? a / maxVal : 0, minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.04), valueColor: const AlwaysStoppedAnimation(Color(0xFF1A73E8))))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('₹${a.toStringAsFixed(0)} | ₹${b.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 10))),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: maxVal > 0 ? b / maxVal : 0, minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.04), valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6D00))))),
          ]),
        ]),
      );
    }).toList();
  }

  Widget _verdict(String label, String winner) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: winner == 'A' ? const Color(0xFF1A73E8).withOpacity(0.2) : const Color(0xFFFF6D00).withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('Trip $winner', style: GoogleFonts.inter(
            color: winner == 'A' ? const Color(0xFF1A73E8) : const Color(0xFFFF6D00), fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    ]),
  );

  double _num(Map<String, dynamic> d, String key) => (d[key] as num?)?.toDouble() ?? 0;
  String _val(Map<String, dynamic> d, String key) => ((d[key] as num?)?.toDouble() ?? 0).toStringAsFixed(0);
  String _dailyCost(Map<String, dynamic> d) {
    final cost = (d['totalCost'] as num?)?.toDouble() ?? 0;
    final dur = (d['duration'] as num?)?.toInt() ?? 1;
    return (cost / dur).toStringAsFixed(0);
  }
}
