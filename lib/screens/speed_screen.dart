import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../services/location_service.dart';

class SpeedScreen extends StatefulWidget {
  const SpeedScreen({super.key});

  @override
  State<SpeedScreen> createState() => _SpeedScreenState();
}

class _SpeedScreenState extends State<SpeedScreen> with SingleTickerProviderStateMixin {
  double _speed = 0; // km/h
  double _maxSpeed = 0;
  double _avgSpeed = 0;
  double _altitude = 0;
  int _speedReadings = 0;
  double _totalSpeed = 0;
  StreamSubscription<Position>? _positionStream;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _startTracking();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startTracking() async {
    final hasPermission = await LocationService.requestPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission required for speedometer')),
        );
      }
      return;
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    ).listen((position) {
      if (!mounted) return;
      final speedKmh = position.speed * 3.6; // m/s to km/h
      _speedReadings++;
      _totalSpeed += speedKmh;

      setState(() {
        _speed = speedKmh < 1 ? 0 : speedKmh;
        _altitude = position.altitude;
        if (speedKmh > _maxSpeed) _maxSpeed = speedKmh;
        _avgSpeed = _totalSpeed / _speedReadings;
      });
    });
  }

  Color _getSpeedColor() {
    if (_speed < 40) return const Color(0xFF00BFA5);
    if (_speed < 80) return const Color(0xFF1A73E8);
    if (_speed < 120) return const Color(0xFFFF6D00);
    return const Color(0xFFE53935);
  }

  @override
  Widget build(BuildContext context) {
    final speedColor = _getSpeedColor();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Speedometer', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Speed gauge
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulse = 1 + (_pulseController.value * 0.02);
                return Transform.scale(
                  scale: _speed > 0 ? pulse : 1.0,
                  child: child,
                );
              },
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      speedColor.withOpacity(0.15),
                      const Color(0xFF0D1117),
                    ],
                  ),
                  border: Border.all(color: speedColor.withOpacity(0.4), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: speedColor.withOpacity(0.2),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _speed.toStringAsFixed(0),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    Text(
                      'km/h',
                      style: GoogleFonts.inter(
                        color: speedColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),

            // Speed indicator bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_speed / 200).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation(speedColor),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _speedStat(
                    icon: Icons.trending_up_rounded,
                    value: '${_maxSpeed.toStringAsFixed(0)}',
                    label: 'Max',
                    unit: 'km/h',
                    color: const Color(0xFFFF6D00),
                  ),
                  _speedStat(
                    icon: Icons.speed_rounded,
                    value: '${_avgSpeed.toStringAsFixed(0)}',
                    label: 'Avg',
                    unit: 'km/h',
                    color: const Color(0xFF1A73E8),
                  ),
                  _speedStat(
                    icon: Icons.terrain_rounded,
                    value: '${_altitude.toStringAsFixed(0)}',
                    label: 'Altitude',
                    unit: 'm',
                    color: const Color(0xFF00BFA5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: speedColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: speedColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _speed < 1 ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: speedColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _speed < 1
                        ? 'Stationary'
                        : _speed < 40
                            ? 'City Driving'
                            : _speed < 80
                                ? 'Highway'
                                : 'High Speed',
                    style: GoogleFonts.inter(color: speedColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _speedStat({
    required IconData icon,
    required String value,
    required String label,
    required String unit,
    required Color color,
  }) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: ' $unit',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}
