import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocationService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static StreamSubscription<Position>? _positionStream;
  static Position? lastPosition;

  /// Check & request location permissions
  static Future<bool> requestPermission() async {
    if (kIsWeb) {
      // Web: geolocator handles permissions via browser prompt
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        return result == LocationPermission.whileInUse ||
            result == LocationPermission.always;
      }
      return perm != LocationPermission.deniedForever;
    }

    // Mobile
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return false;
    }
    if (perm == LocationPermission.deniedForever) return false;
    return true;
  }

  /// Get current position once
  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        debugPrint('Location permission denied');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: kIsWeb ? 30 : 15),
        ),
      );
      lastPosition = position;
      return position;
    } catch (e) {
      debugPrint('Location error: $e');
      return null;
    }
  }

  /// Start broadcasting location to Firestore for a team
  static void startBroadcasting(String teamId) {
    stopBroadcasting();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      lastPosition = position;
      _updateFirestore(teamId, position);
    });
  }

  /// Update location in Firestore
  static Future<void> _updateFirestore(String teamId, Position position) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore
          .collection('teams')
          .doc(teamId)
          .collection('locations')
          .doc(uid)
          .set({
        'lat': position.latitude,
        'lng': position.longitude,
        'speed': position.speed, // m/s
        'speedKmh': (position.speed * 3.6), // km/h
        'heading': position.heading,
        'altitude': position.altitude,
        'accuracy': position.accuracy,
        'updatedAt': FieldValue.serverTimestamp(),
        'userId': uid,
        'userName': _auth.currentUser?.displayName ?? 'Unknown',
        'userPhoto': _auth.currentUser?.photoURL ?? '',
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore location update error: $e');
    }
  }

  /// Stop broadcasting
  static void stopBroadcasting() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  /// Get real-time location stream for all team members
  static Stream<QuerySnapshot> getTeamLocations(String teamId) {
    return _firestore
        .collection('teams')
        .doc(teamId)
        .collection('locations')
        .snapshots();
  }

  /// Calculate distance between two points in km
  static double distanceBetween(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }

  /// Format speed for display
  static String formatSpeed(double speedKmh) {
    if (speedKmh < 1) return 'Stopped';
    return '${speedKmh.toStringAsFixed(0)} km/h';
  }
}
