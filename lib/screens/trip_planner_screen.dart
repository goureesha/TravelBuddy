import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../widgets/notification_bell.dart';

class TripPlannerScreen extends StatefulWidget {
  const TripPlannerScreen({super.key});

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  static final _firestore = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference get _tripsRef =>
      _firestore.collection('users').doc(_uid).collection('planned_trips');

  void _showCreateTrip() {
    final nameCtrl = TextEditingController();
    final destCtrl = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1C2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Plan a Trip', style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Trip Name',
                  labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: destCtrl,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Destination',
                  labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setDialogState(() => startDate = picked);
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 14),
                      label: Text(
                        startDate != null ? DateFormat('dd MMM').format(startDate!) : 'Start',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: startDate ?? DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setDialogState(() => endDate = picked);
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 14),
                      label: Text(
                        endDate != null ? DateFormat('dd MMM').format(endDate!) : 'End',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await _tripsRef.add({
                  'name': nameCtrl.text.trim(),
                  'destination': destCtrl.text.trim(),
                  'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
                  'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Create', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Trip Planner', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _tripsRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snapshot.data?.docs ?? [];

          if (trips.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_rounded, size: 64, color: Colors.white.withOpacity(0.12)),
                  const SizedBox(height: 12),
                  Text('No trips planned', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Plan your next adventure!', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final doc = trips[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] as String? ?? '';
              final dest = data['destination'] as String? ?? '';
              final startTs = data['startDate'] as Timestamp?;
              final endTs = data['endDate'] as Timestamp?;

              String dateRange = '';
              if (startTs != null && endTs != null) {
                dateRange = '${DateFormat('dd MMM').format(startTs.toDate())} - ${DateFormat('dd MMM').format(endTs.toDate())}';
                final days = endTs.toDate().difference(startTs.toDate()).inDays;
                dateRange += ' ($days days)';
              }

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                ),
                onDismissed: (_) => _tripsRef.doc(doc.id).delete(),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A73E8).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.flight_takeoff_rounded, color: Color(0xFF1A73E8), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                                if (dest.isNotEmpty)
                                  Text(dest, style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (dateRange.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.date_range_rounded, size: 14, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(width: 6),
                            Text(dateRange, style: GoogleFonts.inter(color: Colors.white30, fontSize: 12)),
                          ],
                        ),
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
        onPressed: _showCreateTrip,
        backgroundColor: const Color(0xFF00BFA5),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Plan Trip', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
