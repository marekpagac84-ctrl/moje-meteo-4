import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

class WeatherIntelligenceResult {
  final String title;
  final String description;
  final String confidenceText;

  final double confidence;

  final bool rainNearby;
  final bool stormNearby;
  final bool rainLikelySoon;

  final double? radarDistanceKm;
  final double? lightningDistanceKm;

  final int? rainProbability;
  final double? precipitation;

  final double? windDirection;
  final double? windSpeed;

  final List<String> evidence;

  WeatherIntelligenceResult({
    required this.title,
    required this.description,
    required this.confidenceText,
    required this.confidence,
    required this.rainNearby,
    required this.stormNearby,
    required this.rainLikelySoon,
    required this.radarDistanceKm,
    required this.lightningDistanceKm,
    required this.rainProbability,
    required this.precipitation,
    required this.windDirection,
    required this.windSpeed,
    required this.evidence,
  });
}

class WeatherIntelligenceService {
  static const String _openMeteo =
      'https://api.open-meteo.com/v1/forecast';

  // ----------------------------------------------------------
  // HLAVNÉ VYHODNOTENIE
  // ----------------------------------------------------------

  Future<WeatherIntelligenceResult> analyze({
    required double lat,
    required double lng,
    required double pressure,
    required double pressureChangeRate,
    required double heading,
    required double tiltX,
    required double tiltY,
  }) async {
    final evidence = <String>[];

    int rainProbability = 0;
    double precipitation = 0.0;
    double windDirection = 0.0;
    double windSpeed = 0.0;

    bool rainLikelySoon = false;

    // --------------------------------------------------------
    // 1. OPEN-METEO
    // --------------------------------------------------------

    try {
      final uri = Uri.parse(
        '$_openMeteo'
        '?latitude=$lat'
        '&longitude=$lng'
        '&current=temperature_2m,precipitation,'
        'weather_code,wind_speed_10m,wind_direction_10m,'
        'surface_pressure'
        '&hourly=precipitation_probability,'
        'precipitation,wind_direction_10m,'
        'wind_speed_10m'
        '&forecast_hours=12'
        '&timezone=auto',
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data =
            jsonDecode(response.body) as Map<String, dynamic>;

        final hourly =
            data['hourly'] as Map<String, dynamic>?;

        final current =
            data['current'] as Map<String, dynamic>?;

        if (current != null) {
          precipitation =
              (current['precipitation'] as num?)?.toDouble() ?? 0.0;

          windDirection =
              (current['wind_direction_10m'] as num?)
                      ?.toDouble() ??
                  0.0;

          windSpeed =
              (current['wind_speed_10m'] as num?)
                      ?.toDouble() ??
                  0.0;
        }

        if (hourly != null) {
          final probabilities =
              (hourly['precipitation_probability']
                          as List?)
                      ?.map(
                        (e) => (e as num).toInt(),
                      )
                      .toList() ??
                  [];

          final precipitations =
              (hourly['precipitation'] as List?)
                      ?.map(
                        (e) => (e as num).toDouble(),
                      )
                      .toList() ??
                  [];

          if (probabilities.isNotEmpty) {
            rainProbability = probabilities.first;
          }

          final int maxLookAhead =
              math.min(
                probabilities.length,
                6,
              );

          for (int i = 0; i < maxLookAhead; i++) {
            final probability =
                probabilities[i];

            final rain =
                precipitations.length > i
                    ? precipitations[i]
                    : 0.0;

            if (probability >= 40 ||
                rain >= 0.1) {
              rainLikelySoon = true;
              break;
            }
          }

          if (rainLikelySoon) {
            evidence.add(
              'Model očakáva zrážky v najbližších hodinách.',
            );
          }
        }
      }
    } catch (e) {
      evidence.add(
        'Niektoré online meteorologické dáta sa nepodarilo načítať.',
      );
    }

    // --------------------------------------------------------
    // 2. BAROMETER
    // --------------------------------------------------------

    if (pressure > 0) {
      final rate = pressureChangeRate;

      if (rate <= -0.15) {
        evidence.add(
          'Tlak rýchlo klesá.',
        );
      } else if (rate <= -0.05) {
        evidence.add(
          'Tlak mierne klesá.',
        );
      } else if (rate >= 0.15) {
        evidence.add(
          'Tlak rastie.',
        );
      }
    }

    // --------------------------------------------------------
    // 3. VYHODNOTENIE
    // --------------------------------------------------------

    double score = 0.0;

    if (rainLikelySoon) {
      score += 0.30;
    }

    if (rainProbability >= 60) {
      score += 0.20;
    }

    if (precipitation > 0.5) {
      score += 0.20;
    }

    if (pressureChangeRate <= -0.15) {
      score += 0.15;
    }

    if (pressureChangeRate <= -0.30) {
      score += 0.10;
    }

    // --------------------------------------------------------
    // 4. BÚRKA – zatiaľ konzervatívne
    //
    // Blitzortung napojíme ako ďalší zdroj neskôr.
    // Nechceme tvrdiť "búrka", keď máme iba model.
    // --------------------------------------------------------

    bool stormNearby = false;

    if (precipitation >= 8 &&
        rainProbability >= 60) {
      stormNearby = true;
      score += 0.20;

      evidence.add(
        'Model naznačuje možnosť intenzívnej konvekcie.',
      );
    }

    // --------------------------------------------------------
    // 5. TEXT
    // --------------------------------------------------------

    String title;
    String description;

    if (stormNearby) {
      title = 'Pozor, môže sa blížiť búrka';

      description =
          'Dáta naznačujú zvýšené riziko silných zrážok '
          'alebo búrkovej aktivity.';
    } else if (rainLikelySoon &&
        pressureChangeRate <= -0.10) {
      title = 'Dážď sa môže blížiť';

      description =
          'Model očakáva zrážky a zároveň pozorujeme '
          'pokles tlaku. Situácia sa môže zhoršovať.';
    } else if (rainLikelySoon) {
      title = 'Zrážky sú pravdepodobné';

      description =
          'Online predpoveď očakáva zrážky v blízkom '
          'časovom horizonte.';
    } else if (pressureChangeRate <= -0.15) {
      title = 'Počasie sa môže meniť';

      description =
          'Barometer zaznamenáva výraznejší pokles tlaku, '
          'ale zatiaľ nemáme dostatok ďalších signálov.';
    } else {
      title = 'Situácia vyzerá pokojne';

      description =
          'Dostupné údaje momentálne neukazujú na '
          'bezprostredný nástup výrazných zrážok.';
    }

    // --------------------------------------------------------
    // 6. CONFIDENCE
    // --------------------------------------------------------

    final confidence =
        math.min(
          0.95,
          math.max(
            0.35,
            0.45 + score,
          ),
        );

    String confidenceText;

    if (confidence >= 0.80) {
      confidenceText = 'Vysoká zhoda dát';
    } else if (confidence >= 0.65) {
      confidenceText = 'Dobrá zhoda dát';
    } else {
      confidenceText = 'Predbežný odhad';
    }

    return WeatherIntelligenceResult(
      title: title,
      description: description,
      confidenceText: confidenceText,
      confidence: confidence,
      rainNearby: rainLikelySoon,
      stormNearby: stormNearby,
      rainLikelySoon: rainLikelySoon,
      radarDistanceKm: null,
      lightningDistanceKm: null,
      rainProbability: rainProbability,
      precipitation: precipitation,
      windDirection: windDirection,
      windSpeed: windSpeed,
      evidence: evidence,
    );
  }
}
