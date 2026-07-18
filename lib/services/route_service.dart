import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RouteService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;
  static String? get _name => _auth.currentUser?.displayName;

  /// Returns the routes collection — personal or team-scoped
  static CollectionReference _routesRef(String? teamId) {
    if (teamId != null) {
      return _firestore.collection('teams').doc(teamId).collection('routes');
    }
    return _firestore.collection('users').doc(_uid!).collection('routes');
  }

  /// Create a new route plan
  static Future<String?> createRoute({
    String? teamId,
    required String name,
    required Map<String, dynamic> startPoint,
    required Map<String, dynamic> endPoint,
    List<Map<String, dynamic>> stops = const [],
  }) async {
    if (_uid == null) return null;

    final docRef = await _routesRef(teamId).add({
      'name': name.trim(),
      'startPoint': startPoint,
      'endPoint': endPoint,
      'stops': stops,
      'isActive': true,
      'createdBy': _uid,
      'createdByName': _name ?? 'Unknown',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Get all routes
  static Stream<QuerySnapshot> getRoutes(String? teamId) {
    return _routesRef(teamId).snapshots();
  }

  /// Get active route
  static Stream<QuerySnapshot> getActiveRoute(String? teamId) {
    return _routesRef(teamId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots();
  }

  /// Update stops on a route
  static Future<void> updateStops(String? teamId, String routeId, List<Map<String, dynamic>> stops) async {
    await _routesRef(teamId).doc(routeId).update({'stops': stops});
  }

  /// Set active/inactive
  static Future<void> setActive(String? teamId, String routeId, bool isActive) async {
    await _routesRef(teamId).doc(routeId).update({'isActive': isActive});
  }

  /// Delete route
  static Future<void> deleteRoute(String? teamId, String routeId) async {
    await _routesRef(teamId).doc(routeId).delete();
  }

  /// Fetch directions from OSRM (free, no API key needed)
  /// Returns a list of LatLng points for the polyline
  static Future<List<LatLng>> getDirections(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return [];

    // Build OSRM coordinates string: lng,lat;lng,lat;...
    final coords = waypoints
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');

    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$coords'
      '?overview=full&geometries=geojson&steps=false',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          final coordinates = geometry['coordinates'] as List;
          return coordinates
              .map<LatLng>((coord) => LatLng(
                    (coord[1] as num).toDouble(),
                    (coord[0] as num).toDouble(),
                  ))
              .toList();
        }
      }
    } catch (e) {
      // Silently fail, return empty route
    }
    return [];
  }

  /// Get distance and duration from OSRM
  static Future<Map<String, dynamic>> getRouteInfo(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return {'distance': 0.0, 'duration': 0.0};

    final coords = waypoints
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');

    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$coords'
      '?overview=false&steps=false',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          return {
            'distance': (route['distance'] as num).toDouble() / 1000,
            'duration': (route['duration'] as num).toDouble() / 60,
          };
        }
      }
    } catch (e) {
      // Silently fail
    }
    return {'distance': 0.0, 'duration': 0.0};
  }

  /// Fetch directions from OSRM with turn-by-turn steps
  /// Returns polyline + navigation steps
  static Future<NavigationRoute> getDirectionsWithSteps(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return NavigationRoute.empty();

    final coords = waypoints
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');

    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$coords'
      '?overview=full&geometries=geojson&steps=true&banner_instructions=true',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];

          // Parse polyline
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;
          final polyline = coordinates
              .map<LatLng>((coord) => LatLng(
                    (coord[1] as num).toDouble(),
                    (coord[0] as num).toDouble(),
                  ))
              .toList();

          // Parse steps from all legs
          final legs = route['legs'] as List;
          final steps = <NavigationStep>[];
          for (final leg in legs) {
            final legSteps = leg['steps'] as List;
            for (final s in legSteps) {
              final maneuver = s['maneuver'] as Map<String, dynamic>;
              final loc = maneuver['location'] as List;
              final modifier = maneuver['modifier'] as String? ?? '';
              final type = maneuver['type'] as String? ?? '';

              // Build instruction text
              final name = s['name'] as String? ?? '';
              final instruction = _buildInstruction(type, modifier, name);

              steps.add(NavigationStep(
                instruction: instruction,
                distanceM: (s['distance'] as num).toDouble(),
                durationS: (s['duration'] as num).toDouble(),
                maneuverType: type,
                modifier: modifier,
                location: LatLng(
                  (loc[1] as num).toDouble(),
                  (loc[0] as num).toDouble(),
                ),
              ));
            }
          }

          final totalDistKm = (route['distance'] as num).toDouble() / 1000;
          final totalDurMin = (route['duration'] as num).toDouble() / 60;

          return NavigationRoute(
            polyline: polyline,
            steps: steps,
            totalDistanceKm: totalDistKm,
            totalDurationMin: totalDurMin,
          );
        }
      }
    } catch (e) {
      // Silently fail
    }
    return NavigationRoute.empty();
  }

  /// Build human-readable instruction from OSRM maneuver
  static String _buildInstruction(String type, String modifier, String name) {
    final road = name.isNotEmpty ? ' onto $name' : '';
    switch (type) {
      case 'depart':
        return 'Start driving$road';
      case 'arrive':
        return 'You have arrived at your destination';
      case 'turn':
        return '${_modifierText(modifier)}$road';
      case 'new name':
        return 'Continue$road';
      case 'merge':
        return 'Merge ${_modifierText(modifier).toLowerCase()}$road';
      case 'on ramp':
      case 'off ramp':
        return 'Take the ramp$road';
      case 'fork':
        return 'Keep ${modifier == 'left' ? 'left' : 'right'}$road';
      case 'roundabout':
      case 'rotary':
        return 'Enter roundabout, exit$road';
      case 'end of road':
        return '${_modifierText(modifier)} at end of road$road';
      case 'continue':
        return 'Continue straight$road';
      default:
        if (modifier.isNotEmpty) return '${_modifierText(modifier)}$road';
        return 'Continue$road';
    }
  }

  static String _modifierText(String modifier) {
    switch (modifier) {
      case 'left': return 'Turn left';
      case 'right': return 'Turn right';
      case 'sharp left': return 'Sharp left';
      case 'sharp right': return 'Sharp right';
      case 'slight left': return 'Bear left';
      case 'slight right': return 'Bear right';
      case 'straight': return 'Continue straight';
      case 'uturn': return 'Make a U-turn';
      default: return 'Continue';
    }
  }
}

