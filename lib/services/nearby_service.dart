import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Fetches nearby points of interest from OpenStreetMap via Overpass API.
class NearbyService {
  // Category definitions: key, label, emoji, OSM tags
  static const Map<String, Map<String, String>> categories = {
    'hospital':    {'label': 'Hospitals',     'emoji': '🏥', 'tag': 'amenity=hospital'},
    'hotel':       {'label': 'Hotels',        'emoji': '🏨', 'tag': 'tourism=hotel'},
    'fuel':        {'label': 'Petrol Pumps',  'emoji': '⛽', 'tag': 'amenity=fuel'},
    'restaurant':  {'label': 'Restaurants',   'emoji': '🍽️', 'tag': 'amenity=restaurant'},
    'atm':         {'label': 'ATMs',          'emoji': '🏧', 'tag': 'amenity=atm'},
    'pharmacy':    {'label': 'Pharmacies',    'emoji': '💊', 'tag': 'amenity=pharmacy'},
    'police':      {'label': 'Police',        'emoji': '🚔', 'tag': 'amenity=police'},
    'parking':     {'label': 'Parking',       'emoji': '🅿️', 'tag': 'amenity=parking'},
  };

  /// Fetch nearby places for a category within [radiusMeters] of [center].
  static Future<List<NearbyPlace>> fetch({
    required LatLng center,
    required String categoryKey,
    int radiusMeters = 5000,
  }) async {
    final cat = categories[categoryKey];
    if (cat == null) return [];

    final tag = cat['tag']!;
    final parts = tag.split('=');
    final key = parts[0];
    final value = parts[1];

    final query = '''
[out:json][timeout:10];
(
  node["$key"="$value"](around:$radiusMeters,${center.latitude},${center.longitude});
  way["$key"="$value"](around:$radiusMeters,${center.latitude},${center.longitude});
);
out center body 30;
''';

    try {
      final url = Uri.parse('https://overpass-api.de/api/interpreter');
      final resp = await http.post(url, body: {'data': query});

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final elements = data['elements'] as List? ?? [];

        return elements.map<NearbyPlace>((e) {
          double lat, lng;
          if (e['type'] == 'way' && e['center'] != null) {
            lat = (e['center']['lat'] as num).toDouble();
            lng = (e['center']['lon'] as num).toDouble();
          } else {
            lat = (e['lat'] as num?)?.toDouble() ?? 0;
            lng = (e['lon'] as num?)?.toDouble() ?? 0;
          }

          final tags = e['tags'] as Map<String, dynamic>? ?? {};
          return NearbyPlace(
            name: tags['name']?.toString() ?? cat['label'] ?? categoryKey,
            lat: lat,
            lng: lng,
            category: categoryKey,
            emoji: cat['emoji'] ?? '📍',
            phone: tags['phone']?.toString(),
            website: tags['website']?.toString(),
            openingHours: tags['opening_hours']?.toString(),
          );
        }).toList();
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

  const NearbyPlace({
    required this.name,
    required this.lat,
    required this.lng,
    required this.category,
    required this.emoji,
    this.phone,
    this.website,
    this.openingHours,
  });

  LatLng get latLng => LatLng(lat, lng);
}
