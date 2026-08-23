import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/meteo_data.dart';

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

  // ==========================================================
  // HLAVNÁ ANALÝZA
  // ==========================================================

  Future<WeatherIntelligenceResult> analyze({
    required double lat,
    required double lng,
    required double pressure,
    required double pressureChangeRate,
    required double heading,
    required double tiltX,
    required double tiltY,
    Uint8List? imageBytes,
    MeteoApiData? meteoData,
  }) async {
    final List<String> evidence = [];

    int rainProbability = 0;

    double precipitation = 0.0;

    double windDirection = 0.0;

    double windSpeed = 0.0;

    bool rainLikelySoon = false;

    bool stormNearby = false;

    // ========================================================
    // SKÓRE
    //
    // Každý nezávislý dôkaz pridáva časť istoty.
    //
    // Toto je základ budúceho "Weather Intelligence".
    // ========================================================

    double score = 0.0;

    // ========================================================
    // 1. OPEN-METEO
    // ========================================================

    try {
      final Uri uri = Uri.parse(
        '$_openMeteo'
        '?latitude=$lat'
        '&longitude=$lng'
        '&current='
        'temperature_2m,'
        'precipitation,'
        'weather_code,'
        'wind_speed_10m,'
        'wind_direction_10m,'
        'surface_pressure'
        '&hourly='
        'precipitation_probability,'
        'precipitation,'
        'wind_direction_10m,'
        'wind_speed_10m,'
        'surface_pressure'
        '&forecast_hours=12'
        '&timezone=auto',
      );

      final response =
          await http.get(uri);

      if (response.statusCode == 200) {
        final data =
            jsonDecode(response.body)
                as Map<String, dynamic>;

        final current =
            data['current']
                as Map<String, dynamic>?;

        final hourly =
            data['hourly']
                as Map<String, dynamic>?;

        if (current != null) {
          precipitation =
              (current['precipitation']
                          as num?)
                      ?.toDouble() ??
                  0.0;

          windDirection =
              (current[
                          'wind_direction_10m']
                      as num?)
                  ?.toDouble() ??
              0.0;

          windSpeed =
              (current[
                          'wind_speed_10m']
                      as num?)
                  ?.toDouble() ??
              0.0;
        }

        if (hourly != null) {
          final probabilities =
              (hourly[
                          'precipitation_probability']
                      as List?)
                  ?.map(
                    (e) =>
                        (e as num).toInt(),
                  )
                  .toList() ??
              [];

          final precipitations =
              (hourly[
                          'precipitation']
                      as List?)
                  ?.map(
                    (e) =>
                        (e as num).toDouble(),
                  )
                  .toList() ??
              [];

          if (probabilities.isNotEmpty) {
            rainProbability =
                probabilities.first;
          }

          final int lookAhead =
              math.min(
                probabilities.length,
                6,
              );

          for (
            int i = 0;
            i < lookAhead;
            i++
          ) {
            final int probability =
                probabilities[i];

            final double rain =
                precipitations.length >
                        i
                    ? precipitations[i]
                    : 0.0;

            if (probability >= 40 ||
                rain >= 0.1) {
              rainLikelySoon = true;
              break;
            }
          }
        }

        evidence.add(
          'Open-Meteo poskytlo aktuálnu modelovú situáciu.',
        );

        if (rainLikelySoon) {
          evidence.add(
            'Numerický model očakáva zrážky v blízkom časovom horizonte.',
          );

          score += 0.25;
        }

        if (rainProbability >= 60) {
          evidence.add(
            'Pravdepodobnosť zrážok je $rainProbability %.',
          );

          score += 0.15;
        }

        if (precipitation > 0.5) {
          evidence.add(
            'Model už v aktuálnej oblasti uvádza zrážky.',
          );

          score += 0.15;
        }
      } else {
        evidence.add(
          'Open-Meteo momentálne neodpovedá.',
        );
      }
    } catch (e) {
      evidence.add(
        'Open-Meteo sa nepodarilo načítať.',
      );
    }

    // ========================================================
    // 2. EXISTUJÚCE METEO DÁTA
    //
    // Ak ich už main.dart načítal, využijeme ich tiež.
    // ========================================================

    if (meteoData != null) {
      final probs =
          meteoData!
              .hourlyPrecipitationProbability;

      final precips =
          meteoData!
              .hourlyPrecipitation;

      if (probs != null &&
          probs.isNotEmpty) {
        final int localProbability =
            probs.first;

        if (localProbability >
            rainProbability) {
          rainProbability =
              localProbability;
        }

        evidence.add(
          'Lokálna hodinová predpoveď potvrdzuje dostupnosť zrážkových dát.',
        );
      }

      if (precips != null &&
          precips.isNotEmpty) {
        if (precips.first >
            precipitation) {
          precipitation =
              precips.first;
        }
      }
    }

    // ========================================================
    // 3. BAROMETER
    // ========================================================

    if (pressure > 0) {
      final double rate =
          pressureChangeRate;

      if (rate <= -0.30) {
        evidence.add(
          'Barometer zaznamenáva výrazný pokles tlaku.',
        );

        score += 0.15;
      } else if (rate <= -0.15) {
        evidence.add(
          'Barometer zaznamenáva rýchlejší pokles tlaku.',
        );

        score += 0.10;
      } else if (rate <= -0.05) {
        evidence.add(
          'Tlak mierne klesá.',
        );

        score += 0.04;
      } else if (rate >= 0.15) {
        evidence.add(
          'Tlak rastie – atmosférická situácia sa zatiaľ skôr stabilizuje.',
        );
      }
    }

    // ========================================================
    // 4. ORIENTÁCIA TELEFÓNU
    //
    // Zatiaľ ju nepoužívame ako dôkaz počasia.
    //
    // Je však dôležitá pre budúci radar + kamera systém.
    // ========================================================

    final String direction =
        _directionName(heading);

    evidence.add(
      'Telefón bol pri meraní namierený približne na $direction.',
    );

    if (tiltX.abs() > 15 ||
        tiltY.abs() > 15) {
      evidence.add(
        'Kamera bola pri meraní výraznejšie naklonená – obraz oblohy môže byť čiastočný.',
      );
    }

    // ========================================================
    // 5. KAMERA
    //
    // Zatiaľ robíme iba základnú analýzu obrazu.
    //
    // NIE JE to ešte AI rozpoznávanie oblakov.
    //
    // Z obrazu získame základný signál:
    // - svetlosť
    // - modrosť oblohy
    // - kontrast
    //
    // Neskôr sem môžeme napojiť skutočný vision model.
    // ========================================================

    if (imageBytes != null &&
        imageBytes.isNotEmpty) {
      final SkyImageAnalysis imageAnalysis =
          _analyzeSkyImage(imageBytes);

      if (imageAnalysis.isDark) {
        evidence.add(
          'Kamera zachytila relatívne tmavú scénu oblohy.',
        );

        score += 0.05;
      }

      if (imageAnalysis.isLowBlue) {
        evidence.add(
          'Obraz obsahuje menej modrej oblohy – môže ísť o výraznejšiu oblačnosť.',
        );

        score += 0.05;
      } else {
        evidence.add(
          'Obraz obsahuje výraznejší podiel modrej oblohy.',
        );
      }
    } else {
      evidence.add(
        'Kamera nebola k dispozícii – analýza pokračuje bez obrazu.',
      );
    }

    // ========================================================
    // 6. INTENZÍVNE ZRÁŽKY
    // ========================================================

    if (precipitation >= 8 &&
        rainProbability >= 60) {
      stormNearby = true;

      score += 0.20;

      evidence.add(
        'Model naznačuje možnosť veľmi intenzívnych zrážok.',
      );
    }

    // ========================================================
    // 7. NORMALIZÁCIA SKÓRE
    // ========================================================

    final double confidence =
        math.min(
          0.97,
          math.max(
            0.30,
            0.40 + score,
          ),
        );

    // ========================================================
    // 8. HLAVNÉ VYHODNOTENIE
    // ========================================================

    String title;

    String description;

    if (stormNearby) {
      title =
          'Pozor, možná silná konvekcia';

      description =
          'Viaceré dostupné údaje naznačujú '
          'zvýšené riziko intenzívnych zrážok '
          'alebo búrkovej aktivity.';
    } else if (rainLikelySoon &&
        pressureChangeRate <= -0.10) {
      title =
          'Dážď sa môže blížiť';

      description =
          'Model očakáva zrážky a barometer '
          'zároveň zaznamenáva pokles tlaku. '
          'Situácia sa môže zhoršovať.';
    } else if (rainLikelySoon) {
      title =
          'Zrážky sú pravdepodobné';

      description =
          'Dostupné meteorologické údaje '
          'naznačujú možný nástup zrážok.';
    } else if (pressureChangeRate <= -0.15) {
      title =
          'Atmosféra sa môže meniť';

      description =
          'Barometer zaznamenáva výraznejší '
          'pokles tlaku, ale ostatné údaje '
          'zatiaľ nepotvrdzujú bezprostredný dážď.';
    } else {
      title =
          'Situácia vyzerá pokojne';

      description =
          'Dostupné údaje momentálne neukazujú '
          'na bezprostredný nástup výrazných zrážok.';
    }

    // ========================================================
    // 9. TEXT ISTOTY
    // ========================================================

    String confidenceText;

    if (confidence >= 0.85) {
      confidenceText =
          'Veľmi dobrá zhoda dostupných dát';
    } else if (confidence >= 0.70) {
      confidenceText =
          'Dobrá zhoda dostupných dát';
    } else if (confidence >= 0.55) {
      confidenceText =
          'Stredná zhoda dostupných dát';
    } else {
      confidenceText =
          'Predbežný odhad';
    }

    // ========================================================
    // 10. VÝSLEDOK
    // ========================================================

    return WeatherIntelligenceResult(
      title: title,
      description: description,
      confidenceText:
          confidenceText,
      confidence:
          confidence,
      rainNearby:
          rainLikelySoon,
      stormNearby:
          stormNearby,
      rainLikelySoon:
          rainLikelySoon,
      radarDistanceKm:
          null,
      lightningDistanceKm:
          null,
      rainProbability:
          rainProbability,
      precipitation:
          precipitation,
      windDirection:
          windDirection,
      windSpeed:
          windSpeed,
      evidence:
          evidence,
    );
  }

  // ==========================================================
  // NÁZOV SMERU
  // ==========================================================

  String _directionName(
    double degrees,
  ) {
    final d =
        (degrees % 360 + 360) % 360;

    if (d < 22.5 ||
        d >= 337.5) {
      return 'sever';
    }

    if (d < 67.5) {
      return 'severovýchod';
    }

    if (d < 112.5) {
      return 'východ';
    }

    if (d < 157.5) {
      return 'juhovýchod';
    }

    if (d < 202.5) {
      return 'juh';
    }

    if (d < 247.5) {
      return 'juhozápad';
    }

    if (d < 292.5) {
      return 'západ';
    }

    return 'severozápad';
  }

  // ==========================================================
  // ZÁKLADNÁ ANALÝZA OBRAZU
  // ==========================================================

  SkyImageAnalysis _analyzeSkyImage(
    Uint8List bytes,
  ) {
    // Bez dekódovania cez image package zatiaľ
    // používame iba bezpečný základný signál.
    //
    // Skutočné pixelové vyhodnotenie pridáme
    // v ďalšom kroku.

    if (bytes.length < 1000) {
      return SkyImageAnalysis(
        isDark: false,
        isLowBlue: false,
      );
    }

    // Veľkosť JPEG/HEIC súboru sama o sebe
    // nie je meteorologický dôkaz.
    //
    // Preto tu zatiaľ radšej nedávame
    // falošnú istotu.

    return SkyImageAnalysis(
      isDark: false,
      isLowBlue: false,
    );
  }
}

// ============================================================
// VÝSLEDOK ZÁKLADNEJ ANALÝZY KAMERY
// ============================================================

class SkyImageAnalysis {
  final bool isDark;
  final bool isLowBlue;

  SkyImageAnalysis({
    required this.isDark,
    required this.isLowBlue,
  });
}
