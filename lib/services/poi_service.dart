import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PoiService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;
  static String? get _name => _auth.currentUser?.displayName;

  /// Add a POI marker for a team
  static Future<String?> addPoi({
    required String teamId,
    required double lat,
    required double lng,
    required String title,
    required String category,
    String? notes,
  }) async {
    if (_uid == null) return null;

    final docRef = await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('pois')
        .add({
      'lat': lat,
      'lng': lng,
      'title': title.trim(),
      'category': category,
      'notes': notes ?? '',
      'addedBy': _uid,
      'addedByName': _name ?? 'Unknown',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Get all POIs for a team (real-time)
  static Stream<QuerySnapshot> getTeamPois(String teamId) {
    return _firestore
        .collection('teams')
        .doc(teamId)
        .collection('pois')
        .snapshots();
  }

  /// Delete a POI
  static Future<void> deletePoi(String teamId, String poiId) async {
    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('pois')
        .doc(poiId)
        .delete();
  }

  /// POI categories with icons
  static const categories = {
    'food': '🍽️',
    'fuel': '⛽',
    'hotel': '🏨',
    'scenic': '📸',
    'danger': '⚠️',
    'parking': '🅿️',
    'mechanic': '🔧',
    'hospital': '🏥',
    'atm': '🏧',
    'other': '📍',
  };
}
