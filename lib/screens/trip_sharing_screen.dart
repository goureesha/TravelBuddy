import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/notification_bell.dart';
import '../services/trip_plan_service.dart';

class TripSharingScreen extends StatefulWidget {
  const TripSharingScreen({super.key});

  @override
  State<TripSharingScreen> createState() => _TripSharingScreenState();
}

class _TripSharingScreenState extends State<TripSharingScreen> {

  Future<void> _shareTrip(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final tripName = data['name'] as String? ?? 'Trip';

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF00BFA5))),
    );

    final code = await TripPlanService.sharePlan(null, doc.id);
    if (!mounted) return;
    Navigator.pop(context); // dismiss loading

    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share trip', style: GoogleFonts.inter())),
      );
      return;
    }

    _showShareDialog(tripName, code, data);
  }

  void _showShareDialog(String tripName, String code, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.share_rounded, color: Color(0xFF00BFA5), size: 22),
          const SizedBox(width: 8),
          Text('Trip Shared!', style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
        ]),
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
                  Text(code, style: GoogleFonts.inter(
                      color: const Color(0xFF00BFA5), fontSize: 24,
                      fontWeight: FontWeight.w900, letterSpacing: 3)),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Code copied!', style: GoogleFonts.inter())),
                      );
                    },
                    child: const Icon(Icons.copy_rounded, color: Color(0xFF00BFA5), size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Share via WhatsApp button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                label: Text('Share via WhatsApp', style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  final text = TripPlanService.getShareText(data, code);
                  SharePlus.instance.share(ShareParams(text: text));
                },
              ),
            ),
            const SizedBox(height: 8),
            Text('They can enter this code to view your trip plan.',
                style: GoogleFonts.inter(color: Colors.white30, fontSize: 11),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
      final tripData = await TripPlanService.loadSharedPlan(code);
      if (tripData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Trip not found — check the code', style: GoogleFonts.inter())),
          );
        }
        return;
      }

      if (!mounted) return;

      final tripName = tripData['name'] as String? ?? 'Trip';
      final waypoints = (tripData['waypoints'] as List? ?? [])
          .map((w) => Map<String, dynamic>.from(w as Map))
          .toList();
      final dist = (tripData['routeDistanceKm'] as num?)?.toStringAsFixed(1) ?? '0';
      final dur = (tripData['routeDurationMin'] as num?)?.toDouble() ?? 0;
      final durText = dur < 60
          ? '${dur.toStringAsFixed(0)} min'
          : '${(dur / 60).toStringAsFixed(1)} hr';
      final isRound = tripData['isRoundTrip'] == true;
      final stops = tripData['stops'] as List? ?? [];

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
                Row(children: [
                  const Icon(Icons.route_rounded, color: Color(0xFF1A73E8), size: 22),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tripName, style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
                const SizedBox(height: 12),
                // Route summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1A73E8), Color(0xFF00BFA5)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _infoChip(Icons.place, '${waypoints.length} pts'),
                    Container(width: 1, height: 24, color: Colors.white24),
                    _infoChip(Icons.straighten, '$dist km'),
                    Container(width: 1, height: 24, color: Colors.white24),
                    _infoChip(Icons.timer, durText),
                    if (isRound) ...[
                      Container(width: 1, height: 24, color: Colors.white24),
                      _infoChip(Icons.loop, 'Round'),
                    ],
                  ]),
                ),
                const SizedBox(height: 14),
                // Waypoints list
                if (waypoints.isNotEmpty) ...[
                  Text('Route', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...waypoints.take(10).map((w) {
                    final type = w['type'] as String? ?? 'stop';
                    final icon = type == 'start' ? Icons.trip_origin : type == 'end' ? Icons.flag_circle : Icons.circle;
                    final color = type == 'start' ? const Color(0xFF4CAF50) : type == 'end' ? Colors.redAccent : const Color(0xFFFF9800);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Icon(icon, color: color, size: 14),
                        const SizedBox(width: 10),
                        Expanded(child: Text(w['name'] as String? ?? 'Point',
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13))),
                      ]),
                    );
                  }),
                ],
                if (stops.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('${stops.length} activity stops logged',
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                // Clone to my trips button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    label: Text('Add to My Trips', style: GoogleFonts.inter(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final newId = await TripPlanService.cloneSharedPlan(tripData);
                      if (newId != null && ctx.mounted) {
                        Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Trip "$tripName" added to your plans! ✓', style: GoogleFonts.inter()),
                            backgroundColor: const Color(0xFF00BFA5),
                          ));
                        }
                      }
                    },
                  ),
                ),
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

  Widget _infoChip(IconData icon, String text) {
    return Column(children: [
      Icon(icon, color: Colors.white70, size: 16),
      const SizedBox(height: 2),
      Text(text, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
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
              child: Text('Your Trip Plans', style: GoogleFonts.inter(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: TripPlanService.getPlans(null),
              builder: (context, snapshot) {
                final trips = snapshot.data?.docs ?? [];

                if (trips.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.route_rounded, size: 48, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 12),
                        Text('No trip plans to share', style: GoogleFonts.inter(color: Colors.white38, fontSize: 14)),
                        Text('Plan a route on the map first', style: GoogleFonts.inter(color: Colors.white24, fontSize: 12)),
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
                    final name = data['name'] as String? ?? 'Trip';
                    final dist = (data['routeDistanceKm'] as num?)?.toStringAsFixed(1) ?? '0';
                    final waypoints = data['waypoints'] as List? ?? [];
                    final shareCode = data['shareCode'] as String?;

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
                              color: const Color(0xFF1A73E8).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.route_rounded, color: Color(0xFF1A73E8), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                Row(children: [
                                  Text('${waypoints.length} pts · $dist km',
                                      style: GoogleFonts.inter(color: Colors.white30, fontSize: 11)),
                                  if (shareCode != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00BFA5).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(shareCode, style: GoogleFonts.inter(
                                          color: const Color(0xFF00BFA5), fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ]),
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
