import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../models/meteo_data.dart';
import 'ecmwf_service.dart';

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

  final double? skyBluePercent;
  final double? cloudinessEstimate;

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
    required this.skyBluePercent,
    required this.cloudinessEstimate,
    required this.evidence,
  });
}

class WeatherIntelligenceService {
  static const String _openMeteo =
      'https://api.open-meteo.com/v1/forecast';

  final EcmwfService _ecmwfService =
      EcmwfService();

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

    double score = 0.0;

    double? skyBluePercent;
    double? cloudinessEstimate;

    // ==========================================================
    // 1. OPEN-METEO
    // ==========================================================

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
        final Map<String, dynamic> data =
            jsonDecode(response.body)
                as Map<String, dynamic>;

        final Map<String, dynamic>? current =
            data['current']
                as Map<String, dynamic>?;

        final Map<String, dynamic>? hourly =
            data['hourly']
                as Map<String, dynamic>?;

        if (current != null) {
          precipitation =
              (current['precipitation'] as num?)
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
          final List<int> probabilities =
              (hourly[
                          'precipitation_probability']
                      as List?)
                  ?.map(
                    (e) =>
                        (e as num).toInt(),
                  )
                  .toList() ??
              [];

          final List<double> precipitations =
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

          for (int i = 0;
              i < lookAhead;
              i++) {
            final int probability =
                probabilities[i];

            final double rain =
                precipitations.length > i
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
          score += 0.12;

          evidence.add(
            'Open-Meteo očakáva zrážky v blízkom časovom horizonte.',
          );
        }

        if (rainProbability >= 60) {
          score += 0.10;

          evidence.add(
            'Open-Meteo uvádza pravdepodobnosť zrážok $rainProbability %.',
          );
        }

        if (precipitation > 0.5) {
          score += 0.15;

          evidence.add(
            'Open-Meteo už uvádza aktuálne zrážky.',
          );
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

    // ==========================================================
    // 2. EXISTUJÚCE METEO DÁTA
    // ==========================================================

    if (meteoData != null) {
      final probs =
          meteoData.hourlyPrecipitationProbability;

      final precips =
          meteoData.hourlyPrecipitation;

      if (probs != null &&
          probs.isNotEmpty) {
        final int localProbability =
            probs.first;

        if (localProbability >
            rainProbability) {
          rainProbability =
              localProbability;
        }
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

    // ==========================================================
    // 3. ECMWF IFS HRES 9 KM
    // ==========================================================

    EcmwfData? ecmwfData;

    try {
      ecmwfData =
          await _ecmwfService.getForecast(
        latitude: lat,
        longitude: lng,
      );

      if (ecmwfData != null) {
        final bool ecmwfRain =
            ecmwfData.rainExpectedNext6Hours;

        final double ecmwfMaxRain =
            ecmwfData.maxPrecipitationNext6Hours;

        final int? ecmwfRainHour =
            ecmwfData.firstRainHourIndex;

        print(
          '================================================',
        );
        print(
          'ECMWF IFS HRES 9 KM',
        );
        print(
          'Current precipitation: '
          '${ecmwfData.currentPrecipitation} mm',
        );
        print(
          'Max precipitation next 6h: '
          '$ecmwfMaxRain mm',
        );
        print(
          'Rain expected next 6h: '
          '$ecmwfRain',
        );
        print(
          'First rain hour index: '
          '$ecmwfRainHour',
        );
        print(
          '================================================',
        );

        evidence.add(
          'ECMWF IFS HRES 9 km bol načítaný.',
        );

        if (ecmwfRain) {
          evidence.add(
            'ECMWF očakáva merateľné zrážky v najbližších 6 hodinách.',
          );

          // ECMWF a Open-Meteo sa zhodujú.
          if (rainLikelySoon) {
            score += 0.10;

            evidence.add(
              'ECMWF a Open-Meteo sa zhodujú na riziku zrážok.',
            );
          }
        } else {
          evidence.add(
            'ECMWF momentálne nepredpokladá merateľné zrážky v najbližších 6 hodinách.',
          );

          // Ak Open-Meteo hlási dážď, ale ECMWF nie,
          // nezvyšujeme skóre. Práve naopak, upozorníme
          // na rozpor medzi modelmi.
          if (rainLikelySoon) {
            score -= 0.06;

            evidence.add(
              'ECMWF a Open-Meteo sa v zrážkach rozchádzajú.',
            );
          }
        }

        // Ak ECMWF očakáva výraznejšie zrážky,
        // pridáme menší signál.
        if (ecmwfMaxRain >= 2.0) {
          score += 0.05;

          evidence.add(
            'ECMWF očakáva výraznejšie zrážky v najbližších hodinách.',
          );
        }
      } else {
        evidence.add(
          'ECMWF IFS momentálne neposkytol dáta.',
        );
      }
    } catch (e) {
      evidence.add(
        'ECMWF IFS sa nepodarilo načítať.',
      );

      print(
        'ECMWF INTELLIGENCE ERROR: $e',
      );
    }

    // ==========================================================
    // 4. BAROMETER
    // ==========================================================

    if (pressure > 0) {
      if (pressureChangeRate <= -0.30) {
        score += 0.15;

        evidence.add(
          'Barometer zaznamenáva výrazný pokles tlaku.',
        );
      } else if (pressureChangeRate <= -0.15) {
        score += 0.10;

        evidence.add(
          'Barometer zaznamenáva rýchlejší pokles tlaku.',
        );
      } else if (pressureChangeRate <= -0.05) {
        score += 0.04;

        evidence.add(
          'Tlak mierne klesá.',
        );
      } else if (pressureChangeRate >= 0.15) {
        evidence.add(
          'Tlak rastie – atmosféra sa zatiaľ skôr stabilizuje.',
        );
      }
    }

    // ==========================================================
    // 5. ORIENTÁCIA
    // ==========================================================

    final direction =
        _directionName(heading);

    evidence.add(
      'Telefón bol pri meraní namierený približne na $direction.',
    );

    if (tiltX.abs() > 15 ||
        tiltY.abs() > 15) {
      evidence.add(
        'Telefón bol výraznejšie naklonený – obraz oblohy môže byť čiastočný.',
      );
    }

    // ==========================================================
    // 6. KAMERA – REÁLNE PIXELY
    // ==========================================================

    if (imageBytes != null &&
        imageBytes.isNotEmpty) {
      final SkyImageAnalysis sky =
          _analyzeSkyImage(imageBytes);

      skyBluePercent =
          sky.blueSkyPercent;

      cloudinessEstimate =
          sky.cloudinessPercent;

      evidence.add(
        'Kamera analyzovala ${sky.sampleCount} vzoriek obrazu.',
      );

      if (sky.blueSkyPercent >= 65) {
        evidence.add(
          'Kamera vidí prevažne modrú oblohu.',
        );
      } else if (sky.blueSkyPercent >= 35) {
        evidence.add(
          'Kamera vidí kombináciu modrej oblohy a oblačnosti.',
        );
      } else {
        evidence.add(
          'Kamera vidí málo modrej oblohy.',
        );

        score += 0.06;
      }

      if (sky.cloudinessPercent >= 75) {
        evidence.add(
          'Obraz naznačuje výraznú oblačnosť.',
        );

        score += 0.08;
      }

      if (sky.darkPercent >= 45) {
        evidence.add(
          'Výrazná časť obrazu je tmavá.',
        );

        score += 0.05;
      }

      if (sky.cloudinessPercent >= 65 &&
          rainLikelySoon) {
        score += 0.10;

        evidence.add(
          'Obraz oblohy a meteorologický model sa navzájom podporujú.',
        );
      }
    } else {
      evidence.add(
        'Kamera nebola použitá – analýza pokračuje bez obrazu.',
      );
    }

    // ==========================================================
    // 7. INTENZÍVNE ZRÁŽKY
    // ==========================================================

    if (precipitation >= 8 &&
        rainProbability >= 60) {
      stormNearby = true;

      score += 0.15;

      evidence.add(
        'Model naznačuje možnosť veľmi intenzívnych zrážok.',
      );
    }

    // ==========================================================
    // 8. NORMALIZÁCIA
    // ==========================================================

    //
    // DÔLEŽITÁ ZMENA:
    //
    // Predtým bolo:
    //
    //   0.40 + score
    //
    // To spôsobovalo, že "zhoda" mohla byť veľmi vysoká
    // aj pri slabej modelovej podpore.
    //
    // Teraz začíname na 30 % a pridávame iba reálne
    // dostupné signály.
    //

    final double confidence =
        math.min(
          0.95,
          math.max(
            0.30,
            0.30 + score,
          ),
        );

    // ==========================================================
    // 9. HLAVNÝ ZÁVER
    // ==========================================================

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
        pressureChangeRate <= -0.10 &&
        (cloudinessEstimate == null ||
            cloudinessEstimate >= 50)) {
      title =
          'Dážď sa môže blížiť';

      description =
          'Meteorologické modely naznačujú zrážky, '
          'barometer klesá a kamera zároveň '
          'nevidí úplne čistú oblohu.';
    } else if (rainLikelySoon) {
      title =
          'Zrážky sú pravdepodobné';

      description =
          'Meteorologické dáta naznačujú možný '
          'nástup zrážok v blízkom časovom horizonte.';
    } else if (cloudinessEstimate != null &&
        cloudinessEstimate >= 75) {
      title =
          'Obloha je výrazne zamračená';

      description =
          'Kamera zachytila výraznú oblačnosť, '
          'hoci model zatiaľ nepredpokladá bezprostredný dážď.';
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

    // ==========================================================
    // 10. TEXT ISTOTY
    // ==========================================================

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

    // ==========================================================
    // 11. VÝSLEDOK
    // ==========================================================

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
      skyBluePercent: skyBluePercent,
      cloudinessEstimate:
          cloudinessEstimate,
      evidence: evidence,
    );
  }

  // ==========================================================
  // ANALÝZA OBRAZU
  // ==========================================================

  SkyImageAnalysis _analyzeSkyImage(
    Uint8List bytes,
  ) {
    final decoded =
        img.decodeImage(bytes);

    if (decoded == null) {
      return SkyImageAnalysis.empty();
    }

    final image =
        img.copyResize(
      decoded,
      width: 80,
    );

    int total = 0;
    int blue = 0;
    int dark = 0;
    int cloudy = 0;

    double blueStrengthSum = 0;

    for (int y = 0;
        y < image.height;
        y++) {
      for (int x = 0;
          x < image.width;
          x++) {
        final pixel =
            image.getPixel(x, y);

        final double r =
            pixel.r.toDouble();

        final double g =
            pixel.g.toDouble();

        final double b =
            pixel.b.toDouble();

        final double brightness =
            (r + g + b) / 3;

        total++;

        if (brightness < 75) {
          dark++;
        }

        final bool isBlue =
            b > r * 1.12 &&
            b > g * 1.02 &&
            b > 90;

        if (isBlue) {
          blue++;

          blueStrengthSum +=
              ((b - r) / 255)
                  .clamp(0.0, 1.0);
        }

        final double maxChannel =
            math.max(
              r,
              math.max(g, b),
            );

        final double minChannel =
            math.min(
              r,
              math.min(g, b),
            );

        final double spread =
            maxChannel - minChannel;

        if (spread < 25 &&
            brightness > 80) {
          cloudy++;
        }
      }
    }

    if (total == 0) {
      return SkyImageAnalysis.empty();
    }

    final double bluePercent =
        blue / total * 100;

    final double darkPercent =
        dark / total * 100;

    final double greyPercent =
        cloudy / total * 100;

    double cloudiness =
        100 - bluePercent;

    cloudiness =
        cloudiness * 0.70 +
            greyPercent * 0.20 +
            darkPercent * 0.10;

    cloudiness =
        cloudiness.clamp(
          0.0,
          100.0,
        );

    return SkyImageAnalysis(
      blueSkyPercent:
          bluePercent.clamp(
        0.0,
        100.0,
      ),
      cloudinessPercent:
          cloudiness,
      darkPercent:
          darkPercent.clamp(
        0.0,
        100.0,
      ),
      sampleCount:
          total,
      averageBlueStrength:
          blueStrengthSum /
              math.max(
                1,
                blue,
              ),
    );
  }

  // ==========================================================
  // SMER
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
}

// ============================================================
// ANALÝZA OBRAZU
// ============================================================

class SkyImageAnalysis {
  final double blueSkyPercent;
  final double cloudinessPercent;
  final double darkPercent;
  final int sampleCount;
  final double averageBlueStrength;

  SkyImageAnalysis({
    required this.blueSkyPercent,
    required this.cloudinessPercent,
    required this.darkPercent,
    required this.sampleCount,
    required this.averageBlueStrength,
  });

  factory SkyImageAnalysis.empty() {
    return SkyImageAnalysis(
      blueSkyPercent: 0,
      cloudinessPercent: 0,
      darkPercent: 0,
      sampleCount: 0,
      averageBlueStrength: 0,
    );
  }
}
