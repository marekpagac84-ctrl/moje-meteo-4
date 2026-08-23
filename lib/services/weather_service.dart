import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  Future<Map<String, dynamic>?> getWeather({
    required double lat,
    required double lng,
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat'
        '&longitude=$lng'
        '&current='
        'temperature_2m,'
        'relative_humidity_2m,'
        'apparent_temperature,'
        'precipitation,'
        'rain,'
        'showers,'
        'weather_code,'
        'cloud_cover,'
        'pressure_msl,'
        'surface_pressure,'
        'wind_speed_10m,'
        'wind_direction_10m'
        '&hourly='
        'precipitation_probability,'
        'precipitation,'
        'rain,'
        'showers,'
        'weather_code,'
        'cloud_cover,'
        'pressure_msl,'
        'surface_pressure,'
        'wind_speed_10m,'
        'wind_direction_10m'
        '&forecast_hours=12'
        '&timezone=auto',
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        return null;
      }

      return jsonDecode(response.body)
          as Map<String, dynamic>;
    } catch (e) {
      print('WeatherService error: $e');
      return null;
    }
  }
}
