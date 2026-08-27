import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'ecmwf_service.dart';

class SkyContextResult {
  final DateTime generatedAt;

  final double latitude;
  final double longitude;

  final double temperature;
  final double apparentTemperature;

  final double humidity;

  final double surfacePressure;
  final double seaLevelPressure;

  final double windSpeed;

  /// Meteorologický smer:
  /// odkiaľ vietor prichádza.
  final double windDirection;

  final int currentRainProbability;
  final double currentPrecipitation;

  final DateTime? nextRainTime;
  final int? nextRainMinutes;

  final int? nextRainProbability;
  final double? nextRainAmount;

  final int? nextRainWeatherCode;

  final bool rainExpectedNext6Hours;

  final bool ecmwfRainExpected;

  final double? ecmwfMaxRain6h;

  final int? ecmwfFirstRainHour;

  const SkyContextResult({
    required this.generatedAt,
    required this.latitude,
    required this.longitude,
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.surfacePressure,
    required this.seaLevelPressure,
    required this.windSpeed,
    required this.windDirection,
    required this.currentRainProbability,
    required this.currentPrecipitation,
    required this.nextRainTime,
    required this.nextRainMinutes,
    required this.nextRainProbability,
    required this.nextRainAmount,
    required this.nextRainWeatherCode,
    required this.rainExpectedNext6Hours,
    required this.ecmwfRainExpected,
    required this.ecmwfMaxRain6h,
    required this.ecmwfFirstRainHour,
  });

  bool get modelsAgreeOnRain {
    return rainExpectedNext6Hours &&
        ecmwfRainExpected;
  }

  bool get modelsAgreeOnDry {
    return !rainExpectedNext6Hours &&
        !ecmwfRainExpected;
  }

  bool get modelsDisagree {
    return rainExpectedNext6Hours !=
        ecmwfRainExpected;
  }

  String get precipitationDescription {
    final amount =
        nextRainAmount ?? currentPrecipitation;

    if (amount <= 0.0) {
      return 'bez merateľných zrážok';
    }

    if (amount < 0.3) {
      return 'slabé kvapky alebo veľmi slabý dážď';
    }

    if (amount < 1.0) {
      return 'slabý dážď';
    }

    if (amount < 3.0) {
      return 'mierny dážď';
    }

    if (amount < 7.0) {
      return 'silnejší dážď';
    }

    return 'výdatné zrážky';
  }

  bool get stormSignal {
    final code = nextRainWeatherCode;

    if (code == 95 ||
        code == 96 ||
        code == 99) {
      return true;
    }

    if ((nextRainAmount ?? 0.0) >= 7.0) {
      return true;
    }

    return false;
  }
}

class SkyContextService {
  static const String _openMeteo =
      'https://api.open-meteo.com/v1/forecast';

  final EcmwfService _ecmwf =
      EcmwfService();

