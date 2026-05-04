import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Fetches nearby points of interest using multiple data sources:
/// 1. Overpass API (OpenStreetMap) — expanded tags for better coverage
/// 2. Geoapify Places API (free tier, 3000 req/day) — enriched data
class NearbyService {
  // Free Geoapify key (3000 requests/day, no billing needed)
  // Get yours at: https://myprojects.geoapify.com/register
  static const String _geoapifyKey = '65224d8c178e496bb922f133761718b7';

  // Category definitions with MULTIPLE OSM tags for broader results
  static const Map<String, Map<String, dynamic>> categories = {
    'fuel':       {'label': 'Petrol Pumps', 'emoji': '⛽',
      'tags': ['amenity=fuel', 'shop=fuel', 'industrial=fuel_depot'],
      'geoapify': 'service.vehicle.fuel'},
    'garage':     {'label': 'Garages',      'emoji': '🔧',
      'tags': ['shop=car_repair', 'shop=motorcycle_repair', 'craft=mechanic', 'amenity=vehicle_inspection'],
      'geoapify': 'service.vehicle.repair,service.vehicle.car_repair'},
    'hospital':   {'label': 'Hospitals',    'emoji': '🏥',
      'tags': ['amenity=hospital', 'amenity=clinic', 'amenity=doctors', 'healthcare=hospital'],
      'geoapify': 'healthcare.hospital,healthcare.clinic'},
    'pharmacy':   {'label': 'Medical Shops','emoji': '💊',
      'tags': ['amenity=pharmacy', 'shop=chemist', 'healthcare=pharmacy'],
      'geoapify': 'healthcare.pharmacy'},
    'toll':       {'label': 'Tolls',        'emoji': '🛣️',
      'tags': ['barrier=toll_booth', 'highway=toll_gantry'],
      'geoapify': 'access.toll'},
    'hotel':      {'label': 'Hotels',       'emoji': '🏨',
      'tags': ['tourism=hotel', 'tourism=guest_house', 'tourism=motel', 'tourism=hostel', 'building=hotel'],
      'geoapify': 'accommodation.hotel,accommodation.motel,accommodation.guest_house'},
    'restaurant': {'label': 'Restaurants',  'emoji': '🍽️',
      'tags': ['amenity=restaurant', 'amenity=fast_food', 'amenity=cafe', 'amenity=food_court', 'shop=bakery'],
      'geoapify': 'catering.restaurant,catering.fast_food,catering.cafe'},
    'atm':        {'label': 'ATMs / Banks', 'emoji': '🏧',
      'tags': ['amenity=atm', 'amenity=bank'],
      'geoapify': 'service.financial.atm,service.financial.bank'},
    'police':     {'label': 'Police',       'emoji': '🚔',
      'tags': ['amenity=police'],
      'geoapify': 'service.police'},
    'parking':    {'label': 'Parking',      'emoji': '🅿️',
      'tags': ['amenity=parking', 'amenity=parking_space'],
      'geoapify': 'parking'},
  };

  /// Fetch nearby places — tries Geoapify first (if key set), falls back to Overpass
  static Future<List<NearbyPlace>> fetch({
    required LatLng center,
    required String categoryKey,
    int radiusMeters = 10000,
  }) async {
    final cat = categories[categoryKey];
    if (cat == null) return [];

    // Try Geoapify first (better data)
    if (_geoapifyKey.isNotEmpty) {
      final geoapifyResults = await _fetchGeoapify(center, categoryKey, cat, radiusMeters);
      if (geoapifyResults.isNotEmpty) return geoapifyResults;
    }

    // Fall back to Overpass (OSM) with expanded tags
    return _fetchOverpass(center, categoryKey, cat, radiusMeters);
  }

