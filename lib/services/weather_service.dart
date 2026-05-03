import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

/// Weather data model
class WeatherData {
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int weatherCode;
  final bool isDay;
  final String condition;
  final String icon;

  WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.isDay,
    required this.condition,
    required this.icon,
  });
}

/// Daily forecast model
class ForecastDay {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final int weatherCode;
  final String condition;
  final String icon;

  ForecastDay({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.weatherCode,
    required this.condition,
    required this.icon,
  });
}

/// Uses Open-Meteo API — free, no API key needed
class WeatherService {
  static WeatherData? _cached;
  static DateTime? _lastFetch;

  /// Get current weather at user's location
  /// Caches for 15 minutes to avoid excessive API calls
  static Future<WeatherData?> getCurrentWeather() async {
    // Return cached if recent
    if (_cached != null && _lastFetch != null) {
      if (DateTime.now().difference(_lastFetch!).inMinutes < 15) {
        return _cached;
      }
    }

    try {
      final hasPermission = await LocationService.requestPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 10));

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${position.latitude}'
        '&longitude=${position.longitude}'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,'
        'weather_code,wind_speed_10m,is_day'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min'
        '&forecast_days=3'
        '&timezone=auto',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      final current = json['current'];

      final code = current['weather_code'] as int;
      final isDay = (current['is_day'] as int) == 1;

      _cached = WeatherData(
        temperature: (current['temperature_2m'] as num).toDouble(),
        feelsLike: (current['apparent_temperature'] as num).toDouble(),
        humidity: (current['relative_humidity_2m'] as num).toInt(),
        windSpeed: (current['wind_speed_10m'] as num).toDouble(),
        weatherCode: code,
        isDay: isDay,
        condition: _getCondition(code),
        icon: _getIcon(code, isDay),
      );
      _lastFetch = DateTime.now();

      // Also parse forecast
      _cachedForecast = _parseForecast(json);

      return _cached;
    } catch (e) {
      debugPrint('Weather error: $e');
      return _cached; // Return stale cache if available
    }
  }

  /// WMO weather code → human-readable condition
  static String _getCondition(int code) {
    switch (code) {
      case 0: return 'Clear Sky';
      case 1: return 'Mainly Clear';
      case 2: return 'Partly Cloudy';
      case 3: return 'Overcast';
      case 45: case 48: return 'Foggy';
      case 51: case 53: case 55: return 'Drizzle';
      case 56: case 57: return 'Freezing Drizzle';
      case 61: case 63: case 65: return 'Rain';
      case 66: case 67: return 'Freezing Rain';
      case 71: case 73: case 75: return 'Snowfall';
      case 77: return 'Snow Grains';
      case 80: case 81: case 82: return 'Rain Showers';
      case 85: case 86: return 'Snow Showers';
      case 95: return 'Thunderstorm';
      case 96: case 99: return 'Thunderstorm + Hail';
      default: return 'Unknown';
    }
  }

  /// WMO weather code → emoji icon
  static String _getIcon(int code, bool isDay) {
    switch (code) {
      case 0: return isDay ? '☀️' : '🌙';
      case 1: return isDay ? '🌤️' : '🌙';
      case 2: return '⛅';
      case 3: return '☁️';
      case 45: case 48: return '🌫️';
      case 51: case 53: case 55: return '🌦️';
      case 56: case 57: return '🌧️';
      case 61: case 63: return '🌧️';
      case 65: return '🌧️';
      case 66: case 67: return '❄️🌧️';
      case 71: case 73: case 75: return '❄️';
      case 77: return '❄️';
      case 80: case 81: case 82: return '🌧️';
      case 85: case 86: return '🌨️';
      case 95: return '⛈️';
      case 96: case 99: return '⛈️';
      default: return '🌡️';
    }
  }

  /// Parse 3-day forecast from the same API response
  static List<ForecastDay> _parseForecast(Map<String, dynamic> json) {
    final daily = json['daily'];
    if (daily == null) return [];
    final dates = (daily['time'] as List?) ?? [];
    final maxTemps = (daily['temperature_2m_max'] as List?) ?? [];
    final minTemps = (daily['temperature_2m_min'] as List?) ?? [];
    final codes = (daily['weather_code'] as List?) ?? [];

    final List<ForecastDay> forecast = [];
    for (int i = 0; i < dates.length && i < 3; i++) {
      final code = (codes[i] as num).toInt();
      forecast.add(ForecastDay(
        date: DateTime.parse(dates[i]),
        tempMax: (maxTemps[i] as num).toDouble(),
        tempMin: (minTemps[i] as num).toDouble(),
        weatherCode: code,
        condition: _getCondition(code),
        icon: _getIcon(code, true),
      ));
    }
    return forecast;
  }

  /// Cached forecast
  static List<ForecastDay>? _cachedForecast;

  /// Get 3-day forecast
  static Future<List<ForecastDay>> getForecast() async {
    if (_cachedForecast != null && _lastFetch != null) {
      if (DateTime.now().difference(_lastFetch!).inMinutes < 15) {
        return _cachedForecast!;
      }
    }
    // Trigger getCurrentWeather to refresh the cache
    await getCurrentWeather();
    return _cachedForecast ?? [];
  }
}
