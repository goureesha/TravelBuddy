import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/notification_bell.dart';

class TripSharingScreen extends StatefulWidget {
  const TripSharingScreen({super.key});

  @override
  State<TripSharingScreen> createState() => _TripSharingScreenState();
}

class _TripSharingScreenState extends State<TripSharingScreen> {
  static final _firestore = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  String get _userName => FirebaseAuth.instance.currentUser?.displayName ?? 'A traveler';

  CollectionReference get _tripsRef =>
      _firestore.collection('users').doc(_uid).collection('planned_trips');

  CollectionReference get _sharedRef =>
      _firestore.collection('shared_trips');

  Future<void> _shareTrip(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final tripName = data['name'] as String? ?? 'Trip';

    // Create a shared trip document with a unique code
    final shareDoc = await _sharedRef.add({
      'originalId': doc.id,
      'ownerId': _uid,
      'ownerName': _userName,
      'tripName': tripName,
      'tripData': data,
      'sharedAt': FieldValue.serverTimestamp(),
      'views': 0,
    });

    final shareCode = shareDoc.id.substring(0, 8).toUpperCase();
    await shareDoc.update({'shareCode': shareCode});

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.share_rounded, color: Color(0xFF00BFA5), size: 22),
            const SizedBox(width: 8),
            Text('Trip Shared!', style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share this code with friends:', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00BFA5).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(shareCode, style: GoogleFonts.inter(
                    color: const Color(0xFF00BFA5), fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 3)),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: shareCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Code copied!', style: GoogleFonts.inter())),
                      );
                    },
                    child: const Icon(Icons.copy_rounded, color: Color(0xFF00BFA5), size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('They can enter this code to view your trip plan.',
                style: GoogleFonts.inter(color: Colors.white30, fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx),
            child: Text('Done', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _viewSharedTrip() async {
    final codeCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Enter Share Code', style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
        content: TextField(
          controller: codeCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 20, letterSpacing: 3, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          maxLength: 8,
          decoration: InputDecoration(
            hintText: 'ABCD1234',
            hintStyle: GoogleFonts.inter(color: Colors.white12, fontSize: 20, letterSpacing: 3),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            counterStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 10),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              final code = codeCtrl.text.trim().toUpperCase();
              if (code.isEmpty) return;
              Navigator.pop(ctx);
              _loadSharedTrip(code);
            },
            child: Text('View Trip', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSharedTrip(String code) async {
    try {
      final query = await _sharedRef.where('shareCode', isEqualTo: code).limit(1).get();
      if (query.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Trip not found — check the code', style: GoogleFonts.inter())),
          );
        }
        return;
      }

      final doc = query.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      await doc.reference.update({'views': FieldValue.increment(1)});

      if (!mounted) return;

      final tripData = data['tripData'] as Map<String, dynamic>? ?? {};
      final ownerName = data['ownerName'] as String? ?? 'Someone';
      final tripName = data['tripName'] as String? ?? 'Trip';
      final itinerary = (tripData['itinerary'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: const Color(0xFF1C2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flight_takeoff_rounded, color: Color(0xFF1A73E8), size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tripName, style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text('Shared by $ownerName', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                if (tripData['startDate'] != null) ...[
                  const SizedBox(height: 4),
                  Text('${tripData['startDate']} → ${tripData['endDate'] ?? ''}',
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                if (itinerary.isNotEmpty) ...[
                  Text('Itinerary', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...itinerary.take(10).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF1A73E8), shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(item['activity'] as String? ?? '',
                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                        ),
                      ],
                    ),
                  )),
                ] else
                  Text('No itinerary details', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trip', style: GoogleFonts.inter())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Trip Sharing', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_rounded),
            onPressed: _viewSharedTrip,
            tooltip: 'Enter share code',
          ),
          const NotificationBell(),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Enter code card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: GestureDetector(
              onTap: _viewSharedTrip,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1A73E8).withOpacity(0.15), const Color(0xFF4FC3F7).withOpacity(0.08)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1A73E8).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A73E8).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.vpn_key_rounded, color: Color(0xFF1A73E8), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Have a share code?', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          Text('Enter it to view a friend\'s trip', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
                  ],
                ),
              ),
            ),
          ),

          // My trips to share
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Your Trips', style: GoogleFonts.inter(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _tripsRef.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                final trips = snapshot.data?.docs ?? [];

                if (trips.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flight_rounded, size: 48, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 12),
                        Text('No trips to share', style: GoogleFonts.inter(color: Colors.white38, fontSize: 14)),
                        Text('Create trips in Trip Planner first', style: GoogleFonts.inter(color: Colors.white24, fontSize: 12)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    final doc = trips[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] as String? ?? 'Unnamed Trip';
                    final startDate = data['startDate'] as String? ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C4DFF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.flight_takeoff_rounded, color: Color(0xFF7C4DFF), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                if (startDate.isNotEmpty)
                                  Text(startDate, style: GoogleFonts.inter(color: Colors.white30, fontSize: 11)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _shareTrip(doc),
                            icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                            label: Text('Share', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00BFA5),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
