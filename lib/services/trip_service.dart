import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;
  static String? get _name => _auth.currentUser?.displayName;

  /// Returns the base collection ref — personal or team-scoped
  static CollectionReference _tripsRef(String? teamId) {
    if (teamId != null) {
      return _firestore.collection('teams').doc(teamId).collection('trips');
    }
    return _firestore.collection('users').doc(_uid!).collection('trips');
  }

  /// Start a new trip
  static Future<String?> startTrip({
    String? teamId,
    required String vehicleName,
    required double fuelPricePerLiter,
    double startOdometer = 0,
  }) async {
    if (_uid == null) return null;

    final docRef = await _tripsRef(teamId).add({
      'userId': _uid,
      'userName': _name ?? 'Unknown',
      'vehicleName': vehicleName.trim(),
      'fuelPricePerLiter': fuelPricePerLiter,
      'startOdometer': startOdometer,
      'endOdometer': 0,
      'fuelUsedLiters': 0,
      'totalDistanceKm': 0,
      'totalCost': 0,
      'status': 'active', // active, completed
      'startedAt': FieldValue.serverTimestamp(),
      'completedAt': null,
      'fuelLogs': [],
    });

    return docRef.id;
  }

  /// End a trip
  static Future<void> endTrip({
    String? teamId,
    required String tripId,
    required double endOdometer,
    required double fuelUsedLiters,
  }) async {
    final tripRef = _tripsRef(teamId).doc(tripId);

    final tripSnap = await tripRef.get();
    if (!tripSnap.exists) return;

    final data = tripSnap.data()! as Map<String, dynamic>;
    final startOdometer = (data['startOdometer'] as num?)?.toDouble() ?? 0;
    final fuelPrice = (data['fuelPricePerLiter'] as num?)?.toDouble() ?? 0;
    final distanceKm = endOdometer - startOdometer;
    final totalCost = fuelUsedLiters * fuelPrice;

    await tripRef.update({
      'endOdometer': endOdometer,
      'fuelUsedLiters': fuelUsedLiters,
      'totalDistanceKm': distanceKm > 0 ? distanceKm : 0,
      'totalCost': totalCost,
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add a fuel log entry during a trip
  static Future<void> addFuelLog({
    String? teamId,
    required String tripId,
    required double liters,
    required double costPerLiter,
    String? stationName,
  }) async {
    await _tripsRef(teamId).doc(tripId).update({
      'fuelLogs': FieldValue.arrayUnion([
        {
          'liters': liters,
          'costPerLiter': costPerLiter,
          'totalCost': liters * costPerLiter,
          'stationName': stationName ?? '',
          'addedAt': DateTime.now().toIso8601String(),
          'addedBy': _uid,
        }
      ]),
    });
  }

  /// Get active trip for a team or personal
  static Stream<QuerySnapshot> getActiveTrips(String? teamId) {
    return _tripsRef(teamId)
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  /// Get all trips for a team or personal (history)
  static Stream<QuerySnapshot> getTripHistory(String? teamId) {
    return _tripsRef(teamId).snapshots();
  }

  /// Get trip stats summary
  static Future<Map<String, double>> getTripStats(String? teamId) async {
    final snapshot = await _tripsRef(teamId)
        .where('status', isEqualTo: 'completed')
        .get();

    double totalDistance = 0;
    double totalFuel = 0;
    double totalCost = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalDistance += (data['totalDistanceKm'] as num?)?.toDouble() ?? 0;
      totalFuel += (data['fuelUsedLiters'] as num?)?.toDouble() ?? 0;
      totalCost += (data['totalCost'] as num?)?.toDouble() ?? 0;
    }

    return {
      'totalDistance': totalDistance,
      'totalFuel': totalFuel,
      'totalCost': totalCost,
      'avgEfficiency': totalDistance > 0 ? totalDistance / totalFuel : 0,
      'tripCount': snapshot.docs.length.toDouble(),
    };
  }
}
