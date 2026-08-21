import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:sensors_plus/sensors_plus.dart';

class SkyAnalyzerWidget extends StatefulWidget {
  const SkyAnalyzerWidget({super.key});

  @override
  State<SkyAnalyzerWidget> createState() =>
      _SkyAnalyzerWidgetState();
}

class _SkyAnalyzerWidgetState
    extends State<SkyAnalyzerWidget> {
  CameraController? _controller;

  StreamSubscription<BarometerEvent>? _pressureSubscription;
  StreamSubscription<UserAccelerometerEvent>?
      _accelerometerSubscription;

  bool _isInitializing = true;
  bool _isAnalyzing = false;
  bool _weatherLoading = false;

  String? _error;

  int _capturedFrames = 0;

  final List<XFile> _capturedImages = [];

  // ------------------------------------------------------------
  // KAMERA
  // ------------------------------------------------------------

  double _cloudCoverage = 0.0;
  double _blueSky = 0.0;
  double _brightness = 0.0;
  double _darkClouds = 0.0;
  double _cloudChange = 0.0;

  // ------------------------------------------------------------
  // BAROMETER
  // ------------------------------------------------------------

  double? _pressureStart;
  double? _pressureEnd;
  double _pressureChange = 0.0;

  bool _phoneWasMoving = false;

  // ------------------------------------------------------------
  // GPS / METEO
  // ------------------------------------------------------------

  double? _latitude;
  double? _longitude;

  double? _apiTemperature;
  double? _apiPressure;
  double? _apiCloudCover;
  double? _apiPrecipitation;
  double? _apiPrecipitationProbability;

  int? _apiWeatherCode;

  double? _nextRainProbability;
  double? _nextCloudCover;

  // ------------------------------------------------------------
  // VÝSLEDOK
  // ------------------------------------------------------------

  String _weatherResult =
      'Čakám na analýzu';

  String _weatherDescription = '';

  @override
  void initState() {
    super.initState();

    _initializeCamera();
    _initializeSensors();
    _initializeLocation();
  }

  // ============================================================
  // KAMERA
  // ============================================================

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        if (!mounted) return;

        setState(() {
          _error =
              'Zariadenie nemá dostupnú kameru.';
          _isInitializing = false;
        });

        return;
      }

      CameraDescription? selectedCamera;

      for (final camera in cameras) {
        if (camera.lensDirection ==
            CameraLensDirection.back) {
          selectedCamera = camera;
          break;
        }
      }

      selectedCamera ??= cameras.first;

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            'Kameru sa nepodarilo spustiť: $e';
        _isInitializing = false;
      });
    }
  }

  // ============================================================
  // SENZORY
  // ============================================================

  void _initializeSensors() {
    // ----------------------------------------------------------
    // BAROMETER
    // ----------------------------------------------------------

    try {
      _pressureSubscription =
          barometerEventStream().listen(
        (event) {
          if (!mounted) return;

          final pressure = event.pressure;

          if (pressure <= 0) return;

          if (_isAnalyzing) {
            if (_pressureStart == null) {
              _pressureStart = pressure;
            }

            _pressureEnd = pressure;

            if (_pressureStart != null) {
              _pressureChange =
                  pressure - _pressureStart!;
            }
          }
        },
        onError: (error) {
          debugPrint(
            'Barometer error: $error',
          );
        },
      );
    } catch (e) {
      debugPrint(
        'Barometer unavailable: $e',
      );
    }

    // ----------------------------------------------------------
    // AKCELEROMETER
    // ----------------------------------------------------------

    try {
      _accelerometerSubscription =
          userAccelerometerEventStream().listen(
        (event) {
          final motion =
              event.x.abs() +
              event.y.abs() +
              event.z.abs();

          final moving = motion > 3.0;

          if (mounted && moving) {
            _phoneWasMoving = true;
          }
        },
        onError: (error) {
          debugPrint(
            'Accelerometer error: $error',
          );
        },
      );
    } catch (e) {
      debugPrint(
        'Accelerometer unavailable: $e',
      );
    }
  }

  // ============================================================
  // GPS
  // ============================================================

  Future<void> _initializeLocation() async {
    try {
      final enabled =
          await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        return;
      }

      var permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission ==
              LocationPermission.whileInUse ||
          permission ==
              LocationPermission.always) {
        final position =
            await Geolocator.getCurrentPosition(
          desiredAccuracy:
              LocationAccuracy.high,
        );

        if (!mounted) return;

        setState(() {
          _latitude =
              position.latitude;
          _longitude =
              position.longitude;
        });
      }
    } catch (e) {
      debugPrint(
        'GPS error: $e',
      );
    }
  }

  // ============================================================
  // OPEN-METEO
  // ============================================================

  Future<void> _loadWeatherForecast() async {
    if (_latitude == null ||
        _longitude == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _weatherLoading = true;
      });
    }

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$_latitude'
        '&longitude=$_longitude'
        '&current=temperature_2m,'
        'relative_humidity_2m,'
        'precipitation,'
        'weather_code,'
        'cloud_cover,'
        'surface_pressure'
        '&hourly=precipitation_probability,'
        'precipitation,'
        'cloud_cover,'
        'weather_code,'
        'surface_pressure'
        '&forecast_hours=6'
        '&timezone=auto',
      );

      final response =
          await http.get(url);

      if (response.statusCode != 200) {
        throw Exception(
          'HTTP ${response.statusCode}',
        );
      }

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(
        Uri.decodeFull(
          response.body,
        ).isEmpty
            ? {}
            : _decodeJson(response.body),
      );

      final current =
          data['current'] as Map<String, dynamic>?;

      final hourly =
          data['hourly'] as Map<String, dynamic>?;

      if (current == null) {
        throw Exception(
          'Chýbajú aktuálne údaje.',
        );
      }

      final temperature =
          _toDouble(
        current['temperature_2m'],
      );

      final pressure =
          _toDouble(
        current['surface_pressure'],
      );

      final cloud =
          _toDouble(
        current['cloud_cover'],
      );

      final precipitation =
          _toDouble(
        current['precipitation'],
      );

      final probability =
          _toDouble(
        hourly?['precipitation_probability']
            is List &&
            (hourly?[
                    'precipitation_probability']
                as List)
                .isNotEmpty
            ? (hourly![
                    'precipitation_probability']
                as List)
                .first
            : null,
      );

      double? nextProbability;

      double? nextCloud;

      if (hourly != null) {
        final probabilities =
            hourly[
                'precipitation_probability'];

        final clouds =
            hourly['cloud_cover'];

        if (probabilities is List &&
            probabilities.isNotEmpty) {
          final values =
              probabilities
                  .take(
                    math.min(
                      3,
                      probabilities.length,
                    ),
                  )
                  .map(
                    (e) =>
                        _toDouble(e) ?? 0.0,
                  )
                  .toList();

          if (values.isNotEmpty) {
            nextProbability =
                values.reduce(
                      (a, b) =>
                          a > b ? a : b,
                    );
          }
        }

        if (clouds is List &&
            clouds.isNotEmpty) {
          final values =
              clouds
                  .take(
                    math.min(
                      3,
                      clouds.length,
                    ),
                  )
                  .map(
                    (e) =>
                        _toDouble(e) ?? 0.0,
                  )
                  .toList();

          if (values.isNotEmpty) {
            nextCloud =
                values.reduce(
                      (a, b) =>
                          a + b,
                    ) /
                    values.length;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _apiTemperature =
            temperature;

        _apiPressure =
            pressure;

        _apiCloudCover =
            cloud;

        _apiPrecipitation =
            precipitation;

        _apiPrecipitationProbability =
            probability;

        _nextRainProbability =
            nextProbability;

        _nextCloudCover =
            nextCloud;

        _apiWeatherCode =
            _toInt(
          current['weather_code'],
        );

        _weatherLoading = false;
      });
    } catch (e) {
      debugPrint(
        'Open-Meteo error: $e',
      );

      if (!mounted) return;

      setState(() {
        _weatherLoading = false;
      });
    }
  }

  Map<String, dynamic> _decodeJson(
    String source,
  ) {
    // Jednoduchý parser bez ďalšej dependency.
    // Používa sa dart:convert cez lokálnu implementáciu
    // nižšie.
    return jsonDecode(source)
        as Map<String, dynamic>;
  }

  double? _toDouble(
    dynamic value,
  ) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  int? _toInt(
    dynamic value,
  ) {
    if (value == null) return null;

    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }

  // ============================================================
  // HLAVNÁ ANALÝZA
  // ============================================================

  Future<void> _analyzeSky() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _isAnalyzing) {
      return;
    }

    setState(() {
      _isAnalyzing = true;

      _capturedFrames = 0;

      _capturedImages.clear();

      _cloudCoverage = 0.0;
      _blueSky = 0.0;
      _brightness = 0.0;
      _darkClouds = 0.0;
      _cloudChange = 0.0;

      _pressureStart = null;
      _pressureEnd = null;
      _pressureChange = 0.0;

      _phoneWasMoving = false;

      _weatherResult =
          'Analyzujem...';

      _weatherDescription = '';

      _error = null;
    });

    try {
      // Načítame meteodata súčasne s kamerovou analýzou.
      await _loadWeatherForecast();

      // --------------------------------------------------------
      // 10 SEKÚND
      // --------------------------------------------------------

      for (int i = 0; i < 10; i++) {
        if (!mounted) return;

        final image =
            await controller.takePicture();

        _capturedImages.add(image);

        if (mounted) {
          setState(() {
            _capturedFrames++;
          });
        }

        if (i < 9) {
          await Future.delayed(
            const Duration(seconds: 1),
          );
        }
      }

      // --------------------------------------------------------
      // SPRACOVANIE OBRÁZKOV
      // --------------------------------------------------------

      await _processImages();

      if (!mounted) return;

      // --------------------------------------------------------
      // VÝPOČET KOMBINOVANÉHO VÝSLEDKU
      // --------------------------------------------------------

      _calculateCombinedWeatherResult();

      // --------------------------------------------------------
      // OKAMŽITÉ ZMAZANIE FOTIEK
      // --------------------------------------------------------

      await _deleteCapturedImages();

      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
      });

      _showAnalysisResult();
    } catch (e) {
      await _deleteCapturedImages();

      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;

        _error =
            'Analýza oblohy zlyhala: $e';
      });
    }
  }

  // ============================================================
  // SPRACOVANIE OBRÁZKOV
  // ============================================================

  Future<void> _processImages() async {
    if (_capturedImages.isEmpty) {
      throw Exception(
        'Neboli nasnímané žiadne obrázky.',
      );
    }

    double totalCloud = 0.0;
    double totalBlue = 0.0;
    double totalBrightness = 0.0;
    double totalDark = 0.0;

    final List<double> cloudValues = [];

    int validImages = 0;

    for (final cameraImage
        in _capturedImages) {
      try {
        final Uint8List bytes =
            await cameraImage.readAsBytes();

        final decoded =
            img.decodeImage(bytes);

        if (decoded == null) {
          continue;
        }

        final analysis =
            await _analyzeImage(decoded);

        totalCloud +=
            analysis.cloudCoverage;

        totalBlue +=
            analysis.blueSky;

        totalBrightness +=
            analysis.brightness;

        totalDark +=
            analysis.darkClouds;

        cloudValues.add(
          analysis.cloudCoverage,
        );

        validImages++;
      } catch (e) {
        debugPrint(
          'Chyba pri analýze obrázka: $e',
        );
      }
    }

    if (validImages == 0) {
      throw Exception(
        'Nepodarilo sa spracovať žiadnu snímku.',
      );
    }

    final cloud =
        totalCloud / validImages;

    final blue =
        totalBlue / validImages;

    final brightness =
        totalBrightness / validImages;

    final dark =
        totalDark / validImages;

    double cloudChange = 0.0;

    if (cloudValues.length >= 2) {
      cloudChange =
          cloudValues.last -
          cloudValues.first;
    }

    if (!mounted) return;

    setState(() {
      _cloudCoverage = cloud;
      _blueSky = blue;
      _brightness = brightness;
      _darkClouds = dark;
      _cloudChange = cloudChange;
    });
  }

  // ============================================================
  // ANALÝZA JEDNÉHO OBRÁZKA
  // ============================================================

  Future<_SkyAnalysis> _analyzeImage(
    img.Image image,
  ) async {
    int cloudPixels = 0;
    int bluePixels = 0;
    int darkPixels = 0;

    double brightnessSum = 0.0;

    int samples = 0;

    for (
      int y = 0;
      y < image.height;
      y += 8
    ) {
      for (
        int x = 0;
        x < image.width;
        x += 8
      ) {
        final pixel =
            image.getPixel(x, y);

        final double r =
            pixel.r.toDouble();

        final double g =
            pixel.g.toDouble();

        final double b =
            pixel.b.toDouble();

        final double maxValue =
            math.max(
              r,
              math.max(g, b),
            );

        final double minValue =
            math.min(
              r,
              math.min(g, b),
            );

        final double brightness =
            (r + g + b) / 3.0;

        final double saturation =
            maxValue == 0
                ? 0.0
                : (maxValue -
                        minValue) /
                    maxValue;

        brightnessSum +=
            brightness;

        // ------------------------------------------------------
        // MODRÁ OBLOHA
        // ------------------------------------------------------

        final bool isBlue =
            b > r * 1.15 &&
            b > g * 1.05 &&
            saturation > 0.12 &&
            brightness > 60;

        // ------------------------------------------------------
        // OBLAČNOSŤ
        // ------------------------------------------------------

        final bool isCloud =
            saturation < 0.18 &&
            brightness > 90;

        // ------------------------------------------------------
        // TMAVÉ OBLASTI
        // ------------------------------------------------------

        final bool isDark =
            brightness < 75;

        if (isBlue) {
          bluePixels++;
        }

        if (isCloud) {
          cloudPixels++;
        }

        if (isDark) {
          darkPixels++;
        }

        samples++;
      }
    }

    if (samples == 0) {
      return const _SkyAnalysis(
        cloudCoverage: 0.0,
        blueSky: 0.0,
        brightness: 0.0,
        darkClouds: 0.0,
      );
    }

    return _SkyAnalysis(
      cloudCoverage:
          cloudPixels /
              samples *
              100.0,
      blueSky:
          bluePixels /
              samples *
              100.0,
      brightness:
          brightnessSum /
              samples,
      darkClouds:
          darkPixels /
              samples *
              100.0,
    );
  }

  // ============================================================
  // KOMBINOVANÁ METEO ANALÝZA
  // ============================================================

  void _calculateCombinedWeatherResult() {
    final cameraCloud =
        _cloudCoverage;

    final cameraBlue =
        _blueSky;

    final dark =
        _darkClouds;

    final brightness =
        _brightness;

    final apiCloud =
        _apiCloudCover;

    final rainProbability =
        _nextRainProbability ??
        _apiPrecipitationProbability;

    // ----------------------------------------------------------
    // KOMBINOVANÁ OBLAČNOSŤ
    // ----------------------------------------------------------

    double combinedCloud =
        cameraCloud;

    if (apiCloud != null) {
      // Kamera má väčšiu váhu, pretože ukazuje
      // skutočnú oblohu priamo nad telefónom.
      combinedCloud =
          cameraCloud * 0.65 +
          apiCloud * 0.35;
    }

    // ----------------------------------------------------------
    // TLAK
    // ----------------------------------------------------------

    final pressureFalling =
        _pressureChange < -0.5;

    final pressureStronglyFalling =
        _pressureChange < -1.5;

    // ----------------------------------------------------------
    // PRAVDEPODOBNOSŤ DAŽĎA
    // ----------------------------------------------------------

    final rainLikely =
        rainProbability != null &&
        rainProbability >= 50;

    final rainVeryLikely =
        rainProbability != null &&
        rainProbability >= 70;

    // ----------------------------------------------------------
    // HLAVNÝ VÝSLEDOK
    // ----------------------------------------------------------

    if (rainVeryLikely &&
        (combinedCloud > 60 ||
            dark > 25)) {
      _weatherResult =
          '🌧️ Pravdepodobný dážď';

      _weatherDescription =
          'Kamera zachytila výraznú oblačnosť '
          'a meteopredpoveď zároveň uvádza '
          'vyššiu pravdepodobnosť zrážok.';
    } else if (rainLikely &&
        combinedCloud > 55) {
      _weatherResult =
          '🌦️ Možné zrážky';

      _weatherDescription =
          'Obloha vykazuje výraznú oblačnosť '
          'a predpoveď naznačuje možnosť '
          'zrážok v najbližších hodinách.';
    } else if (dark > 35 &&
        combinedCloud > 50 &&
        pressureStronglyFalling) {
      _weatherResult =
          '⛈️ Zhoršovanie počasia';

      _weatherDescription =
          'Kamera zachytila tmavú oblačnosť, '
          'tlak klesá a stav oblohy môže '
          'naznačovať príchod zhoršenia.';
    } else if (combinedCloud > 75) {
      _weatherResult =
          '☁️ Zamračené';

      _weatherDescription =
          'Kamera aj meteodata ukazujú '
          'vysokú mieru oblačnosti.';
    } else if (combinedCloud > 50) {
      _weatherResult =
          '⛅ Polooblačno';

      _weatherDescription =
          'Pozorovanie ukazuje značnú '
          'oblačnosť, ale časť oblohy '
          'zostáva jasná.';
    } else if (cameraBlue > 45 &&
        combinedCloud < 40) {
      _weatherResult =
          '☀️ Jasná obloha';

      _weatherDescription =
          'Kamera zachytila veľké množstvo '
          'modrej oblohy a nízku oblačnosť.';
    } else if (brightness < 80) {
      _weatherResult =
          '🌥️ Tmavá obloha';

      _weatherDescription =
          'Obloha je výrazne tmavá. '
          'Môže ísť o hustú oblačnosť '
          'alebo slabé svetelné podmienky.';
    } else {
      _weatherResult =
          '🌤️ Premenlivá obloha';

      _weatherDescription =
          'Pozorovanie neposkytlo jednoznačný '
          'výsledok.';
    }

    // ----------------------------------------------------------
    // DYNAMIKA OBLAČNOSTI
    // ----------------------------------------------------------

    if (_cloudChange > 15) {
      _weatherDescription +=
          ' Počas 10 sekúnd sa oblačnosť '
          'výrazne zvýšila.';
    } else if (_cloudChange < -15) {
      _weatherDescription +=
          ' Počas snímania sa oblačnosť '
          'znižovala.';
    } else {
      _weatherDescription +=
          ' Oblačnosť bola počas merania '
          'relatívne stabilná.';
    }

    // ----------------------------------------------------------
    // TLAK
    // ----------------------------------------------------------

    if (!_phoneWasMoving &&
        pressureFalling) {
      _weatherDescription +=
          ' Barometer zároveň zaznamenal '
          'pokles tlaku.';
    } else if (_phoneWasMoving) {
      _weatherDescription +=
          ' Meranie tlaku môže byť ovplyvnené '
          'pohybom telefónu.';
    }
  }

  // ============================================================
  // ZMAZANIE FOTOGRAFIÍ
  // ============================================================

  Future<void> _deleteCapturedImages() async {
    for (final image
        in List<XFile>.from(
      _capturedImages,
    )) {
      try {
        await image.delete();
      } catch (e) {
        debugPrint(
          'Nepodarilo sa vymazať snímku: $e',
        );
      }
    }

    _capturedImages.clear();
  }

  // ============================================================
  // VÝSLEDOK
  // ============================================================

  void _showAnalysisResult() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          const Color(0xFF1E293B),
      isScrollControlled: true,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding:
              const EdgeInsets.all(24),
          child:
              SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud,
                  size: 55,
                  color:
                      Colors.blueAccent,
                ),

                const SizedBox(height: 12),

                const Text(
                  'VÝSLEDOK ANALÝZY',
                  style:
                      TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  _weatherResult,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  _weatherDescription,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 24),

                _buildResultRow(
                  '☁️ Kamera – oblačnosť',
                  '${_cloudCoverage.toStringAsFixed(0)} %',
                ),

                _buildResultRow(
                  '🔵 Modrá obloha',
                  '${_blueSky.toStringAsFixed(0)} %',
                ),

                _buildResultRow(
                  '🌑 Tmavé oblasti',
                  '${_darkClouds.toStringAsFixed(0)} %',
                ),

                _buildResultRow(
                  '💡 Jas',
                  '${_brightness.toStringAsFixed(0)} / 255',
                ),

                _buildResultRow(
                  '📈 Zmena oblačnosti',
                  '${_cloudChange >= 0 ? '+' : ''}'
                  '${_cloudChange.toStringAsFixed(0)} %',
                ),

                const Divider(
                  height: 28,
                  color: Colors.white12,
                ),

                _buildResultRow(
                  '🌦️ Predpoveď – oblačnosť',
                  _apiCloudCover != null
                      ? '${_apiCloudCover!.toStringAsFixed(0)} %'
                      : 'N/A',
                ),

                _buildResultRow(
                  '🌧️ Zrážky',
                  _nextRainProbability != null
                      ? '${_nextRainProbability!.toStringAsFixed(0)} %'
                      : 'N/A',
                ),

                _buildResultRow(
                  '🌧️ Aktuálne zrážky',
                  _apiPrecipitation != null
                      ? '${_apiPrecipitation!.toStringAsFixed(1)} mm'
                      : 'N/A',
                ),

                _buildResultRow(
                  '🌡️ Teplota',
                  _apiTemperature != null
                      ? '${_apiTemperature!.toStringAsFixed(1)} °C'
                      : 'N/A',
                ),

                _buildResultRow(
                  '🧭 Tlak',
                  _apiPressure != null
                      ? '${_apiPressure!.toStringAsFixed(1)} hPa'
                      : 'N/A',
                ),

                _buildResultRow(
                  '📉 Zmena tlaku telefónu',
                  '${_pressureChange >= 0 ? '+' : ''}'
                  '${_pressureChange.toStringAsFixed(2)} hPa',
                ),

                const Divider(
                  height: 28,
                  color: Colors.white12,
                ),

                _buildResultRow(
                  '📷 Snímky',
                  '$_capturedFrames / 10',
                ),

                _buildResultRow(
                  '🗑️ Fotografie',
                  'Vymazané',
                ),

                const SizedBox(height: 20),

                Container(
                  padding:
                      const EdgeInsets.all(12),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.black26,
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child:
                      const Text(
                    'Výsledok kombinuje obrazovú '
                    'analýzu oblohy, barometer, '
                    'pohyb telefónu a dostupné '
                    'meteodata. Nejde o AI model.',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      color:
                          Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width:
                      double.infinity,
                  child:
                      ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(
                      context,
                    ),
                    child:
                        const Text(
                      'HOTOVO',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  const TextStyle(
                color:
                    Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _pressureSubscription?.cancel();
    _accelerometerSubscription?.cancel();

    _controller?.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),

            SizedBox(height: 16),

            Text(
              'Spúšťam kameru...',
              style:
                  TextStyle(
                color:
                    Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              const Icon(
                Icons
                    .camera_alt_outlined,
                size: 60,
                color:
                    Colors.white54,
              ),

              const SizedBox(height: 16),

              Text(
                _error!,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color:
                      Colors.white70,
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isInitializing =
                        true;
                    _error = null;
                  });

                  _initializeCamera();
                },
                icon:
                    const Icon(
                  Icons.refresh,
                ),
                label:
                    const Text(
                  'Skúsiť znova',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final controller =
        _controller;

    if (controller == null ||
        !controller.value
            .isInitialized) {
      return const Center(
        child: Text(
          'Kamera nie je pripravená.',
          style:
              TextStyle(
            color:
                Colors.white70,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(
          controller,
        ),

        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration:
                BoxDecoration(
              color: Colors.black
                  .withOpacity(0.55),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child:
                const Column(
              children: [
                Text(
                  'ANALÝZA OBLOHY',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'Namierte telefón na oblohu',
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 14,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  '10 sekúnd • kamera + senzory + meteodata',
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_isAnalyzing)
          Positioned(
            left: 20,
            right: 20,
            bottom: 110,
            child: Container(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.black
                    .withOpacity(0.70),
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
              ),
              child:
                  Column(
                children: [
                  const CircularProgressIndicator(),

                  const SizedBox(
                    height: 12,
                  ),

                  const Text(
                    'Analyzujem oblohu...',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    'Snímka '
                    '$_capturedFrames / 10',
                    style:
                        const TextStyle(
                      color:
                          Colors.white70,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    _weatherLoading
                        ? 'Načítavam meteopredpoveď...'
                        : 'Senzory a kamera aktívne',
                    style:
                        const TextStyle(
                      color:
                          Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

        Positioned(
          left: 24,
          right: 24,
          bottom: 24,
          child:
              ElevatedButton.icon(
            onPressed:
                _isAnalyzing
                    ? null
                    : _analyzeSky,
            icon: Icon(
              _isAnalyzing
                  ? Icons
                      .hourglass_top
                  : Icons.cloud,
            ),
            label: Text(
              _isAnalyzing
                  ? 'ANALYZUJEM...'
                  : 'ANALYZOVAŤ OBLOHU',
            ),
            style:
                ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets
                      .symmetric(
                vertical: 16,
              ),
              textStyle:
                  const TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ===============================================================
// VÝSLEDOK ANALÝZY JEDNÉHO OBRÁZKA
// ===============================================================

class _SkyAnalysis {
  final double cloudCoverage;
  final double blueSky;
  final double brightness;
  final double darkClouds;

  const _SkyAnalysis({
    required this.cloudCoverage,
    required this.blueSky,
    required this.brightness,
    required this.darkClouds,
  });
}
