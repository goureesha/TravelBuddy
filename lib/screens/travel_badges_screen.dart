import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/notification_bell.dart';

class TravelBadgesScreen extends StatefulWidget {
  const TravelBadgesScreen({super.key});

  @override
  State<TravelBadgesScreen> createState() => _TravelBadgesScreenState();
}

class _TravelBadgesScreenState extends State<TravelBadgesScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static final _allBadges = <_Badge>[
    _Badge(id: 'first_trip', name: 'First Trip', desc: 'Complete your first trip', icon: '🚗', requiredCount: 1, type: 'trips'),
    _Badge(id: 'road_warrior', name: 'Road Warrior', desc: 'Complete 5 trips', icon: '🛣️', requiredCount: 5, type: 'trips'),
    _Badge(id: 'veteran', name: 'Veteran Traveler', desc: 'Complete 10 trips', icon: '🏆', requiredCount: 10, type: 'trips'),
    _Badge(id: 'legend', name: 'Travel Legend', desc: 'Complete 25 trips', icon: '👑', requiredCount: 25, type: 'trips'),
    _Badge(id: 'first_team', name: 'Team Player', desc: 'Join your first team', icon: '👥', requiredCount: 1, type: 'teams'),
    _Badge(id: 'squad', name: 'Squad Leader', desc: 'Be in 3 teams', icon: '🎯', requiredCount: 3, type: 'teams'),
    _Badge(id: 'first_fuel', name: 'First Fill-up', desc: 'Log your first fuel entry', icon: '⛽', requiredCount: 1, type: 'fuel'),
    _Badge(id: 'fuel_tracker', name: 'Fuel Tracker', desc: 'Log 10 fuel entries', icon: '📊', requiredCount: 10, type: 'fuel'),
    _Badge(id: 'first_expense', name: 'First Expense', desc: 'Track your first cost', icon: '💰', requiredCount: 1, type: 'costs'),
    _Badge(id: 'big_spender', name: 'Big Spender', desc: 'Track 20 expenses', icon: '💎', requiredCount: 20, type: 'costs'),
    _Badge(id: 'first_plan', name: 'Trip Planner', desc: 'Create your first trip plan', icon: '✈️', requiredCount: 1, type: 'plans'),
    _Badge(id: 'explorer', name: 'Explorer', desc: 'Plan 5 trips', icon: '🗺️', requiredCount: 5, type: 'plans'),
    _Badge(id: 'km_100', name: '100km Club', desc: 'Travel 100 km total', icon: '📏', requiredCount: 100, type: 'km'),
    _Badge(id: 'km_500', name: '500km Club', desc: 'Travel 500 km total', icon: '🚀', requiredCount: 500, type: 'km'),
    _Badge(id: 'km_1000', name: '1000km Club', desc: 'Travel 1000 km total', icon: '🌍', requiredCount: 1000, type: 'km'),
    _Badge(id: 'first_doc', name: 'Prepared', desc: 'Save your first document', icon: '📋', requiredCount: 1, type: 'docs'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Travel Badges', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _loadCounts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final counts = snapshot.data!;
          final earned = _allBadges.where((b) => (counts[b.type] ?? 0) >= b.requiredCount).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6D00), Color(0xFFFF9100)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFF6D00).withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(child: Text('🏅', style: const TextStyle(fontSize: 28))),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$earned / ${_allBadges.length}',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                        Text('Badges Earned', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                    const Spacer(),
                    // Progress ring
                    SizedBox(
                      width: 48, height: 48,
                      child: Stack(
                        children: [
                          CircularProgressIndicator(
                            value: earned / _allBadges.length,
                            strokeWidth: 4,
                            backgroundColor: Colors.white.withOpacity(0.15),
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                          ),
                          Center(
                            child: Text('${((earned / _allBadges.length) * 100).toStringAsFixed(0)}%',
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Badge grid
              ...List.generate((_allBadges.length / 2).ceil(), (row) {
                final i1 = row * 2;
                final i2 = i1 + 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(child: _badgeCard(_allBadges[i1], counts)),
                      const SizedBox(width: 12),
                      if (i2 < _allBadges.length)
                        Expanded(child: _badgeCard(_allBadges[i2], counts))
                      else
                        const Expanded(child: SizedBox()),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _badgeCard(_Badge badge, Map<String, int> counts) {
    final current = counts[badge.type] ?? 0;
    final isEarned = current >= badge.requiredCount;
    final progress = (current / badge.requiredCount).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isEarned ? const Color(0xFF1C2128) : const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEarned ? const Color(0xFFFF6D00).withOpacity(0.3) : Colors.white.withOpacity(0.06),
        ),
        boxShadow: isEarned ? [
          BoxShadow(color: const Color(0xFFFF6D00).withOpacity(0.08), blurRadius: 8),
        ] : null,
      ),
      child: Column(
        children: [
          Text(badge.icon, style: TextStyle(fontSize: 32, color: isEarned ? null : Colors.white.withOpacity(0.3))),
          const SizedBox(height: 6),
          Text(badge.name,
              style: GoogleFonts.inter(
                color: isEarned ? Colors.white : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(badge.desc,
              style: GoogleFonts.inter(color: Colors.white24, fontSize: 10),
              textAlign: TextAlign.center, maxLines: 2),
          const SizedBox(height: 8),
          if (isEarned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6D00).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('EARNED', style: GoogleFonts.inter(color: const Color(0xFFFF6D00), fontSize: 9, fontWeight: FontWeight.bold)),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF7C4DFF)),
                minHeight: 4,
              ),
            ),
        ],
      ),
    );
  }

  Future<Map<String, int>> _loadCounts() async {
    final counts = <String, int>{};

    // Trips
    final trips = await FirebaseFirestore.instance
        .collection('users').doc(_uid).collection('trips')
        .get();
    counts['trips'] = trips.docs.length;

    // Teams
    final teams = await FirebaseFirestore.instance
        .collection('teams')
        .where('members', arrayContains: _uid)
        .get();
    counts['teams'] = teams.docs.length;

    // Fuel logs
    final fuel = await FirebaseFirestore.instance
        .collection('fuel_logs')
        .where('userId', isEqualTo: _uid)
        .get();
    counts['fuel'] = fuel.docs.length;

    // Trip costs
    final costs = await FirebaseFirestore.instance
        .collection('users').doc(_uid).collection('trip_costs')
        .get();
    counts['costs'] = costs.docs.length;

    // Planned trips
    final plans = await FirebaseFirestore.instance
        .collection('users').doc(_uid).collection('planned_trips')
        .get();
    counts['plans'] = plans.docs.length;

    // Total km
    double totalKm = 0;
    for (final doc in trips.docs) {
      final data = doc.data();
      totalKm += (data['totalKm'] as num?)?.toDouble() ?? 0;
    }
    counts['km'] = totalKm.toInt();

    // Documents
    final docs = await FirebaseFirestore.instance
        .collection('users').doc(_uid).collection('documents')
        .get();
    counts['docs'] = docs.docs.length;

    return counts;
  }
}

class _Badge {
  final String id;
  final String name;
  final String desc;
  final String icon;
  final int requiredCount;
  final String type;

  _Badge({
    required this.id,
    required this.name,
    required this.desc,
    required this.icon,
    required this.requiredCount,
    required this.type,
  });
}
