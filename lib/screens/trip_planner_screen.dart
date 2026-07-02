import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/trip_plan_service.dart';
import '../widgets/notification_bell.dart';
import 'live_map_screen.dart';

class TripPlannerScreen extends StatefulWidget {
  const TripPlannerScreen({super.key});

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  /// Status → (color, icon)
  static const _statusConfig = {
    'planned': (Color(0xFF1A73E8), Icons.schedule_rounded),
    'active': (Color(0xFF00BFA5), Icons.directions_run_rounded),
    'completed': (Color(0xFF6B7280), Icons.check_circle_rounded),
  };

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'ACTIVE';
      case 'completed':
        return 'DONE';
      default:
        return 'PLANNED';
    }
  }

  String _formatDuration(double minutes) {
    if (minutes < 60) return '${minutes.toStringAsFixed(0)} min';
    return '${(minutes / 60).toStringAsFixed(1)} hr';
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
        stream: TripPlanService.getPlans(null),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final plans = snapshot.data?.docs ?? [];

          if (plans.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_rounded, size: 64, color: Colors.white.withOpacity(0.12)),
                  const SizedBox(height: 12),
                  Text('No trip plans yet', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Open the map to plan your first route!', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final doc = plans[index];
              final data = doc.data() as Map<String, dynamic>;

              final name = data['name'] as String? ?? 'Untitled';
              final status = data['status'] as String? ?? 'planned';
              final distKm = (data['routeDistanceKm'] as num?)?.toDouble() ?? 0;
              final durMin = (data['routeDurationMin'] as num?)?.toDouble() ?? 0;
              final waypoints = data['waypoints'] as List<dynamic>? ?? [];
              final isRoundTrip = data['isRoundTrip'] as bool? ?? false;
              final stops = data['stops'] as List<dynamic>? ?? [];

              final config = _statusConfig[status] ?? _statusConfig['planned']!;
              final statusColor = config.$1;
              final statusIcon = config.$2;

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1C2128),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text('Delete Plan', style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
                      content: Text(
                        'Delete "$name"? This cannot be undone.',
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('Delete', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (_) => TripPlanService.deletePlan(null, doc.id),
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Open the map and tap Load Trip to view this plan',
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                        backgroundColor: const Color(0xFF161B22),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveMapScreen()));
                  },
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
                        // ── Header: status badge + name ──
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, color: statusColor, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    _statusLabel(status),
                                    style: GoogleFonts.inter(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isRoundTrip) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6D00).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.loop_rounded, color: Color(0xFFFF6D00), size: 12),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Round Trip',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFFF6D00),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 10),

                        // ── Trip name ──
                        Text(
                          name,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 8),

                        // ── Route summary row ──
                        Row(
                          children: [
                            Icon(Icons.straighten_rounded, size: 14, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(width: 4),
                            Text(
                              '${distKm.toStringAsFixed(1)} km',
                              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.timer_outlined, size: 14, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(width: 4),
                            Text(
                              _formatDuration(durMin),
                              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.place_outlined, size: 14, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(width: 4),
                            Text(
                              '${waypoints.length} waypoints',
                              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),

                        // ── Stops count ──
                        if (stops.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.flag_rounded, size: 14, color: Colors.white.withOpacity(0.3)),
                              const SizedBox(width: 4),
                              Text(
                                '${stops.length} stop${stops.length == 1 ? '' : 's'} logged',
                                style: GoogleFonts.inter(color: Colors.white30, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveMapScreen()));
        },
        backgroundColor: const Color(0xFF00BFA5),
        icon: const Icon(Icons.map_rounded, color: Colors.white),
        label: Text('Plan on Map', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
