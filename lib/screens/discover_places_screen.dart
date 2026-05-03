import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../widgets/notification_bell.dart';

class DiscoverPlacesScreen extends StatefulWidget {
  const DiscoverPlacesScreen({super.key});
  @override
  State<DiscoverPlacesScreen> createState() => _DiscoverPlacesScreenState();
}

class _DiscoverPlacesScreenState extends State<DiscoverPlacesScreen> {
  String _selectedCategory = 'restaurant';
  bool _loading = false;
  List<_Place> _places = [];
  String? _error;

  static final _categories = {
    'restaurant': _Cat('Restaurants', Icons.restaurant_rounded, Color(0xFFE53935)),
    'fuel': _Cat('Fuel Stations', Icons.local_gas_station_rounded, Color(0xFFFF6D00)),
    'hospital': _Cat('Hospitals', Icons.local_hospital_rounded, Color(0xFF1E88E5)),
    'atm': _Cat('ATMs', Icons.atm_rounded, Color(0xFF43A047)),
    'hotel': _Cat('Hotels', Icons.hotel_rounded, Color(0xFF8E24AA)),
    'parking': _Cat('Parking', Icons.local_parking_rounded, Color(0xFF00ACC1)),
    'tourism': _Cat('Attractions', Icons.photo_camera_rounded, Color(0xFFFFB300)),
    'pharmacy': _Cat('Pharmacies', Icons.local_pharmacy_rounded, Color(0xFF00897B)),
  };

  @override
  void initState() {
    super.initState();
    _fetchNearby();
  }

  Future<void> _fetchNearby() async {
    setState(() { _loading = true; _error = null; });

    try {
      final pos = await _getPosition();
      final lat = pos.latitude;
      final lon = pos.longitude;

      // Build Overpass API query
      String amenity = _selectedCategory;
      String tag = 'amenity';
      if (_selectedCategory == 'fuel') amenity = 'fuel';
      if (_selectedCategory == 'tourism') { tag = 'tourism'; amenity = 'attraction|museum|viewpoint'; }
      if (_selectedCategory == 'parking') amenity = 'parking';

      final query = '''
[out:json][timeout:10];
node[$tag~"$amenity"](around:5000,$lat,$lon);
out body 20;
''';

      final resp = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: {'data': query},
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final elements = json['elements'] as List? ?? [];
        final places = <_Place>[];

        for (final el in elements) {
          final tags = el['tags'] as Map<String, dynamic>? ?? {};
          final name = tags['name'] as String?;
          if (name == null || name.isEmpty) continue;

          final pLat = (el['lat'] as num?)?.toDouble() ?? 0;
          final pLon = (el['lon'] as num?)?.toDouble() ?? 0;
          final dist = Geolocator.distanceBetween(lat, lon, pLat, pLon);

          places.add(_Place(
            name: name,
            lat: pLat,
            lon: pLon,
            distance: dist,
            address: tags['addr:street'] as String? ?? '',
            phone: tags['phone'] as String? ?? '',
            cuisine: tags['cuisine'] as String? ?? '',
          ));
        }

        places.sort((a, b) => a.distance.compareTo(b.distance));
        setState(() => _places = places);
      }
    } catch (e) {
      setState(() => _error = 'Could not load places. Check location & internet.');
    }

    setState(() => _loading = false);
  }

  Future<Position> _getPosition() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('Location disabled');

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) throw Exception('Permission denied');
    }
    if (perm == LocationPermission.deniedForever) throw Exception('Permission denied forever');

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium)
        .timeout(const Duration(seconds: 10));
  }

  String _formatDist(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    final cat = _categories[_selectedCategory]!;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Discover', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: Column(
        children: [
          // Category chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _categories.entries.map((e) {
                final sel = e.key == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(e.value.icon, size: 16, color: sel ? Colors.white : e.value.color),
                    label: Text(e.value.label, style: GoogleFonts.inter(fontSize: 11,
                        color: sel ? Colors.white : Colors.white54, fontWeight: FontWeight.w600)),
                    selected: sel,
                    selectedColor: e.value.color,
                    backgroundColor: const Color(0xFF161B22),
                    side: BorderSide(color: sel ? e.value.color : Colors.white.withOpacity(0.08)),
                    onSelected: (_) {
                      setState(() => _selectedCategory = e.key);
                      _fetchNearby();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.location_off_rounded, size: 48, color: Colors.white.withOpacity(0.12)),
                          const SizedBox(height: 12),
                          Text(_error!, style: GoogleFonts.inter(color: Colors.white38, fontSize: 13), textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _fetchNearby, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8)),
                              child: Text('Retry', style: GoogleFonts.inter(color: Colors.white))),
                        ]),
                      ))
                    : _places.isEmpty
                        ? Center(child: Text('No ${cat.label.toLowerCase()} found nearby',
                            style: GoogleFonts.inter(color: Colors.white38, fontSize: 14)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _places.length,
                            itemBuilder: (context, i) {
                              final p = _places[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161B22),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: cat.color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(cat.icon, color: cat.color, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                      if (p.cuisine.isNotEmpty)
                                        Text(p.cuisine, style: GoogleFonts.inter(color: Colors.white30, fontSize: 11)),
                                      if (p.address.isNotEmpty)
                                        Text(p.address, style: GoogleFonts.inter(color: Colors.white24, fontSize: 11)),
                                    ],
                                  )),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A73E8).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(_formatDist(p.distance),
                                        style: GoogleFonts.inter(color: const Color(0xFF1A73E8), fontSize: 11, fontWeight: FontWeight.w700)),
                                  ),
                                ]),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _Cat {
  final String label;
  final IconData icon;
  final Color color;
  const _Cat(this.label, this.icon, this.color);
}

class _Place {
  final String name;
  final double lat, lon, distance;
  final String address, phone, cuisine;
  _Place({required this.name, required this.lat, required this.lon, required this.distance,
      required this.address, required this.phone, required this.cuisine});
}
