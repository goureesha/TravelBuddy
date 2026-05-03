import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../widgets/notification_bell.dart';

class RouteOptimizerScreen extends StatefulWidget {
  const RouteOptimizerScreen({super.key});

  @override
  State<RouteOptimizerScreen> createState() => _RouteOptimizerScreenState();
}

class _RouteOptimizerScreenState extends State<RouteOptimizerScreen> {
  final List<_Stop> _stops = [];
  List<_Stop>? _optimizedRoute;
  double? _totalDistance;
  double? _totalDuration;
  bool _optimizing = false;

  final _searchCtrl = TextEditingController();
  List<_SearchResult> _searchResults = [];
  bool _searching = false;

  Future<void> _searchPlace(String query) async {
    if (query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&countrycodes=in',
      );
      final resp = await http.get(url, headers: {'User-Agent': 'TravelBuddy/1.0'});
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        setState(() {
          _searchResults = list.map((e) => _SearchResult(
            name: e['display_name'] as String? ?? '',
            lat: double.tryParse(e['lat'] ?? '') ?? 0,
            lon: double.tryParse(e['lon'] ?? '') ?? 0,
          )).toList();
        });
      }
    } catch (_) {}
    setState(() => _searching = false);
  }

  void _addStop(_SearchResult result) {
    setState(() {
      _stops.add(_Stop(
        name: result.name.split(',').first,
        fullName: result.name,
        lat: result.lat,
        lon: result.lon,
      ));
      _searchResults = [];
      _searchCtrl.clear();
      _optimizedRoute = null;
    });
  }

  void _removeStop(int index) {
    setState(() {
      _stops.removeAt(index);
      _optimizedRoute = null;
    });
  }

  Future<void> _optimizeRoute() async {
    if (_stops.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add at least 3 stops to optimize', style: GoogleFonts.inter())),
      );
      return;
    }

    setState(() => _optimizing = true);

    try {
      // Build OSRM trip URL (free, no API key)
      final coords = _stops.map((s) => '${s.lon},${s.lat}').join(';');
      final url = Uri.parse(
        'https://router.project-osrm.org/trip/v1/driving/$coords?overview=false&source=first&roundtrip=false',
      );

      final resp = await http.get(url).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        if (json['code'] == 'Ok') {
          final waypoints = json['waypoints'] as List;
          final trips = json['trips'] as List;

          // Get optimized order
          final optimizedIndices = waypoints.map<int>((w) => w['waypoint_index'] as int).toList();

          // Reorder stops
          final reordered = <_Stop>[];
          for (final idx in optimizedIndices) {
            if (idx < _stops.length) reordered.add(_stops[idx]);
          }

          final trip = trips.isNotEmpty ? trips[0] : null;
          final distance = (trip?['distance'] as num?)?.toDouble() ?? 0;
          final duration = (trip?['duration'] as num?)?.toDouble() ?? 0;

          setState(() {
            _optimizedRoute = reordered;
            _totalDistance = distance / 1000; // meters to km
            _totalDuration = duration / 60; // seconds to minutes
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Optimization failed — check internet', style: GoogleFonts.inter())),
        );
      }
    }

    setState(() => _optimizing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Route Optimizer', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Search box
          TextField(
            controller: _searchCtrl,
            style: GoogleFonts.inter(color: Colors.white),
            onChanged: _searchPlace,
            decoration: InputDecoration(
              hintText: 'Search for a place to add...',
              hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 14),
              filled: true,
              fillColor: const Color(0xFF161B22),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white24),
              suffixIcon: _searching
                  ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),

          // Search results
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2128),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: _searchResults.map((r) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_rounded, color: Color(0xFF1A73E8), size: 18),
                  title: Text(r.name, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => _addStop(r),
                )).toList(),
              ),
            ),

          const SizedBox(height: 20),

          // Stops list
          Text('Your Stops (${_stops.length})',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          if (_stops.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.add_location_alt_rounded, size: 40, color: Colors.white.withOpacity(0.1)),
                    const SizedBox(height: 8),
                    Text('Add stops to plan your route', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
                  ],
                ),
              ),
            ),

          ...List.generate(_stops.length, (i) {
            final stop = _stops[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('${i + 1}', style: GoogleFonts.inter(color: const Color(0xFF1A73E8), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(stop.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white24, size: 18),
                    onPressed: () => _removeStop(i),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            );
          }),

          if (_stops.length >= 3) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _optimizing ? null : _optimizeRoute,
                icon: _optimizing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.route_rounded, color: Colors.white),
                label: Text(_optimizing ? 'Optimizing...' : 'Optimize Route',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],

          // Optimized result
          if (_optimizedRoute != null) ...[
            const SizedBox(height: 24),
            // Summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00BFA5), Color(0xFF1DE9B6)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.straighten_rounded, color: Colors.white70, size: 20),
                      const SizedBox(height: 4),
                      Text('${_totalDistance?.toStringAsFixed(0) ?? '0'} km',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      Text('Distance', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                  Container(width: 1, height: 40, color: Colors.white24),
                  Column(
                    children: [
                      const Icon(Icons.schedule_rounded, color: Colors.white70, size: 20),
                      const SizedBox(height: 4),
                      Text(_formatDuration(_totalDuration ?? 0),
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      Text('Drive Time', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Optimized Order', style: GoogleFonts.inter(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...List.generate(_optimizedRoute!.length, (i) {
              final stop = _optimizedRoute![i];
              final isFirst = i == 0;
              final isLast = i == _optimizedRoute!.length - 1;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: isFirst ? const Color(0xFF00BFA5) : isLast ? const Color(0xFFE53935) : const Color(0xFF1A73E8),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('${i + 1}', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (!isLast)
                        Container(width: 2, height: 30, color: Colors.white.withOpacity(0.1)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stop.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                          Text(isFirst ? 'Start' : isLast ? 'End' : 'Waypoint',
                              style: GoogleFonts.inter(color: Colors.white30, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  String _formatDuration(double minutes) {
    if (minutes < 60) return '${minutes.toStringAsFixed(0)} min';
    final h = (minutes / 60).floor();
    final m = (minutes % 60).toStringAsFixed(0);
    return '${h}h ${m}m';
  }
}

class _Stop {
  final String name;
  final String fullName;
  final double lat;
  final double lon;
  _Stop({required this.name, required this.fullName, required this.lat, required this.lon});
}

class _SearchResult {
  final String name;
  final double lat;
  final double lon;
  _SearchResult({required this.name, required this.lat, required this.lon});
}
