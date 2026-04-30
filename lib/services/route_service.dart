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
            'distance': (route['distance'] as num).toDouble() / 1000, // km
            'duration': (route['duration'] as num).toDouble() / 60,   // minutes
          };
        }
      }
    } catch (e) {
      // Silently fail
    }
    return {'distance': 0.0, 'duration': 0.0};
  }
}
