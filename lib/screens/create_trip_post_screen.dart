import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class CreateTripPostScreen extends StatefulWidget {
  const CreateTripPostScreen({super.key});
  @override
  State<CreateTripPostScreen> createState() => _CreateTripPostScreenState();
}

class _CreateTripPostScreenState extends State<CreateTripPostScreen> {
  int _step = 0;
  bool _saving = false;

  // Step 1: Basics
  final _titleCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  String _tripType = 'Road Trip';
  int _duration = 3;
  double _rating = 4.0;
  String _bestSeason = 'Oct-Mar';

  // Step 2: Day-wise
  final List<Map<String, TextEditingController>> _days = [];

  // Step 3: Costs
  final _costCtrls = <String, TextEditingController>{
    'transport': TextEditingController(), 'stay': TextEditingController(),
    'food': TextEditingController(), 'activities': TextEditingController(),
    'shopping': TextEditingController(), 'misc': TextEditingController(),
  };

  // Step 4: Hotels
  final List<Map<String, TextEditingController>> _hotels = [];

  // Step 5: Roads
  final List<Map<String, TextEditingController>> _roads = [];

  // Step 6: Avoid + Packing
  final _avoidCtrl = TextEditingController();
  final _packingCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  static const _types = ['Beach', 'Mountain', 'Cultural', 'Weekend', 'Pilgrimage', 'Road Trip', 'Adventure'];
  static const _seasons = ['Jan-Mar', 'Apr-Jun', 'Jul-Sep', 'Oct-Dec', 'Oct-Mar', 'Year-round'];

  @override
  void initState() {
    super.initState();
    _updateDays();
  }

  void _updateDays() {
    while (_days.length < _duration) {
      _days.add({
        'title': TextEditingController(text: 'Day ${_days.length + 1}'),
        'places': TextEditingController(),
        'stay': TextEditingController(),
        'food': TextEditingController(),
        'transport': TextEditingController(),
        'tips': TextEditingController(),
        'avoid': TextEditingController(),
      });
    }
    while (_days.length > _duration) _days.removeLast();
  }

  void _addHotel() => setState(() => _hotels.add({
    'name': TextEditingController(), 'cost': TextEditingController(),
    'rating': TextEditingController(text: '4'), 'review': TextEditingController(),
    'location': TextEditingController(),
  }));

  void _addRoad() => setState(() => _roads.add({
    'name': TextEditingController(), 'condition': TextEditingController(),
    'tips': TextEditingController(), 'danger': TextEditingController(),
  }));

  double get _totalCost {
    double t = 0;
    _costCtrls.forEach((_, c) => t += double.tryParse(c.text) ?? 0);
    return t;
  }

