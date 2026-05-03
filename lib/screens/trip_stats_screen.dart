import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/notification_bell.dart';

class TripStatsScreen extends StatefulWidget {
  const TripStatsScreen({super.key});
  @override
  State<TripStatsScreen> createState() => _TripStatsScreenState();
}

class _TripStatsScreenState extends State<TripStatsScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  bool _loading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final root = FirebaseFirestore.instance.collection('users').doc(_uid);

    final trips = await root.collection('trips').get();
    final costs = await root.collection('trip_costs').get();
    final plans = await root.collection('planned_trips').get();
    final journal = await root.collection('journal_entries').get();
    final docs = await root.collection('documents').get();
    final mileage = await root.collection('mileage_logs').get();

    double totalKm = 0, totalFuel = 0, totalSpent = 0;
    int longestTrip = 0;

    for (final doc in trips.docs) {
      final d = doc.data();
      final km = (d['totalKm'] as num?)?.toDouble() ?? 0;
      totalKm += km;
      final dur = (d['durationMinutes'] as num?)?.toInt() ?? 0;
      if (dur > longestTrip) longestTrip = dur;
    }

    for (final doc in costs.docs) {
      totalSpent += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
    }

    for (final doc in mileage.docs) {
      totalFuel += (doc.data()['fuel'] as num?)?.toDouble() ?? 0;
    }

    double avgMileage = 0;
    if (mileage.docs.isNotEmpty) {
      double sum = 0;
      for (final doc in mileage.docs) {
        sum += (doc.data()['mileage'] as num?)?.toDouble() ?? 0;
      }
      avgMileage = sum / mileage.docs.length;
    }

    setState(() {
      _stats = {
        'totalTrips': trips.docs.length,
        'totalKm': totalKm,
        'totalFuel': totalFuel,
        'totalSpent': totalSpent,
        'longestTrip': longestTrip,
        'avgMileage': avgMileage,
        'plannedTrips': plans.docs.length,
        'journalEntries': journal.docs.length,
        'documents': docs.docs.length,
        'mileageLogs': mileage.docs.length,
      };
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Trip Stats', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Hero stat
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: const Color(0xFF7C4DFF).withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Column(children: [
                      Text('${(_stats['totalKm'] as double? ?? 0).toStringAsFixed(0)}', style: GoogleFonts.inter(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
                      Text('Total Kilometers', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text('across ${_stats['totalTrips']} trips', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  // Grid
                  Row(children: [
                    Expanded(child: _statCard('Trips', '${_stats['totalTrips']}', Icons.directions_car_rounded, const Color(0xFF1A73E8))),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('Fuel Used', '${(_stats['totalFuel'] as double? ?? 0).toStringAsFixed(1)}L', Icons.local_gas_station_rounded, const Color(0xFFFF6D00))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _statCard('Total Spent', '₹${(_stats['totalSpent'] as double? ?? 0).toStringAsFixed(0)}', Icons.currency_rupee_rounded, const Color(0xFFE53935))),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('Avg Mileage', '${(_stats['avgMileage'] as double? ?? 0).toStringAsFixed(1)} km/L', Icons.speed_rounded, const Color(0xFF00BFA5))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _statCard('Planned', '${_stats['plannedTrips']}', Icons.map_rounded, const Color(0xFF8E24AA))),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('Journal', '${_stats['journalEntries']}', Icons.auto_stories_rounded, const Color(0xFF7E57C2))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _statCard('Documents', '${_stats['documents']}', Icons.folder_rounded, const Color(0xFF00ACC1))),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('Longest Trip', '${(_stats['longestTrip'] as int? ?? 0)} min', Icons.timer_rounded, const Color(0xFFFFB300))),
                  ]),
                  const SizedBox(height: 20),
                  // Fun facts
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Fun Facts', style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      _funFact('🌍', 'Earth circumference progress', '${((_stats['totalKm'] as double? ?? 0) / 40075 * 100).toStringAsFixed(2)}%'),
                      _funFact('🚗', 'Avg trip distance', _stats['totalTrips'] > 0 ? '${((_stats['totalKm'] as double? ?? 0) / _stats['totalTrips']).toStringAsFixed(1)} km' : '0 km'),
                      _funFact('💰', 'Avg cost per trip', _stats['totalTrips'] > 0 ? '₹${((_stats['totalSpent'] as double? ?? 0) / _stats['totalTrips']).toStringAsFixed(0)}' : '₹0'),
                      _funFact('⛽', 'Cost per km', (_stats['totalKm'] as double? ?? 0) > 0 ? '₹${((_stats['totalSpent'] as double? ?? 0) / (_stats['totalKm'] as double)).toStringAsFixed(1)}' : '₹0'),
                    ]),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 10),
        Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
      ]),
    );
  }

  Widget _funFact(String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12))),
        Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
