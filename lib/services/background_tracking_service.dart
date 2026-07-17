import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2;
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background GPS tracking service.
/// Runs as an Android foreground service so tracking continues when the app
/// is minimised or the screen is off.
class BackgroundTrackingService {
  static final _service = FlutterBackgroundService();
  static bool _initialized = false;

  // ── Keys for SharedPreferences IPC ──
  static const _kIsTracking = 'bg_is_tracking';
  static const _kTrackPoints = 'bg_track_points'; // "lat,lng;lat,lng;..."
  static const _kDistanceKm = 'bg_distance_km';
  static const _kStartTime = 'bg_start_time'; // millisSinceEpoch

  // ── Initialize the background service (call once on app start) ──
  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    // Notification channel for the persistent notification
    const channel = AndroidNotificationChannel(
      'travel_buddy_tracking',
      'Trip Tracking',
      description: 'Shows when TravelBuddy is tracking your trip',
      importance: Importance.low,
    );

    final notifPlugin = FlutterLocalNotificationsPlugin();
    await notifPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'travel_buddy_tracking',
        initialNotificationTitle: 'TravelBuddy Tracking',
        initialNotificationContent: 'Preparing...',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
      ),
    );
  }

  // ── Start tracking ──
  static Future<void> startTracking() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsTracking, true);
    await prefs.setString(_kTrackPoints, '');
    await prefs.setDouble(_kDistanceKm, 0);
    await prefs.setInt(_kStartTime, DateTime.now().millisecondsSinceEpoch);
    await _service.startService();
  }

  // ── Stop tracking ──
  static Future<void> stopTracking() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsTracking, false);
    _service.invoke('stop');
  }

  // ── Read current tracking data from SharedPreferences ──
  static Future<TrackingSnapshot> getSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final isTracking = prefs.getBool(_kIsTracking) ?? false;
    final pointsStr = prefs.getString(_kTrackPoints) ?? '';
    final distKm = prefs.getDouble(_kDistanceKm) ?? 0;
    final startMs = prefs.getInt(_kStartTime) ?? 0;

    final points = <List<double>>[];
    if (pointsStr.isNotEmpty) {
      for (final seg in pointsStr.split(';')) {
        final parts = seg.split(',');
        if (parts.length == 2) {
          final lat = double.tryParse(parts[0]);
          final lng = double.tryParse(parts[1]);
          if (lat != null && lng != null) points.add([lat, lng]);
        }
      }
    }

    final startTime = startMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(startMs)
        : null;

    return TrackingSnapshot(
      isTracking: isTracking,
      points: points,
      distanceKm: distKm,
      startTime: startTime,
    );
  }

  // ── Haversine distance ──
  static double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * 3.141592653589793 / 180;
    final dLng = (lng2 - lng1) * 3.141592653589793 / 180;
    final la1 = lat1 * 3.141592653589793 / 180;
    final la2 = lat2 * 3.141592653589793 / 180;
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(la1) * cos(la2) * sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  // ══════════════════════════════════════════
  // Background isolate entry point
  // ══════════════════════════════════════════
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    if (service is AndroidServiceInstance) {
      service.on('stop').listen((_) {
        service.stopSelf();
      });
    }

    StreamSubscription<Position>? gpsSub;
    final prefs = await SharedPreferences.getInstance();
    double lastLat = 0, lastLng = 0;

    gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) async {
      await prefs.reload();
      final isTracking = prefs.getBool(_kIsTracking) ?? false;
      if (!isTracking) {
        gpsSub?.cancel();
        if (service is AndroidServiceInstance) service.stopSelf();
        return;
      }

      final currentPoints = prefs.getString(_kTrackPoints) ?? '';
      var distKm = prefs.getDouble(_kDistanceKm) ?? 0;

      // Calculate distance from last point
      if (lastLat != 0 && lastLng != 0) {
        distKm += _haversine(lastLat, lastLng, pos.latitude, pos.longitude);
      }
      lastLat = pos.latitude;
      lastLng = pos.longitude;

      // Append new point
      final newPoints = currentPoints.isEmpty
          ? '${pos.latitude},${pos.longitude}'
          : '$currentPoints;${pos.latitude},${pos.longitude}';

      await prefs.setString(_kTrackPoints, newPoints);
      await prefs.setDouble(_kDistanceKm, distKm);

      // Update notification
      final startMs = prefs.getInt(_kStartTime) ?? 0;
      final elapsed = startMs > 0
          ? DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(startMs))
          : Duration.zero;
      final h = elapsed.inHours;
      final m = elapsed.inMinutes.remainder(60);
      final s = elapsed.inSeconds.remainder(60);
      final timeStr = h > 0
          ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
          : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: '📍 TravelBuddy Tracking',
          content: '${distKm.toStringAsFixed(1)} km • $timeStr',
        );
      }
    });

    // Also stop if the flag gets set to false externally
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      await prefs.reload();
      final isTracking = prefs.getBool(_kIsTracking) ?? false;
      if (!isTracking) {
        gpsSub?.cancel();
        timer.cancel();
        if (service is AndroidServiceInstance) service.stopSelf();
      }
    });
  }
}

/// Snapshot of tracking data read from SharedPreferences
class TrackingSnapshot {
  final bool isTracking;
  final List<List<double>> points; // [[lat, lng], ...]
  final double distanceKm;
  final DateTime? startTime;

  const TrackingSnapshot({
    required this.isTracking,
    required this.points,
    required this.distanceKm,
    this.startTime,
  });

  String get elapsed {
    if (startTime == null) return '00:00';
    final diff = DateTime.now().difference(startTime!);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    final s = diff.inSeconds.remainder(60);
    return h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