  Future<void> _publish() async {
    if (_titleCtrl.text.trim().isEmpty || _destCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final user = FirebaseAuth.instance.currentUser!;
    final costs = <String, double>{};
    _costCtrls.forEach((k, c) => costs[k] = double.tryParse(c.text) ?? 0);

    final dayWise = _days.map((d) => {
      'title': d['title']!.text.trim(),
      'places': d['places']!.text.trim(),
      'stay': d['stay']!.text.trim(),
      'food': d['food']!.text.trim(),
      'transport': d['transport']!.text.trim(),
      'tips': d['tips']!.text.trim(),
      'avoid': d['avoid']!.text.trim(),
    }).toList();

    final hotels = _hotels.map((h) => {
      'name': h['name']!.text.trim(),
      'cost': double.tryParse(h['cost']!.text) ?? 0,
      'rating': double.tryParse(h['rating']!.text) ?? 4,
      'review': h['review']!.text.trim(),
      'location': h['location']!.text.trim(),
    }).toList();

    final roads = _roads.map((r) => {
      'name': r['name']!.text.trim(),
      'condition': r['condition']!.text.trim(),
      'tips': r['tips']!.text.trim(),
      'danger': r['danger']!.text.trim(),
    }).toList();

    final avoidList = _avoidCtrl.text.trim().split('\n').where((s) => s.trim().isNotEmpty).toList();
    final packList = _packingCtrl.text.trim().split('\n').where((s) => s.trim().isNotEmpty).toList();
    final tagsList = _tagsCtrl.text.trim().split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();

    await FirebaseFirestore.instance.collection('community_trips').add({
      'authorUid': user.uid,
      'authorName': user.displayName ?? 'Traveler',
      'title': _titleCtrl.text.trim(),
      'destination': _destCtrl.text.trim(),
      'tripType': _tripType,
      'duration': _duration,
      'totalCost': _totalCost,
      'costBreakdown': costs,
      'rating': _rating,
      'bestSeason': _bestSeason,
      'dayWise': dayWise,
      'hotels': hotels,
      'roads': roads,
      'thingsToAvoid': avoidList,
      'packingList': packList,
      'tags': tagsList,
      'likes': 0,
      'views': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Trip published!', style: GoogleFonts.inter()), backgroundColor: const Color(0xFF00BFA5)),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['Basics', 'Itinerary', 'Costs', 'Hotels', 'Roads', 'Tips', 'Review'];

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Share Trip', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: List.generate(steps.length, (i) => Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _step = i),
                child: Column(children: [
                  Container(
                    height: 3, margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i <= _step ? const Color(0xFF1A73E8) : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(steps[i], style: GoogleFonts.inter(
                      color: i == _step ? const Color(0xFF1A73E8) : Colors.white24, fontSize: 9, fontWeight: FontWeight.w600)),
                ]),
              ),
            ))),
          ),
        ),
      ),
      body: IndexedStack(index: _step, children: [
        _buildBasics(),
        _buildItinerary(),
        _buildCosts(),
        _buildHotels(),
        _buildRoads(),
        _buildTips(),
        _buildReview(),
      ]),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: const Color(0xFF161B22),
        child: Row(children: [
          if (_step > 0)
            OutlinedButton(
              onPressed: () => setState(() => _step--),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white54,
                  side: BorderSide(color: Colors.white.withOpacity(0.1))),
              child: Text('Back', style: GoogleFonts.inter()),
            ),
          const Spacer(),
          ElevatedButton(
            onPressed: _saving ? null : (_step < 6 ? () => setState(() { if (_step == 0) _updateDays(); _step++; }) : _publish),
            style: ElevatedButton.styleFrom(backgroundColor: _step == 6 ? const Color(0xFF00BFA5) : const Color(0xFF1A73E8),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_step == 6 ? 'Publish' : 'Next', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  // ─── Step builders ───
  Widget _buildBasics() => ListView(padding: const EdgeInsets.all(16), children: [
    _field(_titleCtrl, 'Trip Title', 'e.g. 5 Days in Ladakh on a Budget'),
    const SizedBox(height: 10),
    _field(_destCtrl, 'Destination', 'e.g. Ladakh, Jammu & Kashmir'),
    const SizedBox(height: 14),
    Text('Trip Type', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
    const SizedBox(height: 6),
    Wrap(spacing: 6, runSpacing: 6, children: _types.map((t) => ChoiceChip(
      label: Text(t, style: GoogleFonts.inter(fontSize: 11, color: _tripType == t ? Colors.white : Colors.white54)),
      selected: _tripType == t, selectedColor: const Color(0xFF1A73E8),
      backgroundColor: const Color(0xFF161B22),
      onSelected: (_) => setState(() => _tripType = t),
    )).toList()),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Duration: $_duration days', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
        Slider(value: _duration.toDouble(), min: 1, max: 30, divisions: 29,
            activeColor: const Color(0xFF1A73E8),
            onChanged: (v) => setState(() => _duration = v.toInt())),
      ])),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Rating: ${_rating.toStringAsFixed(1)}', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
        Slider(value: _rating, min: 1, max: 5, divisions: 8,
            activeColor: const Color(0xFFFFB300),
            onChanged: (v) => setState(() => _rating = v)),
      ])),
    ]),
    const SizedBox(height: 10),
    Text('Best Season', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
    const SizedBox(height: 6),
    Wrap(spacing: 6, children: _seasons.map((s) => ChoiceChip(
      label: Text(s, style: GoogleFonts.inter(fontSize: 11, color: _bestSeason == s ? Colors.white : Colors.white54)),
      selected: _bestSeason == s, selectedColor: const Color(0xFF00BFA5),
      backgroundColor: const Color(0xFF161B22),
      onSelected: (_) => setState(() => _bestSeason = s),
    )).toList()),
  ]);

  Widget _buildItinerary() => ListView(padding: const EdgeInsets.all(16), children: [
    Text('Day-by-Day Itinerary', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
    const SizedBox(height: 4),
    Text('Fill in details for each day', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
    const SizedBox(height: 14),
    ...List.generate(_days.length, (i) {
      final d = _days[i];
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1A73E8).withOpacity(0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Day ${i + 1}', style: GoogleFonts.inter(color: const Color(0xFF1A73E8), fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _miniField(d['title']!, 'Title (e.g. Arrival Day)'),
          _miniField(d['places']!, 'Places visited'),
          _miniField(d['stay']!, 'Where you stayed'),
          _miniField(d['food']!, 'Food recommendations'),
          _miniField(d['transport']!, 'Transport used'),
          _miniField(d['tips']!, 'Tips for this day'),
          _miniField(d['avoid']!, 'Things to avoid'),
        ]),
      );
    }),
  ]);

  Widget _buildCosts() => ListView(padding: const EdgeInsets.all(16), children: [
    Text('Cost Breakdown', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
    const SizedBox(height: 4),
    Text('Total: ₹${_totalCost.toStringAsFixed(0)}', style: GoogleFonts.inter(color: const Color(0xFF00BFA5), fontSize: 20, fontWeight: FontWeight.w900)),
    const SizedBox(height: 14),
    ..._costCtrls.entries.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(controller: e.value, keyboardType: TextInputType.number,
        style: GoogleFonts.inter(color: Colors.white),
        onChanged: (_) => setState(() {}),
        decoration: _inputDeco('${e.key[0].toUpperCase()}${e.key.substring(1)} (₹)')),
    )),
  ]);

  Widget _buildHotels() => ListView(padding: const EdgeInsets.all(16), children: [
    Row(children: [
      Expanded(child: Text('Hotels & Stays', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
      IconButton(onPressed: _addHotel, icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF1A73E8))),
    ]),
    if (_hotels.isEmpty) Text('Tap + to add hotels', style: GoogleFonts.inter(color: Colors.white24, fontSize: 12)),
    ...List.generate(_hotels.length, (i) {
      final h = _hotels[i];
      return Container(
        margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06))),
        child: Column(children: [
          _miniField(h['name']!, 'Hotel name'),
          _miniField(h['cost']!, 'Cost per night (₹)', isNumber: true),
          _miniField(h['location']!, 'Location'),
          _miniField(h['review']!, 'Your review'),
        ]),
      );
    }),
  ]);

  Widget _buildRoads() => ListView(padding: const EdgeInsets.all(16), children: [
    Row(children: [
      Expanded(child: Text('Road Conditions', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
      IconButton(onPressed: _addRoad, icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF1A73E8))),
    ]),
    if (_roads.isEmpty) Text('Tap + to add road info', style: GoogleFonts.inter(color: Colors.white24, fontSize: 12)),
    ...List.generate(_roads.length, (i) {
      final r = _roads[i];
      return Container(
        margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06))),
        child: Column(children: [
          _miniField(r['name']!, 'Road/Route name'),
          _miniField(r['condition']!, 'Condition (Good/Bad/Dangerous)'),
          _miniField(r['tips']!, 'Tips'),
          _miniField(r['danger']!, 'Dangers/Warnings'),
        ]),
      );
    }),
  ]);

  Widget _buildTips() => ListView(padding: const EdgeInsets.all(16), children: [
    Text('Things to Avoid', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    TextField(controller: _avoidCtrl, maxLines: 5, style: GoogleFonts.inter(color: Colors.white),
        decoration: _inputDeco('One per line:\nDon\'t skip acclimatization\nAvoid street food at night...')),
    const SizedBox(height: 20),
    Text('Packing List', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    TextField(controller: _packingCtrl, maxLines: 5, style: GoogleFonts.inter(color: Colors.white),
        decoration: _inputDeco('One per line:\nWarm jacket\nSunscreen\nFirst aid kit...')),
    const SizedBox(height: 20),
    Text('Tags', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    TextField(controller: _tagsCtrl, style: GoogleFonts.inter(color: Colors.white),
        decoration: _inputDeco('Comma-separated: budget, roadtrip, mountains')),
  ]);

  Widget _buildReview() => ListView(padding: const EdgeInsets.all(16), children: [
    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A73E8), Color(0xFF4FC3F7)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        Text(_titleCtrl.text.isEmpty ? 'Your Trip' : _titleCtrl.text,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
        Text(_destCtrl.text, style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$_duration days', style: GoogleFonts.inter(color: Colors.white60, fontSize: 13)),
          Text(' • ', style: GoogleFonts.inter(color: Colors.white38)),
          Text('₹${_totalCost.toStringAsFixed(0)}', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          Text(' • ', style: GoogleFonts.inter(color: Colors.white38)),
          Text(_tripType, style: GoogleFonts.inter(color: Colors.white60, fontSize: 13)),
        ]),
      ]),
    ),
    const SizedBox(height: 16),
    _reviewRow('Days detailed', '${_days.where((d) => d['places']!.text.isNotEmpty).length}/$_duration'),
    _reviewRow('Cost breakdown', '₹${_totalCost.toStringAsFixed(0)}'),
    _reviewRow('Hotels added', '${_hotels.length}'),
    _reviewRow('Road info', '${_roads.length}'),
    _reviewRow('Avoid items', '${_avoidCtrl.text.trim().split('\n').where((s) => s.trim().isNotEmpty).length}'),
    _reviewRow('Packing items', '${_packingCtrl.text.trim().split('\n').where((s) => s.trim().isNotEmpty).length}'),
    _reviewRow('Rating', '${_rating.toStringAsFixed(1)} ⭐'),
    _reviewRow('Best season', _bestSeason),
  ]);

  Widget _reviewRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
      const Spacer(),
      Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _field(TextEditingController ctrl, String label, String hint) => TextField(
    controller: ctrl, style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
    decoration: InputDecoration(labelText: label, labelStyle: GoogleFonts.inter(color: Colors.white38),
        hintText: hint, hintStyle: GoogleFonts.inter(color: Colors.white16),
        filled: true, fillColor: const Color(0xFF161B22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
  );

  Widget _miniField(TextEditingController ctrl, String hint, {bool isNumber = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: TextField(controller: ctrl, style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
        keyboardType: isNumber ? TextInputType.number : null,
        decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.inter(color: Colors.white16, fontSize: 12),
            filled: true, fillColor: Colors.white.withOpacity(0.04), isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint, hintStyle: GoogleFonts.inter(color: Colors.white16, fontSize: 12),
    filled: true, fillColor: const Color(0xFF161B22),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
  );
}
