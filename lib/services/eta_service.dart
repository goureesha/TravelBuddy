import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

/// ETA sharing service — share your estimated arrival time with team
class EtaService {
  static final _firestore = FirebaseFirestore.instance;

  /// Share your ETA with a team
  static Future<void> shareEta({
    required String teamId,
    required String destinationName,
    required double destLat,
    required double destLng,
    required int estimatedMinutes,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}

    final arrivalTime = DateTime.now().add(Duration(minutes: estimatedMinutes));

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('eta')
        .doc(user.uid)
        .set({
      'userId': user.uid,
      'userName': user.displayName ?? 'Unknown',
      'userPhoto': user.photoURL ?? '',
      'destinationName': destinationName,
      'destLat': destLat,
      'destLng': destLng,
      'currentLat': position?.latitude ?? 0,
      'currentLng': position?.longitude ?? 0,
      'estimatedMinutes': estimatedMinutes,
      'estimatedArrival': Timestamp.fromDate(arrivalTime),
      'sharedAt': FieldValue.serverTimestamp(),
      'active': true,
    });

    // Also send as chat message
    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('messages')
        .add({
      'text': '📍 ETA: ${user.displayName ?? "I"} will arrive at $destinationName in ~$estimatedMinutes min',
      'senderId': user.uid,
      'senderName': user.displayName ?? 'Unknown',
      'senderPhoto': user.photoURL ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'eta',
    });

    debugPrint('ETA shared: $destinationName in $estimatedMinutes min');
  }

  /// Clear your ETA (arrived or cancelled)
  static Future<void> clearEta(String teamId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('eta')
        .doc(uid)
        .update({'active': false});
  }

  /// Stream active ETAs for a team
  static Stream<QuerySnapshot> getActiveEtas(String teamId) {
    return _firestore
        .collection('teams')
        .doc(teamId)
        .collection('eta')
        .where('active', isEqualTo: true)
        .snapshots();
  }
}
