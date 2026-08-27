import 'dart:convert';

import 'package:http/http.dart' as http;

class EcmwfData {
  final List<String> times;

  final List<double> precipitation;
  final List<double> cloudCover;
  final List<double> temperature;
  final List<double> windSpeed;
  final List<double> windDirection;
  final List<double> surfacePressure;

  const EcmwfData({
    required this.times,
    required this.precipitation,
    required this.cloudCover,
    required this.temperature,
    required this.windSpeed,
    required this.windDirection,
    required this.surfacePressure,
  });

  double get currentPrecipitation {
    if (precipitation.isEmpty) {
      return 0.0;
    }

    return precipitation.first;
  }

  double get maxPrecipitationNext6Hours {
    if (precipitation.isEmpty) {
      return 0.0;
    }

    final count =
        precipitation.length < 6
            ? precipitation.length
            : 6;

    double maxValue = 0.0;

    for (int i = 0;
        i < count;
        i++) {
      if (precipitation[i] >
          maxValue) {
        maxValue =
            precipitation[i];
      }
    }

    return maxValue;
  }

  bool get rainExpectedNext6Hours {
    final count =
        precipitation.length < 6
            ? precipitation.length
            : 6;

    for (int i = 0;
        i < count;
        i++) {
      if (precipitation[i] >= 0.1) {
        return true;
      }
    }

    return false;
  }

  int? get firstRainHourIndex {
    final count =
        precipitation.length < 6
            ? precipitation.length
            : 6;

    for (int i = 0;
        i < count;
        i++) {
      if (precipitation[i] >= 0.1) {
        return i;
      }
    }

    return null;
  }
}

class EcmwfService {
  static const String _baseUrl =
      'https://api.open-meteo.com/v1/ecmwf';

  Future<EcmwfData?> getForecast({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl'
        '?latitude=$latitude'
        '&longitude=$longitude'
        '&hourly='
        'precipitation,'
        'cloud_cover,'
        'temperature_2m,'
        'wind_speed_10m,'
        'wind_direction_10m,'
        'surface_pressure'
        '&forecast_hours=12'
        '&timezone=auto',
      );

      final response =
          await http.get(uri);

      if (response.statusCode != 200) {
        print(
          'ECMWF HTTP ERROR: '
          '${response.statusCode}',
        );

        return null;
      }

      final decoded =
          jsonDecode(response.body);

      if (decoded is! Map) {
        return null;
      }

      final hourly =
          decoded['hourly'];

      if (hourly is! Map) {
        return null;
      }

      List<String> readStrings(
        dynamic value,
      ) {
        if (value is! List) {
          return [];
        }

        return value
            .map(
              (e) => e.toString(),
            )
            .toList();
      }

      List<double> readDoubles(
        dynamic value,
      ) {
        if (value is! List) {
          return [];
        }

        return value
            .whereType<num>()
            .map(
              (e) => e.toDouble(),
            )
            .toList();
      }

      final data =
          EcmwfData(
        times:
            readStrings(
          hourly['time'],
        ),
        precipitation:
            readDoubles(
          hourly['precipitation'],
        ),
        cloudCover:
            readDoubles(
          hourly['cloud_cover'],
        ),
        temperature:
            readDoubles(
          hourly['temperature_2m'],
        ),
        windSpeed:
            readDoubles(
          hourly['wind_speed_10m'],
        ),
        windDirection:
            readDoubles(
          hourly[
              'wind_direction_10m'],
        ),
        surfacePressure:
            readDoubles(
          hourly[
              'surface_pressure'],
        ),
      );

      print(
        '========================================',
      );

      print(
        'ECMWF IFS HRES',
      );

      print(
        'Current precipitation: '
        '${data.currentPrecipitation} mm',
      );

      print(
        'Max next 6h: '
        '${data.maxPrecipitationNext6Hours} mm',
      );

      print(
        'Rain expected next 6h: '
        '${data.rainExpectedNext6Hours}',
      );

      print(
        'First rain hour: '
        '${data.firstRainHourIndex}',
      );

      print(
        '========================================',
      );

      return data;
    } catch (e) {
      print(
        'ECMWF ERROR: $e',
      );

      return null;
    }
  }
}
