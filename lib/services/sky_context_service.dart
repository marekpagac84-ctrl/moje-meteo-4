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

  // Podrobny 15-minutovy odhad najblizsej zrazkovej epizody.
  final DateTime? rainStartTime;
  final DateTime? rainPeakTime;
  final DateTime? rainEndTime;
  final int? rainDurationMinutes;
  final double? rainTotalAmount;
  final double? rainPeakRate;
  final double? rainArrivalWindDirection;
  final double? rainArrivalWindSpeed;
  final double? rainEstimatedDistanceKm;

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
    required this.rainStartTime,
    required this.rainPeakTime,
    required this.rainEndTime,
    required this.rainDurationMinutes,
    required this.rainTotalAmount,
    required this.rainPeakRate,
    required this.rainArrivalWindDirection,
    required this.rainArrivalWindSpeed,
    required this.rainEstimatedDistanceKm,
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

  bool get hasDetailedRainTiming =>
      rainStartTime != null && rainDurationMinutes != null;

  String get rainIntensityDescription {
    final rate = rainPeakRate;
    if (rate == null || rate <= 0) return 'nezistená';
    if (rate < 0.5) return 'veľmi slabá';
    if (rate < 2.0) return 'slabá';
    if (rate < 5.0) return 'mierna';
    if (rate < 15.0) return 'silná';
    if (rate < 30.0) return 'veľmi silná';
    return 'prívalová';
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
      '&minutely_15='
      'precipitation,'
      'rain,'
      'showers,'
      'snowfall,'
      'weather_code,'
      'wind_speed_10m,'
      'wind_direction_10m'
      '&forecast_minutely_15=32'
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

    final minutely15 =
        decoded['minutely_15'];

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

    // ==========================================================
    // 15-MINUTOVY DETAIL ZRAZOK
    // ==========================================================

    DateTime? rainStartTime;
    DateTime? rainPeakTime;
    DateTime? rainEndTime;
    int? rainDurationMinutes;
    double? rainTotalAmount;
    double? rainPeakRate;
    double? rainArrivalWindDirection;
    double? rainArrivalWindSpeed;
    double? rainEstimatedDistanceKm;

    if (minutely15 is Map) {
      List<DateTime> read15Times() {
        final value = minutely15['time'];
        if (value is! List) return [];
        return value
            .map((e) => DateTime.tryParse(e.toString()))
            .whereType<DateTime>()
            .toList();
      }

      List<double> read15DoubleList(String key) {
        final value = minutely15[key];
        if (value is! List) return [];
        return value.map<double>((e) {
          if (e is num) return e.toDouble();
          return 0.0;
        }).toList();
      }

      List<int> read15IntList(String key) {
        final value = minutely15[key];
        if (value is! List) return [];
        return value.map<int>((e) {
          if (e is num) return e.toInt();
          return 0;
        }).toList();
      }

      final t15 = read15Times();
      final p15 = read15DoubleList('precipitation');
      final c15 = read15IntList('weather_code');
      final ws15 = read15DoubleList('wind_speed_10m');
      final wd15 = read15DoubleList('wind_direction_10m');

      bool wetAt(int i) {
        final amount = i < p15.length ? p15[i] : 0.0;
        final code = i < c15.length ? c15[i] : 0;
        final wetCode = (code >= 51 && code <= 67) ||
            (code >= 71 && code <= 77) ||
            (code >= 80 && code <= 82) ||
            (code >= 85 && code <= 86) ||
            code == 95 || code == 96 || code == 99;
        // 0.025 mm za 15 min ~= 0.1 mm/h. To uz povazujeme za
        // meratelny zrazkovy signal, no ignorujeme numericky sum.
        return amount >= 0.025 || wetCode;
      }

      int first = -1;
      for (int i = 0; i < t15.length; i++) {
        final intervalEnd = t15[i];
        if (intervalEnd.isBefore(now.subtract(const Duration(minutes: 5)))) {
          continue;
        }
        if (wetAt(i)) {
          first = i;
          break;
        }
      }

      if (first >= 0) {
        int last = first;
        int dryStreak = 0;
        double total = 0.0;
        double maxRate = 0.0;
        int peakIndex = first;

        // Jednu suchu 15-min medzeru vo vnutri pasma tolerujeme.
        for (int i = first; i < t15.length; i++) {
          final wet = wetAt(i);
          if (wet) {
            dryStreak = 0;
            last = i;
            final amount = i < p15.length ? p15[i] : 0.0;
            total += amount;
            final rate = amount * 4.0;
            if (rate > maxRate) {
              maxRate = rate;
              peakIndex = i;
            }
          } else {
            dryStreak++;
            if (dryStreak >= 2) break;
          }
        }

        // Hodnota 15-min zrazok je sucet predchadzajucich 15 minut.
        rainStartTime = t15[first].subtract(const Duration(minutes: 15));
        if (rainStartTime!.isBefore(now) &&
            now.difference(rainStartTime!).inMinutes <= 15) {
          rainStartTime = now;
        }
        rainEndTime = t15[last];
        rainPeakTime = t15[peakIndex].subtract(const Duration(minutes: 8));
        rainDurationMinutes = math.max(
          15,
          rainEndTime!.difference(rainStartTime!).inMinutes,
        );
        rainTotalAmount = total;
        rainPeakRate = maxRate;

        if (first < wd15.length) {
          rainArrivalWindDirection = wd15[first];
        }
        if (first < ws15.length) {
          rainArrivalWindSpeed = ws15[first];
        }

        // Toto NIE JE radarova vzdialenost bunky. Je to orientacny
        // prepocteny dosah z ETA a rychlosti prudenia pri prichode.
        // Preto sa v UI zobrazuje ako "orientacne".
        final etaMinutes = math.max(
          0,
          rainStartTime!.difference(now).inMinutes,
        );
        if (rainArrivalWindSpeed != null && rainArrivalWindSpeed! > 0) {
          rainEstimatedDistanceKm =
              rainArrivalWindSpeed! * (etaMinutes / 60.0);
        }

        // Detail 15-min dat je presnejsi pre cas zaciatku nez hodinovy
        // signal, preto nim prepiseme ETA, ak je epizoda v horizonte.
        nextRainTime = rainStartTime;
        nextRainMinutes = math.max(
          0,
          rainStartTime!.difference(now).inMinutes,
        );
        if (first < c15.length) {
          nextRainWeatherCode = c15[first];
        }
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

      rainStartTime:
          rainStartTime,

      rainPeakTime:
          rainPeakTime,

      rainEndTime:
          rainEndTime,

      rainDurationMinutes:
          rainDurationMinutes,

      rainTotalAmount:
          rainTotalAmount,

      rainPeakRate:
          rainPeakRate,

      rainArrivalWindDirection:
          rainArrivalWindDirection,

      rainArrivalWindSpeed:
          rainArrivalWindSpeed,

      rainEstimatedDistanceKm:
          rainEstimatedDistanceKm,

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