  /// Fetch from Geoapify Places API (richer data, better India coverage)
  static Future<List<NearbyPlace>> _fetchGeoapify(
    LatLng center, String categoryKey, Map<String, dynamic> cat, int radius,
  ) async {
    try {
      final categories = cat['geoapify'] as String? ?? '';
      final url = Uri.parse(
        'https://api.geoapify.com/v2/places'
        '?categories=$categories'
        '&filter=circle:${center.longitude},${center.latitude},$radius'
        '&limit=50'
        '&apiKey=$_geoapifyKey',
      );
      final resp = await http.get(url, headers: {'Accept': 'application/json'});

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final features = data['features'] as List? ?? [];

        return features.map<NearbyPlace>((f) {
          final props = f['properties'] as Map<String, dynamic>? ?? {};
          final coords = f['geometry']?['coordinates'] as List? ?? [0, 0];
          return NearbyPlace(
            name: props['name']?.toString() ?? props['address_line1']?.toString() ?? cat['label'],
            lat: (coords[1] as num).toDouble(),
            lng: (coords[0] as num).toDouble(),
            category: categoryKey,
            emoji: cat['emoji'] ?? '📍',
            phone: props['contact']?['phone']?.toString(),
            website: props['website']?.toString(),
            openingHours: props['opening_hours']?.toString(),
            address: props['formatted']?.toString(),
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Fetch from Overpass API with expanded multi-tag queries
  static Future<List<NearbyPlace>> _fetchOverpass(
    LatLng center, String categoryKey, Map<String, dynamic> cat, int radius,
  ) async {
    final tags = cat['tags'] as List<String>? ?? [];
    if (tags.isEmpty) return [];

    // Build multi-tag Overpass query for broader results
    final queryParts = StringBuffer();
    for (final tag in tags) {
      final parts = tag.split('=');
      final key = parts[0];
      final value = parts[1];
      queryParts.writeln('  node["$key"="$value"](around:$radius,${center.latitude},${center.longitude});');
      queryParts.writeln('  way["$key"="$value"](around:$radius,${center.latitude},${center.longitude});');
    }

    final query = '''
[out:json][timeout:15];
(
$queryParts);
out center body 50;
''';

    try {
      final url = Uri.parse('https://overpass-api.de/api/interpreter');
      final resp = await http.post(url, body: {'data': query});

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final elements = data['elements'] as List? ?? [];

        // Deduplicate by name + approximate location
        final seen = <String>{};
        final results = <NearbyPlace>[];

        for (final e in elements) {
          double lat, lng;
          if (e['type'] == 'way' && e['center'] != null) {
            lat = (e['center']['lat'] as num).toDouble();
            lng = (e['center']['lon'] as num).toDouble();
          } else {
            lat = (e['lat'] as num?)?.toDouble() ?? 0;
            lng = (e['lon'] as num?)?.toDouble() ?? 0;
          }
          if (lat == 0 && lng == 0) continue;

          final osmTags = e['tags'] as Map<String, dynamic>? ?? {};
          final name = osmTags['name']?.toString() ?? cat['label'] ?? categoryKey;
          final dedupeKey = '${name}_${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';
          if (seen.contains(dedupeKey)) continue;
          seen.add(dedupeKey);

          results.add(NearbyPlace(
            name: name,
            lat: lat,
            lng: lng,
            category: categoryKey,
            emoji: cat['emoji'] ?? '📍',
            phone: osmTags['phone']?.toString() ?? osmTags['contact:phone']?.toString(),
            website: osmTags['website']?.toString() ?? osmTags['contact:website']?.toString(),
            openingHours: osmTags['opening_hours']?.toString(),
            address: osmTags['addr:full']?.toString() ??
              [osmTags['addr:street'], osmTags['addr:city']].where((s) => s != null).join(', '),
          ));
        }
        return results;
      }
    } catch (_) {}
    return [];
  }
}

class NearbyPlace {
  final String name;
  final double lat;
  final double lng;
  final String category;
  final String emoji;
  final String? phone;
  final String? website;
  final String? openingHours;
  final String? address;

  const NearbyPlace({
    required this.name,
    required this.lat,
    required this.lng,
    required this.category,
    required this.emoji,
    this.phone,
    this.website,
    this.openingHours,
    this.address,
  });

  LatLng get latLng => LatLng(lat, lng);
}
