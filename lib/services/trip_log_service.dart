import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

/// Trip log service — records location checkpoints during travel
class TripLogService {
  static final _firestore = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /// Log a location checkpoint
  static Future<void> logCheckpoint({
    String? teamId,
    required String placeName,
    String? notes,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}

    final ref = teamId != null
        ? _firestore.collection('teams').doc(teamId).collection('trip_log')
        : _firestore.collection('users').doc(_uid).collection('trip_log');

    await ref.add({
      'placeName': placeName,
      'notes': notes ?? '',
      'lat': position?.latitude ?? 0,
      'lng': position?.longitude ?? 0,
      'altitude': position?.altitude ?? 0,
      'speed': (position?.speed ?? 0) * 3.6,
      'userId': user.uid,
      'userName': user.displayName ?? 'Unknown',
      'userPhoto': user.photoURL ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Stream trip log entries (newest first)
  static Stream<QuerySnapshot> getTripLog(String? teamId) {
    final ref = teamId != null
        ? _firestore.collection('teams').doc(teamId).collection('trip_log')
        : _firestore.collection('users').doc(_uid).collection('trip_log');

    return ref.orderBy('timestamp', descending: true).snapshots();
  }

  /// Delete a log entry
  static Future<void> deleteEntry(String? teamId, String entryId) async {
    final ref = teamId != null
        ? _firestore.collection('teams').doc(teamId).collection('trip_log')
        : _firestore.collection('users').doc(_uid).collection('trip_log');

    await ref.doc(entryId).delete();
  }
}
