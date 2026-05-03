import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../widgets/notification_bell.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  bool _loading = true;
  Map<String, dynamic>? _current;
  List<dynamic> _forecast = [];
  String _city = '';
  String? _error;

  static const _weatherIcons = {
    0: '☀️', 1: '🌤', 2: '⛅', 3: '☁️', 45: '🌫', 48: '🌫',
    51: '🌦', 53: '🌦', 55: '🌧', 61: '🌧', 63: '🌧', 65: '🌧',
    71: '🌨', 73: '🌨', 75: '❄️', 80: '🌦', 81: '🌧', 82: '⛈',
    95: '⛈', 96: '⛈', 99: '⛈',
  };

  static const _weatherDesc = {
    0: 'Clear sky', 1: 'Mainly clear', 2: 'Partly cloudy', 3: 'Overcast',
    45: 'Foggy', 48: 'Rime fog', 51: 'Light drizzle', 53: 'Drizzle', 55: 'Heavy drizzle',
    61: 'Light rain', 63: 'Rain', 65: 'Heavy rain', 71: 'Light snow', 73: 'Snow', 75: 'Heavy snow',
    80: 'Light showers', 81: 'Showers', 82: 'Heavy showers', 95: 'Thunderstorm', 96: 'Hailstorm', 99: 'Severe storm',
  };

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    setState(() { _loading = true; _error = null; });
    try {
      final pos = await _getPosition();
      final lat = pos.latitude;
      final lon = pos.longitude;

      // Reverse geocode
      final geoResp = await http.get(Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&accept-language=en'))
          .timeout(const Duration(seconds: 10));
      if (geoResp.statusCode == 200) {
        final geoJson = jsonDecode(geoResp.body);
        final addr = geoJson['address'] as Map<String, dynamic>? ?? {};
        _city = addr['city'] as String? ?? addr['town'] as String? ?? addr['village'] as String? ?? 'Your Location';
      }

      // Weather
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
          '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,apparent_temperature'
          '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max'
          '&timezone=auto&forecast_days=7';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        _current = json['current'] as Map<String, dynamic>?;
        final daily = json['daily'] as Map<String, dynamic>?;
        if (daily != null) {
          final dates = daily['time'] as List? ?? [];
          _forecast = List.generate(dates.length, (i) => {
            'date': dates[i],
            'code': (daily['weather_code'] as List?)?[i] ?? 0,
            'max': (daily['temperature_2m_max'] as List?)?[i] ?? 0,
            'min': (daily['temperature_2m_min'] as List?)?[i] ?? 0,
            'rain': (daily['precipitation_sum'] as List?)?[i] ?? 0,
            'wind': (daily['wind_speed_10m_max'] as List?)?[i] ?? 0,
          });
        }
      }
    } catch (e) {
      _error = 'Could not load weather';
    }
    setState(() => _loading = false);
  }

  Future<Position> _getPosition() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('Location disabled');
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) throw Exception('Denied');
    }
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low).timeout(const Duration(seconds: 10));
  }

  String _dayName(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return date;
    final now = DateTime.now();
    if (d.day == now.day && d.month == now.month) return 'Today';
    if (d.day == now.day + 1 && d.month == now.month) return 'Tomorrow';
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final code = (_current?['weather_code'] as num?)?.toInt() ?? 0;
    final temp = (_current?['temperature_2m'] as num?)?.toDouble() ?? 0;
    final feels = (_current?['apparent_temperature'] as num?)?.toDouble() ?? 0;
    final humidity = (_current?['relative_humidity_2m'] as num?)?.toInt() ?? 0;
    final wind = (_current?['wind_speed_10m'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Weather', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: _fetchWeather),
          const NotificationBell(), const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.white24),
                  const SizedBox(height: 12),
                  Text(_error!, style: GoogleFonts.inter(color: Colors.white38)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _fetchWeather, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8)),
                      child: Text('Retry', style: GoogleFonts.inter(color: Colors.white))),
                ]))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Current weather hero
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: temp > 30 ? [const Color(0xFFFF6D00), const Color(0xFFFF9100)]
                              : temp > 15 ? [const Color(0xFF1A73E8), const Color(0xFF4FC3F7)]
                              : [const Color(0xFF5C6BC0), const Color(0xFF9FA8DA)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: const Color(0xFF1A73E8).withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: Column(children: [
                        Text(_city, style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(_weatherIcons[code] ?? '🌡', style: const TextStyle(fontSize: 52)),
                        Text('${temp.toStringAsFixed(1)}°C', style: GoogleFonts.inter(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
                        Text(_weatherDesc[code] ?? 'Unknown', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 12),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                          _miniStat('Feels', '${feels.toStringAsFixed(0)}°'),
                          _miniStat('Humidity', '$humidity%'),
                          _miniStat('Wind', '${wind.toStringAsFixed(0)} km/h'),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    Text('7-Day Forecast', style: GoogleFonts.inter(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    ..._forecast.map((f) {
                      final fCode = (f['code'] as num?)?.toInt() ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Row(children: [
                          SizedBox(width: 60, child: Text(_dayName(f['date']), style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                          Text(_weatherIcons[fCode] ?? '🌡', style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_weatherDesc[fCode] ?? '', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11))),
                          Text('${(f['min'] as num).toStringAsFixed(0)}°', style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
                          Container(
                            width: 60, height: 4, margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: LinearGradient(colors: [Colors.blue.shade300, Colors.orange.shade300]),
                            ),
                          ),
                          Text('${(f['max'] as num).toStringAsFixed(0)}°', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        ]),
                      );
                    }),
                  ],
                ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(children: [
      Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
    ]);
  }
}
