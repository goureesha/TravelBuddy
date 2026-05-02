import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Simple fuel log service — tracks odometer, liters, price per entry.
/// Mileage is calculated from consecutive odometer readings.
class FuelService {
  static final _firestore = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /// Get the fuel_logs collection ref (personal or team-scoped)
  static CollectionReference _logsRef(String? teamId) {
    if (teamId != null) {
      return _firestore.collection('teams').doc(teamId).collection('fuel_logs');
    }
    return _firestore.collection('users').doc(_uid).collection('fuel_logs');
  }

  /// Add a new fuel log entry
  static Future<void> addFuelLog({
    String? teamId,
    required double odometerKm,
    required double liters,
    required double pricePerLiter,
    required double totalAmount,
    String? vehicleName,
    String? notes,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get previous log to calculate mileage
    final prevSnapshot = await _logsRef(teamId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    double? mileage;
    double? distanceSinceLastFill;
    if (prevSnapshot.docs.isNotEmpty) {
      final prevData = prevSnapshot.docs.first.data() as Map<String, dynamic>;
      final prevOdometer = (prevData['odometerKm'] as num?)?.toDouble() ?? 0;
      if (prevOdometer > 0 && odometerKm > prevOdometer && liters > 0) {
        distanceSinceLastFill = odometerKm - prevOdometer;
        mileage = distanceSinceLastFill / liters; // km per liter
      }
    }

    await _logsRef(teamId).add({
      'odometerKm': odometerKm,
      'liters': liters,
      'pricePerLiter': pricePerLiter,
      'totalAmount': totalAmount,
      'mileage': mileage, // km/L — null for first entry
      'distanceSinceLastFill': distanceSinceLastFill,
      'vehicleName': vehicleName ?? '',
      'notes': notes ?? '',
      'userId': user.uid,
      'userName': user.displayName ?? 'Unknown',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Also update global fuel_logs for dashboard stats
    await _firestore.collection('fuel_logs').add({
      'userId': user.uid,
      'teamId': teamId,
      'odometerKm': odometerKm,
      'liters': liters,
      'pricePerLiter': pricePerLiter,
      'totalCost': totalAmount,
      'mileage': mileage,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream all fuel logs (newest first)
  static Stream<QuerySnapshot> getFuelLogs(String? teamId) {
    return _logsRef(teamId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Delete a fuel log
  static Future<void> deleteFuelLog(String? teamId, String logId) async {
    await _logsRef(teamId).doc(logId).delete();
  }

  /// Get stats from all logs
  static Future<Map<String, double>> getStats(String? teamId) async {
    final snapshot = await _logsRef(teamId).orderBy('createdAt').get();
    final docs = snapshot.docs;

    double totalLiters = 0;
    double totalCost = 0;
    double totalMileageSum = 0;
    int mileageCount = 0;
    double bestMileage = 0;
    double worstMileage = double.infinity;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalLiters += (data['liters'] as num?)?.toDouble() ?? 0;
      totalCost += (data['totalAmount'] as num?)?.toDouble() ?? 0;

      final m = (data['mileage'] as num?)?.toDouble();
      if (m != null && m > 0) {
        totalMileageSum += m;
        mileageCount++;
        if (m > bestMileage) bestMileage = m;
        if (m < worstMileage) worstMileage = m;
      }
    }

    return {
      'totalLiters': totalLiters,
      'totalCost': totalCost,
      'avgMileage': mileageCount > 0 ? totalMileageSum / mileageCount : 0,
      'bestMileage': bestMileage,
      'worstMileage': worstMileage == double.infinity ? 0 : worstMileage,
      'fillCount': docs.length.toDouble(),
    };
  }
}