  Future<SkyContextResult> load({
    required double latitude,
    required double longitude,
  }) async {
    final Uri uri = Uri.parse(
      '$_openMeteo'
      '?latitude=$latitude'
      '&longitude=$longitude'
      '&current='
      'temperature_2m,'
      'apparent_temperature,'
      'relative_humidity_2m,'
      'precipitation,'
      'rain,'
      'showers,'
      'weather_code,'
      'surface_pressure,'
      'pressure_msl,'
      'wind_speed_10m,'
      'wind_direction_10m'
      '&hourly='
      'precipitation_probability,'
      'precipitation,'
      'rain,'
      'showers,'
      'weather_code,'
      'cloud_cover,'
      'surface_pressure,'
      'pressure_msl,'
      'wind_speed_10m,'
      'wind_direction_10m'
      '&forecast_hours=18'
      '&timezone=auto',
    );

    final results = await Future.wait<dynamic>([
      http.get(uri),
      _ecmwf.getForecast(
        latitude: latitude,
        longitude: longitude,
      ),
    ]);

    final http.Response response =
        results[0] as http.Response;

    final dynamic ecmwf =
        results[1];

    if (response.statusCode != 200) {
      throw Exception(
        'Open-Meteo HTTP ${response.statusCode}',
      );
    }

    final decoded =
        jsonDecode(response.body);

    if (decoded is! Map) {
      throw Exception(
        'Neplatná odpoveď Open-Meteo.',
      );
    }

    final current =
        decoded['current'];

    final hourly =
        decoded['hourly'];

    if (current is! Map ||
        hourly is! Map) {
      throw Exception(
        'Open-Meteo neposkytlo požadované dáta.',
      );
    }

    double readCurrentDouble(
      String key,
    ) {
      final value = current[key];

      if (value is num) {
        return value.toDouble();
      }

      return 0.0;
    }

    List<double> readDoubleList(
      String key,
    ) {
      final value =
          hourly[key];

      if (value is! List) {
        return [];
      }

      return value.map<double>((e) {
        if (e is num) {
          return e.toDouble();
        }

        return 0.0;
      }).toList();
    }

    List<int> readIntList(
      String key,
    ) {
      final value =
          hourly[key];

      if (value is! List) {
        return [];
      }

      return value.map<int>((e) {
        if (e is num) {
          return e.toInt();
        }

        return 0;
      }).toList();
    }

    List<DateTime> readTimes() {
      final value =
          hourly['time'];

      if (value is! List) {
        return [];
      }

      return value
          .map(
            (e) =>
                DateTime.tryParse(
                  e.toString(),
                ),
          )
          .whereType<DateTime>()
          .toList();
    }

    final times =
        readTimes();

    final probabilities =
        readIntList(
      'precipitation_probability',
    );

    final precipitations =
        readDoubleList(
      'precipitation',
    );

    final weatherCodes =
        readIntList(
      'weather_code',
    );

    final DateTime now =
        DateTime.now();

    int startIndex = 0;

    if (times.isNotEmpty) {
      for (int i = 0;
          i < times.length;
          i++) {
        if (!times[i].isBefore(
          now.subtract(
            const Duration(
              minutes: 10,
            ),
          ),
        )) {
          startIndex = i;
          break;
        }
      }
    }

    int currentProbability = 0;

    if (probabilities.isNotEmpty &&
        startIndex <
            probabilities.length) {
      currentProbability =
          probabilities[startIndex];
    }

    DateTime? nextRainTime;
    int? nextRainMinutes;
    int? nextRainProbability;
    double? nextRainAmount;
    int? nextRainWeatherCode;

    bool rainExpectedNext6Hours =
        false;

    final int end6h =
        math.min(
      times.length,
      startIndex + 7,
    );

    for (int i = startIndex;
        i < end6h;
        i++) {
      final int probability =
          i < probabilities.length
              ? probabilities[i]
              : 0;

      final double amount =
          i < precipitations.length
              ? precipitations[i]
              : 0.0;

      if (probability >= 35 ||
          amount >= 0.1) {
        rainExpectedNext6Hours =
            true;
      }
    }

    final int searchEnd =
        math.min(
      times.length,
      startIndex + 18,
    );

    for (int i = startIndex;
        i < searchEnd;
        i++) {
      final int probability =
          i < probabilities.length
              ? probabilities[i]
              : 0;

      final double amount =
          i < precipitations.length
              ? precipitations[i]
              : 0.0;

      /*
       * Nechceme vyhlásiť "dážď"
       * pri úplne zanedbateľnom 5 % signále.
       */
      final bool meaningful =
          amount >= 0.1 ||
              probability >= 40;

      if (meaningful) {
        nextRainTime =
            times[i];

        nextRainMinutes =
            math.max(
          0,
          times[i]
              .difference(now)
              .inMinutes,
        );

        nextRainProbability =
            probability;

        nextRainAmount =
            amount;

        if (i <
            weatherCodes.length) {
          nextRainWeatherCode =
              weatherCodes[i];
        }

        break;
      }
    }

    final bool ecmwfRainExpected =
        ecmwf != null
            ? ecmwf
                .rainExpectedNext6Hours
            : false;

    final double? ecmwfMax =
        ecmwf != null
            ? ecmwf
                .maxPrecipitationNext6Hours
            : null;

    final int? ecmwfHour =
        ecmwf != null
            ? ecmwf.firstRainHourIndex
            : null;

    return SkyContextResult(
      generatedAt:
          DateTime.now(),

      latitude:
          latitude,

      longitude:
          longitude,

      temperature:
          readCurrentDouble(
        'temperature_2m',
      ),

      apparentTemperature:
          readCurrentDouble(
        'apparent_temperature',
      ),

      humidity:
          readCurrentDouble(
        'relative_humidity_2m',
      ),

      surfacePressure:
          readCurrentDouble(
        'surface_pressure',
      ),

      seaLevelPressure:
          readCurrentDouble(
        'pressure_msl',
      ),

      windSpeed:
          readCurrentDouble(
        'wind_speed_10m',
      ),

      windDirection:
          readCurrentDouble(
        'wind_direction_10m',
      ),

      currentRainProbability:
          currentProbability,

      currentPrecipitation:
          readCurrentDouble(
        'precipitation',
      ),

      nextRainTime:
          nextRainTime,

      nextRainMinutes:
          nextRainMinutes,

      nextRainProbability:
          nextRainProbability,

      nextRainAmount:
          nextRainAmount,

      nextRainWeatherCode:
          nextRainWeatherCode,

      rainExpectedNext6Hours:
          rainExpectedNext6Hours,

      ecmwfRainExpected:
          ecmwfRainExpected,

      ecmwfMaxRain6h:
          ecmwfMax,

      ecmwfFirstRainHour:
          ecmwfHour,
    );
  }

