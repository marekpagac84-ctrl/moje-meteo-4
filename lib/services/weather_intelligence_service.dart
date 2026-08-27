import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../models/meteo_data.dart';
import 'cloud_classifier_service.dart';
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

  final String? cloudType;
  final String? cloudTypeShort;
  final double? cloudTypeConfidence;

  final double? ecmwfPrecipitation;
  final double? ecmwfMaxPrecipitation6h;
  final bool? ecmwfRainExpected;

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
    required this.cloudType,
    required this.cloudTypeShort,
    required this.cloudTypeConfidence,
    required this.ecmwfPrecipitation,
    required this.ecmwfMaxPrecipitation6h,
    required this.ecmwfRainExpected,
    required this.evidence,
  });
}

class WeatherIntelligenceService {
  static const String _openMeteo =
      'https://api.open-meteo.com/v1/forecast';

  final CloudClassifierService
      _cloudClassifier =
      CloudClassifierService();

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

    String? cloudType;

    String? cloudTypeShort;

    double? cloudTypeConfidence;

    double? ecmwfPrecipitation;

    double? ecmwfMaxPrecipitation6h;

    bool? ecmwfRainExpected;

    // ==========================================================
    // 1. OPEN-METEO
    // ==========================================================

    try {
      final uri = Uri.parse(
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
        final decoded =
            jsonDecode(response.body);

        if (decoded is Map) {
          final current =
              decoded['current'];

          final hourly =
              decoded['hourly'];

          if (current is Map) {
            precipitation =
                (current[
                            'precipitation']
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

          if (hourly is Map) {
            final probabilities =
                (hourly[
                            'precipitation_probability']
                        as List?)
                    ?.whereType<num>()
                    .map(
                      (e) => e.toInt(),
                    )
                    .toList() ??
                [];

            final precipitations =
                (hourly[
                            'precipitation']
                        as List?)
                    ?.whereType<num>()
                    .map(
                      (e) => e.toDouble(),
                    )
                    .toList() ??
                [];

            if (probabilities
                .isNotEmpty) {
              rainProbability =
                  probabilities.first;
            }

            final count =
                math.min(
              probabilities.length,
              6,
            );

            for (int i = 0;
                i < count;
                i++) {
              final probability =
                  probabilities[i];

              final rain =
                  precipitations.length >
                          i
                      ? precipitations[i]
                      : 0.0;

              if (probability >= 40 ||
                  rain >= 0.1) {
                rainLikelySoon =
                    true;
                break;
              }
            }
          }

          evidence.add(
            'Open-Meteo poskytlo aktuálnu modelovú situáciu.',
          );

          if (rainLikelySoon) {
            score += 0.14;

            evidence.add(
              'Open-Meteo očakáva možnosť zrážok v blízkom časovom horizonte.',
            );
          }

          if (rainProbability >= 60) {
            score += 0.10;

            evidence.add(
              'Open-Meteo uvádza pravdepodobnosť zrážok $rainProbability %.',
            );
          }

          if (precipitation > 0.5) {
            score += 0.12;

            evidence.add(
              'Open-Meteo uvádza aktuálne zrážky.',
            );
          }
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
    // 2. EXISTUJÚCE METEO DATA
    // ==========================================================

    if (meteoData != null) {
      final probs =
          meteoData
              .hourlyPrecipitationProbability;

      final precips =
          meteoData
              .hourlyPrecipitation;

      if (probs != null &&
          probs.isNotEmpty) {
        final localProbability =
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
    // 3. ECMWF IFS HRES
    // ==========================================================

    try {
      final ecmwf =
          await _ecmwfService
              .getForecast(
        latitude: lat,
        longitude: lng,
      );

      if (ecmwf != null) {
        ecmwfPrecipitation =
            ecmwf.currentPrecipitation;

        ecmwfMaxPrecipitation6h =
            ecmwf
                .maxPrecipitationNext6Hours;

        ecmwfRainExpected =
            ecmwf.rainExpectedNext6Hours;

        evidence.add(
          'ECMWF IFS HRES bol načítaný.',
        );

        if (ecmwfRainExpected ==
            true) {
          evidence.add(
            'ECMWF očakáva merateľné zrážky v najbližších 6 hodinách.',
          );

          if (rainLikelySoon) {
            score += 0.12;

            evidence.add(
              'ECMWF a Open-Meteo sa zhodujú na riziku zrážok.',
            );
          }
        } else {
          evidence.add(
            'ECMWF momentálne neočakáva merateľné zrážky v najbližších 6 hodinách.',
          );

          if (rainLikelySoon) {
            score -= 0.06;

            evidence.add(
              'ECMWF a Open-Meteo sa v zrážkach rozchádzajú.',
            );
          }
        }

        if (ecmwfMaxPrecipitation6h >=
            2.0) {
          score += 0.06;

          evidence.add(
            'ECMWF očakáva výraznejšie zrážky v najbližších hodinách.',
          );
        }
      } else {
        evidence.add(
          'ECMWF IFS neposkytol dáta.',
        );
      }
    } catch (e) {
      evidence.add(
        'ECMWF IFS sa nepodarilo načítať.',
      );
    }

    // ==========================================================
    // 4. BAROMETER
    // ==========================================================

    if (pressure > 0) {
      if (pressureChangeRate <=
          -0.30) {
        score += 0.12;

        evidence.add(
          'Barometer zaznamenáva výrazný pokles tlaku.',
        );
      } else if (pressureChangeRate <=
          -0.15) {
        score += 0.08;

        evidence.add(
          'Barometer zaznamenáva rýchlejší pokles tlaku.',
        );
      } else if (pressureChangeRate <=
          -0.05) {
        score += 0.03;

        evidence.add(
          'Tlak mierne klesá.',
        );
      } else if (pressureChangeRate >=
          0.15) {
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
    // 6. KAMERA – RGB ANALÝZA
    // ==========================================================

    if (imageBytes != null &&
        imageBytes.isNotEmpty) {
      final sky =
          _analyzeSkyImage(
        imageBytes,
      );

      skyBluePercent =
          sky.blueSkyPercent;

      cloudinessEstimate =
          sky.cloudinessPercent;

      evidence.add(
        'Kamera analyzovala ${sky.sampleCount} vzoriek obrazu.',
      );

      if (sky.blueSkyPercent >=
          65) {
        evidence.add(
          'Kamera vidí prevažne modrú oblohu.',
        );
      } else if (sky.blueSkyPercent >=
          35) {
        evidence.add(
          'Kamera vidí kombináciu modrej oblohy a oblačnosti.',
        );
      } else {
        evidence.add(
          'Kamera vidí málo modrej oblohy.',
        );

        score += 0.05;
      }

      if (sky.cloudinessPercent >=
          75) {
        score += 0.06;

        evidence.add(
          'Obraz naznačuje výraznú oblačnosť.',
        );
      }

      if (sky.darkPercent >=
          45) {
        score += 0.04;

        evidence.add(
          'Výrazná časť obrazu je tmavá.',
        );
      }

      if (sky.cloudinessPercent >=
              65 &&
          rainLikelySoon) {
        score += 0.08;

        evidence.add(
          'Obraz oblohy a meteorologický model sa navzájom podporujú.',
        );
      }

      // ========================================================
      // 7. AI ROZPOZNANIE OBLAKOV
      // ========================================================

      try {
        final cloud =
            await _cloudClassifier
                .classify(
          imageBytes,
        );

        if (cloud != null) {
          cloudType =
              cloud.name;

          cloudTypeShort =
              cloud.code;

          cloudTypeConfidence =
              cloud.confidence;

          evidence.add(
            'AI kamera rozpoznala '
            '${cloud.name} (${cloud.code}) '
            's istotou '
            '${(cloud.confidence * 100).toStringAsFixed(0)} %.',
          );

          // ------------------------------------------------------
          // CUMULONIMBUS
          // ------------------------------------------------------

          if (cloud.isCumulonimbus) {
            evidence.add(
              'AI identifikovala Cumulonimbus – '
              'mohutný konvektívny oblak spojený '
              's prehánkami, búrkami a možným krupobitím.',
            );

            if (cloud.confidence >=
                0.55) {
              score += 0.10;
            }

            if (cloud.confidence >=
                    0.65 &&
                (rainLikelySoon ||
                    ecmwfRainExpected ==
                        true)) {
              stormNearby = true;

              score += 0.12;

              evidence.add(
                'AI rozpoznanie Cumulonimbusu '
                'sa zhoduje s meteorologickými modelmi.',
              );
            }

            if (pressureChangeRate <=
                -0.10) {
              score += 0.05;

              evidence.add(
                'Cumulonimbus a pokles tlaku '
                'zvyšujú podozrenie na konvekciu.',
              );
            }
          }

          // ------------------------------------------------------
          // NIMBOSTRATUS
          // ------------------------------------------------------

          else if (cloud.isNimbostratus) {
            evidence.add(
              'AI identifikovala Nimbostratus – '
              'rozsiahlu dažďovú oblačnosť.',
            );

            if (cloud.confidence >=
                0.55) {
              score += 0.08;
            }

            if (rainLikelySoon) {
              score += 0.08;

              evidence.add(
                'Nimbostratus a model zrážok sa navzájom podporujú.',
              );
            }
          }

          // ------------------------------------------------------
          // ALTOSTRATUS
          // ------------------------------------------------------

          else if (cloud.code ==
              'As') {
            evidence.add(
              'AI identifikovala Altostratus – '
              'strednú súvislú oblačnosť, '
              'ktorá môže predchádzať zrážkovému systému.',
            );

            if (cloud.confidence >=
                0.60) {
              score += 0.03;
            }
          }

          // ------------------------------------------------------
          // STRATUS
          // ------------------------------------------------------

          else if (cloud.code ==
              'St') {
            evidence.add(
              'AI identifikovala Stratus – '
              'nízku súvislú oblačnosť.',
            );

            if (cloud.confidence >=
                0.60) {
              score += 0.02;
            }
          }

          // ------------------------------------------------------
          // STRATOCUMULUS
          // ------------------------------------------------------

          else if (cloud.code ==
              'Sc') {
            evidence.add(
              'AI identifikovala Stratocumulus – '
              'nízku až strednú oblačnosť.',
            );

            if (cloud.confidence >=
                0.60) {
              score += 0.01;
            }
          }

          // ------------------------------------------------------
          // CUMULUS
          // ------------------------------------------------------

          else if (cloud.code ==
              'Cu') {
            evidence.add(
              'AI identifikovala Cumulus – '
              'kupovitú oblačnosť.',
            );

            /*
             * Cumulus sám o sebe neznamená,
             * že bude pršať.
             */
          }

          // ------------------------------------------------------
          // VYSOKÁ OBLAČNOSŤ
          // ------------------------------------------------------

          else if (cloud.isHighCloud) {
            evidence.add(
              'AI identifikovala vysokú oblačnosť – '
              'sama o sebe neznamená bezprostredný dážď.',
            );
          }

          // ------------------------------------------------------
          // AI + MODEL
          // ------------------------------------------------------

          if (cloud.isRainCloud &&
              rainLikelySoon) {
            score += 0.10;

            evidence.add(
              'AI rozpoznanie oblakov a model zrážok sa zhodujú.',
            );
          }

          // ------------------------------------------------------
          // AI + ECMWF
          // ------------------------------------------------------

          if (cloud.isRainCloud &&
              ecmwfRainExpected ==
                  true) {
            score += 0.08;

            evidence.add(
              'AI rozpoznanie dažďového oblaku a ECMWF sa zhodujú.',
            );
          }
        } else {
          evidence.add(
            'AI rozpoznanie oblakov nebolo dostupné.',
          );
        }
      } catch (e) {
        evidence.add(
          'AI analýza oblakov zlyhala.',
        );

        print(
          'CLOUD AI INTELLIGENCE ERROR: $e',
        );
      }
    } else {
      evidence.add(
        'Kamera nebola použitá – analýza pokračuje bez obrazu.',
      );
    }

    // ==========================================================
    // 8. INTENZÍVNE ZRÁŽKY
    // ==========================================================

    if (precipitation >= 8 &&
        rainProbability >= 60) {
      stormNearby = true;

      score += 0.10;

      evidence.add(
        'Model naznačuje možnosť veľmi intenzívnych zrážok.',
      );
    }

    if (ecmwfMaxPrecipitation6h !=
            null &&
        ecmwfMaxPrecipitation6h! >=
            8.0) {
      stormNearby = true;

      score += 0.08;

      evidence.add(
        'ECMWF naznačuje výrazné zrážky v najbližších hodinách.',
      );
    }

    // ==========================================================
    // 9. NORMALIZÁCIA
    // ==========================================================

    /*
     * DÔLEŽITÉ:
     *
     * Už nepoužívame staré:
     *
     * 0.40 + score
     *
     * Pretože práve to mohlo vytvárať
     * umelo vysoké hodnoty typu 95 %.
     *
     * Začíname na 30 % a zvyšujeme iba
     * podľa skutočných signálov.
     */

    final confidence =
        math.min(
          0.95,
          math.max(
            0.30,
            0.30 + score,
          ),
        );

    // ==========================================================
    // 10. HLAVNÝ ZÁVER
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
        pressureChangeRate <=
            -0.10 &&
        (cloudinessEstimate == null ||
            cloudinessEstimate >=
                50)) {
      title =
          'Dážď sa môže blížiť';

      description =
          'Meteorologické modely naznačujú '
          'zrážky, tlak klesá a obraz oblohy '
          'nie je úplne čistý.';
    } else if (rainLikelySoon) {
      title =
          'Zrážky sú pravdepodobné';

      description =
          'Meteorologické dáta naznačujú možný '
          'nástup zrážok v blízkom časovom horizonte.';
    } else if (cloudTypeShort ==
            'Cb' &&
        (cloudTypeConfidence ??
                0.0) >=
            0.65) {
      title =
          'AI vidí búrkový oblak';

      description =
          'Kamera pomocou AI identifikovala '
          'Cumulonimbus. Modely zatiaľ nemusia '
          'potvrdzovať okamžité zrážky.';
    } else if (cloudinessEstimate !=
            null &&
        cloudinessEstimate! >=
            75) {
      title =
          'Obloha je výrazne zamračená';

      description =
          'Kamera zachytila výraznú oblačnosť, '
          'hoci model zatiaľ nepredpokladá '
          'bezprostredný dážď.';
    } else if (pressureChangeRate <=
        -0.15) {
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
    // 11. TEXT ISTOTY
    // ==========================================================

    String confidenceText;

    if (confidence >= 0.85) {
      confidenceText =
          'Veľmi dobrá zhoda dostupných dát';
    } else if (confidence >=
        0.70) {
      confidenceText =
          'Dobrá zhoda dostupných dát';
    } else if (confidence >=
        0.55) {
      confidenceText =
          'Stredná zhoda dostupných dát';
    } else {
      confidenceText =
          'Predbežný odhad';
    }

    // ==========================================================
    // 12. VÝSLEDOK
    // ==========================================================

    return WeatherIntelligenceResult(
      title: title,
      description: description,
      confidenceText:
          confidenceText,
      confidence: confidence,

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

      skyBluePercent:
          skyBluePercent,

      cloudinessEstimate:
          cloudinessEstimate,

      cloudType:
          cloudType,

      cloudTypeShort:
          cloudTypeShort,

      cloudTypeConfidence:
          cloudTypeConfidence,

      ecmwfPrecipitation:
          ecmwfPrecipitation,

      ecmwfMaxPrecipitation6h:
          ecmwfMaxPrecipitation6h,

      ecmwfRainExpected:
          ecmwfRainExpected,

      evidence:
          evidence,
    );
  }

  // ==========================================================
  // RGB ANALÝZA OBLOHY
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

    double blueStrengthSum =
        0.0;

    for (int y = 0;
        y < image.height;
        y++) {
      for (int x = 0;
          x < image.width;
          x++) {
        final pixel =
            image.getPixel(
          x,
          y,
        );

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
                  .clamp(
            0.0,
            1.0,
          );
        }

        final double maxChannel =
            math.max(
          r,
          math.max(
            g,
            b,
          ),
        );

        final double minChannel =
            math.min(
          r,
          math.min(
            g,
            b,
          ),
        );

        final double spread =
            maxChannel -
                minChannel;

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
      blueSkyPercent: 0.0,
      cloudinessPercent: 0.0,
      darkPercent: 0.0,
      sampleCount: 0,
      averageBlueStrength: 0.0,
    );
  }
}
