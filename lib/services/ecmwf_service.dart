import 'dart:convert';

import 'package:http/http.dart' as http;

/// Dáta z ECMWF IFS HRES 9 km.
///
/// ECMWF HRES neposkytuje priamo precipitation_probability.
/// Preto pracujeme s hodinovými zrážkami a vytvárame z nich
/// "rain signal", ktorý následne porovnávame s Open-Meteo.
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

  /// Aktuálne ECMWF zrážky.
  double get currentPrecipitation {
    if (precipitation.isEmpty) {
      return 0.0;
    }

    return precipitation.first;
  }

  /// Najväčšie predpokladané zrážky v najbližších 6 hodinách.
  double get maxPrecipitationNext6Hours {
    if (precipitation.isEmpty) {
      return 0.0;
    }

    final int count =
        precipitation.length < 6
            ? precipitation.length
            : 6;

    double maxValue = 0.0;

    for (int i = 0; i < count; i++) {
      if (precipitation[i] > maxValue) {
        maxValue = precipitation[i];
      }
    }

    return maxValue;
  }

  /// Sú v najbližších 6 hodinách podľa ECMWF očakávané
  /// merateľné zrážky?
  bool get rainExpectedNext6Hours {
    final int count =
        precipitation.length < 6
            ? precipitation.length
            : 6;

    for (int i = 0; i < count; i++) {
      if (precipitation[i] >= 0.1) {
        return true;
      }
    }

    return false;
  }

  /// Najbližšia hodina, v ktorej ECMWF predpokladá
  /// aspoň 0.1 mm zrážok.
  int? get firstRainHourIndex {
    final int count =
        precipitation.length < 6
            ? precipitation.length
            : 6;

    for (int i = 0; i < count; i++) {
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
      final Uri uri = Uri.parse(
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

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        print(
          'ECMWF HTTP ERROR: ${response.statusCode}',
        );
        return null;
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body)
              as Map<String, dynamic>;

      final Map<String, dynamic>? hourly =
          data['hourly']
              as Map<String, dynamic>?;

      if (hourly == null) {
        print(
          'ECMWF ERROR: hourly data missing',
        );
        return null;
      }

      final List<String> times =
          (hourly['time'] as List?)
                  ?.map(
                    (e) => e.toString(),
                  )
                  .toList() ??
              [];

      final List<double> precipitation =
          (hourly['precipitation'] as List?)
                  ?.map(
                    (e) =>
                        (e as num).toDouble(),
                  )
                  .toList() ??
              [];

      final List<double> cloudCover =
          (hourly['cloud_cover'] as List?)
                  ?.map(
                    (e) =>
                        (e as num).toDouble(),
                  )
                  .toList() ??
              [];

      final List<double> temperature =
          (hourly['temperature_2m'] as List?)
                  ?.map(
                    (e) =>
                        (e as num).toDouble(),
                  )
                  .toList() ??
              [];

      final List<double> windSpeed =
          (hourly['wind_speed_10m'] as List?)
                  ?.map(
                    (e) =>
                        (e as num).toDouble(),
                  )
                  .toList() ??
              [];

      final List<double> windDirection =
          (hourly['wind_direction_10m'] as List?)
                  ?.map(
                    (e) =>
                        (e as num).toDouble(),
                  )
                  .toList() ??
              [];

      final List<double> surfacePressure =
          (hourly['surface_pressure'] as List?)
                  ?.map(
                    (e) =>
                        (e as num).toDouble(),
                  )
                  .toList() ??
              [];

      if (precipitation.isEmpty) {
        print(
          'ECMWF ERROR: precipitation data empty',
        );
        return null;
      }

      return EcmwfData(
        times: times,
        precipitation: precipitation,
        cloudCover: cloudCover,
        temperature: temperature,
        windSpeed: windSpeed,
        windDirection: windDirection,
        surfacePressure: surfacePressure,
      );
    } catch (e) {
      print(
        'ECMWF EXCEPTION: $e',
      );

      return null;
    }
  }
}