  static double circularDifference(
    double a,
    double b,
  ) {
    double difference =
        (a - b).abs() % 360.0;

    if (difference > 180.0) {
      difference =
          360.0 - difference;
    }

    return difference;
  }

  static String directionName(
    double degrees,
  ) {
    final d =
        (degrees % 360 + 360) %
            360;

    if (d < 22.5 ||
        d >= 337.5) {
      return 'S';
    }

    if (d < 67.5) {
      return 'SV';
    }

    if (d < 112.5) {
      return 'V';
    }

    if (d < 157.5) {
      return 'JV';
    }

    if (d < 202.5) {
      return 'J';
    }

    if (d < 247.5) {
      return 'JZ';
    }

    if (d < 292.5) {
      return 'Z';
    }

    return 'SZ';
  }

  static String longDirectionName(
    double degrees,
  ) {
    final short =
        directionName(degrees);

    switch (short) {
      case 'S':
        return 'sever';
      case 'SV':
        return 'severovýchod';
      case 'V':
        return 'východ';
      case 'JV':
        return 'juhovýchod';
      case 'J':
        return 'juh';
      case 'JZ':
        return 'juhozápad';
      case 'Z':
        return 'západ';
      case 'SZ':
        return 'severozápad';
      default:
        return short;
    }
  }

  static String formatMinutes(
    int minutes,
  ) {
    if (minutes <= 0) {
      return 'teraz';
    }

    if (minutes < 60) {
      return 'približne o $minutes min';
    }

    final int hours =
        minutes ~/ 60;

    final int remainder =
        minutes % 60;

    if (remainder < 10) {
      return 'približne o $hours h';
    }

    return 'približne o $hours h $remainder min';
  }

  static String formatClock(
    DateTime time,
  ) {
    final h =
        time.hour
            .toString()
            .padLeft(
              2,
              '0',
            );

    final m =
        time.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$h:$m';
  }

  static double pressureAltitude({
    required double pressure,
    required double seaLevelPressure,
  }) {
    if (pressure <= 0 ||
        seaLevelPressure <= 0) {
      return 0.0;
    }

    return 44330.0 *
        (1.0 -
            math.pow(
              pressure /
                  seaLevelPressure,
              0.1903,
            ));
  }
}
