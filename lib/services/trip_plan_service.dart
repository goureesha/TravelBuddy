import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripPlanService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;
  static String? get _name => _auth.currentUser?.displayName;

  /// Activity types for stops during a live trip
  static const Map<String, Map<String, String>> activityTypes = {
    'fuel': {'emoji': '⛽', 'label': 'Fuel'},
    'food': {'emoji': '🍽️', 'label': 'Food'},
    'tea': {'emoji': '🍵', 'label': 'Tea/Coffee'},
    'hotel': {'emoji': '🏨', 'label': 'Hotel/Stay'},
    'viewpoint': {'emoji': '🏔️', 'label': 'Viewpoint'},
    'suggestion': {'emoji': '💡', 'label': 'Suggestion'},
    'rest': {'emoji': '🅿️', 'label': 'Rest Stop'},
    'other': {'emoji': '📝', 'label': 'Other'},
  };

  /// Returns the trip_plans collection ref — personal or team-scoped
  static CollectionReference _plansRef(String? teamId) {
    if (teamId != null) {
      return _firestore.collection('teams').doc(teamId).collection('trip_plans');
    }
    return _firestore.collection('users').doc(_uid!).collection('trip_plans');
  }

  /// Save a new trip plan (or update existing)
  static Future<String?> savePlan({
    String? teamId,
    String? planId,
    required String name,
    required List<Map<String, dynamic>> waypoints,
    required double routeDistanceKm,
    required double routeDurationMin,
    String? routePolyline,
    bool isRoundTrip = false,
  }) async {
    if (_uid == null) return null;

    final data = {
      'name': name.trim(),
      'isRoundTrip': isRoundTrip,
      'status': 'planned',
      'waypoints': waypoints,
      'routeDistanceKm': routeDistanceKm,
      'routeDurationMin': routeDurationMin,
      'routePolyline': routePolyline ?? '',
      'teamId': teamId,
      'shareCode': null,
      'createdBy': _uid,
      'createdByName': _name ?? 'Unknown',
      'createdAt': FieldValue.serverTimestamp(),
      'startedAt': null,
      'completedAt': null,
      'stops': [],
    };

    if (planId != null) {
      // Update existing plan
      data.remove('createdAt');
      data.remove('stops');
      data.remove('status');
      await _plansRef(teamId).doc(planId).update(data);
      return planId;
    } else {
      final docRef = await _plansRef(teamId).add(data);
      return docRef.id;
    }
  }

  /// Get all trip plans (newest first)
  static Stream<QuerySnapshot> getPlans(String? teamId) {
    return _plansRef(teamId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get a single trip plan
  static Stream<DocumentSnapshot> getPlan(String? teamId, String planId) {
    return _plansRef(teamId).doc(planId).snapshots();
  }

  /// Start a live trip
  static Future<void> startTrip(String? teamId, String planId) async {
    await _plansRef(teamId).doc(planId).update({
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Complete a trip
  static Future<void> completeTrip(String? teamId, String planId) async {
    await _plansRef(teamId).doc(planId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add an activity stop during a live trip
  static Future<void> addStop({
    String? teamId,
    required String planId,
    required String name,
    required double lat,
    required double lng,
    required String activity,
    String? notes,
  }) async {
    await _plansRef(teamId).doc(planId).update({
      'stops': FieldValue.arrayUnion([
        {
          'name': name.trim(),
          'lat': lat,
          'lng': lng,
          'activity': activity,
          'notes': notes?.trim() ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'addedBy': _uid,
          'addedByName': _name ?? 'Unknown',
        }
      ]),
    });
  }

  /// Share a trip plan — generates a share code and copies to shared_trips
  static Future<String?> sharePlan(String? teamId, String planId) async {
    if (_uid == null) return null;

    final planDoc = await _plansRef(teamId).doc(planId).get();
    if (!planDoc.exists) return null;

    final planData = planDoc.data() as Map<String, dynamic>;

    // Create a shared trip document
    final shareDoc = await _firestore.collection('shared_trips').add({
      'originalId': planId,
      'ownerId': _uid,
      'ownerName': _name ?? 'Unknown',
      'tripName': planData['name'] ?? 'Trip',
      'tripData': planData,
      'sharedAt': FieldValue.serverTimestamp(),
      'views': 0,
    });

    final shareCode = shareDoc.id.substring(0, 8).toUpperCase();
    await shareDoc.update({'shareCode': shareCode});

    // Also store the code on the original plan
    await _plansRef(teamId).doc(planId).update({'shareCode': shareCode});

    return shareCode;
  }

  /// Load a shared plan by share code
  static Future<Map<String, dynamic>?> loadSharedPlan(String code) async {
    final query = await _firestore
        .collection('shared_trips')
        .where('shareCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final data = doc.data();

    // Increment views
    await doc.reference.update({'views': FieldValue.increment(1)});

    return data['tripData'] as Map<String, dynamic>?;
  }

  /// Clone a shared plan into the user's own trip_plans
  static Future<String?> cloneSharedPlan(Map<String, dynamic> tripData) async {
    if (_uid == null) return null;

    final data = Map<String, dynamic>.from(tripData);
    data['createdBy'] = _uid;
    data['createdByName'] = _name ?? 'Unknown';
    data['createdAt'] = FieldValue.serverTimestamp();
    data['status'] = 'planned';
    data['shareCode'] = null;
    data['startedAt'] = null;
    data['completedAt'] = null;
    data['stops'] = [];

    final docRef = await _plansRef(null).add(data);
    return docRef.id;
  }

  /// Delete a trip plan
  static Future<void> deletePlan(String? teamId, String planId) async {
    await _plansRef(teamId).doc(planId).delete();
  }

  /// Get share text for WhatsApp / external sharing
  static String getShareText(Map<String, dynamic> planData, String shareCode) {
    final name = planData['name'] ?? 'Trip';
    final dist = (planData['routeDistanceKm'] as num?)?.toStringAsFixed(1) ?? '0';
    final dur = (planData['routeDurationMin'] as num?)?.toDouble() ?? 0;
    final durText = dur < 60
        ? '${dur.toStringAsFixed(0)} min'
        : '${(dur / 60).toStringAsFixed(1)} hr';
    final waypoints = planData['waypoints'] as List? ?? [];
    final stopCount = waypoints.length > 2 ? waypoints.length - 2 : 0;

    return '🗺️ Check out my trip plan "$name"!\n'
        '📍 ${waypoints.length} waypoints${stopCount > 0 ? ' · $stopCount stops' : ''}\n'
        '📏 $dist km · ⏱️ $durText\n'
        '\nOpen in TravelBuddy with code: *$shareCode*';
  }
}