/// A navigation step (one turn-by-turn instruction)
class NavigationStep {
  final String instruction;
  final double distanceM;  // meters
  final double durationS;  // seconds
  final String maneuverType;
  final String modifier;
  final LatLng location;

  const NavigationStep({
    required this.instruction,
    required this.distanceM,
    required this.durationS,
    required this.maneuverType,
    required this.modifier,
    required this.location,
  });

  String get distanceText {
    if (distanceM < 1000) return '${distanceM.toStringAsFixed(0)} m';
    return '${(distanceM / 1000).toStringAsFixed(1)} km';
  }

  String get durationText {
    if (durationS < 60) return '${durationS.toStringAsFixed(0)} sec';
    if (durationS < 3600) return '${(durationS / 60).toStringAsFixed(0)} min';
    return '${(durationS / 3600).toStringAsFixed(1)} hr';
  }

  /// Icon for the maneuver direction
  String get directionIcon {
    switch (modifier) {
      case 'left': return '↰';
      case 'right': return '↱';
      case 'sharp left': return '⬅';
      case 'sharp right': return '➡';
      case 'slight left': return '↖';
      case 'slight right': return '↗';
      case 'uturn': return '↩';
      case 'straight': return '⬆';
      default:
        if (maneuverType == 'arrive') return '🏁';
        if (maneuverType == 'depart') return '🚗';
        if (maneuverType == 'roundabout') return '🔄';
        return '⬆';
    }
  }
}

/// Complete navigation route with steps
class NavigationRoute {
  final List<LatLng> polyline;
  final List<NavigationStep> steps;
  final double totalDistanceKm;
  final double totalDurationMin;

  const NavigationRoute({
    required this.polyline,
    required this.steps,
    required this.totalDistanceKm,
    required this.totalDurationMin,
  });

  factory NavigationRoute.empty() => const NavigationRoute(
    polyline: [],
    steps: [],
    totalDistanceKm: 0,
    totalDurationMin: 0,
  );

  bool get isEmpty => steps.isEmpty;
}
