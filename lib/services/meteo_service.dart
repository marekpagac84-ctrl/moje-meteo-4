import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/meteo_data.dart';

class MeteoService {
  static const List<PresetLocation> presetLocations = [
    PresetLocation(name: 'Nové Mesto nad Váhom', lat: 48.755, lng: 17.830),
    PresetLocation(name: 'Bratislava', lat: 48.148, lng: 17.107),
    PresetLocation(name: 'Trenčín', lat: 48.894, lng: 18.044),
    PresetLocation(name: 'Žilina', lat: 49.223, lng: 18.739),
    PresetLocation(name: 'Košice', lat: 48.716, lng: 21.261),
    PresetLocation(name: 'Banská Bystrica', lat: 48.736, lng: 19.146),
  ];

  static Future<MeteoApiData> fetchOfficialWeatherData(double lat, double lng) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,precipitation,wind_speed_10m,weather_code',
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final current = data['current'] ?? {};
      final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 18.0;
      final rain = (current['precipitation'] as num?)?.toDouble() ?? 0.0;
      final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 12.0;
      final code = (current['weather_code'] as num?)?.toInt() ?? 0;
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      return MeteoApiData(
        temperature: temp,
        precipitation: rain,
        windSpeed: wind,
        weatherCode: code,
        isRain: rain > 0,
        lastUpdated: timeStr,
        statusMessage: rain > 0 ? "⚠️ Zrážkové pásmo v dosahu" : "☀️ Bez zrážok v okruhu 50 km",
      );
    } else {
      throw Exception('Nie je možné načítať dáta z Open-Meteo API');
    }
  }

  static Future<Position?> getDeviceLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  static List<CommunityMarker> getSampleCommunityMarkers(double userLat, double userLng) {
    return [
      CommunityMarker(
        id: '1',
        latitude: userLat + 0.015,
        longitude: userLng - 0.02,
        pressureDrop: -2.8,
        timestamp: 'Pred 2 min',
        label: 'Detekovaný pokles (-2.8 hPa)',
      ),
      CommunityMarker(
        id: '2',
        latitude: userLat - 0.012,
        longitude: userLng + 0.025,
        pressureDrop: -1.9,
        timestamp: 'Pred 5 min',
        label: 'Prudký veterný poryv',
      ),
      CommunityMarker(
        id: '3',
        latitude: userLat + 0.028,
        longitude: userLng + 0.010,
        pressureDrop: -3.1,
        timestamp: 'Pred 1 min',
        label: 'Búrkové jadro (Barometer drop)',
      ),
    ];
  }
}
