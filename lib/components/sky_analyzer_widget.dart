import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/meteo_data.dart';

class SkyAnalyzerWidget extends StatefulWidget {
  final BarometerState barometer;
  final MeteoApiData? meteoData;

  const SkyAnalyzerWidget({
    super.key,
    required this.barometer,
    required this.meteoData,
  });

  @override
  State<SkyAnalyzerWidget> createState() =>
      _SkyAnalyzerWidgetState();
}

class _SkyAnalyzerWidgetState extends State<SkyAnalyzerWidget> {
  CameraController? _controller;

  bool _isInitializing = true;
  bool _isAnalyzing = false;

  String? _error;

  int _capturedFrames = 0;

  final List<XFile> _capturedImages = [];

  double _cloudCoverage = 0.0;
  double _blueSky = 0.0;
  double _brightness = 0.0;
  double _darkClouds = 0.0;
  double _cloudChange = 0.0;

  double _pressure = 0.0;
  double _pressureChange = 0.0;

  int? _rainProbability;
  double? _rainAmount;

  String _weatherResult = 'Čakám na analýzu';
  String _weatherDescription = '';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        if (!mounted) return;

        setState(() {
          _error = 'Zariadenie nemá dostupnú kameru.';
          _isInitializing = false;
        });

        return;
      }

      CameraDescription? selectedCamera;

      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
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
        _error = 'Kameru sa nepodarilo spustiť: $e';
        _isInitializing = false;
      });
    }
  }

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

      _cloudCoverage = 0.0;
      _blueSky = 0.0;
      _brightness = 0.0;
      _darkClouds = 0.0;
      _cloudChange = 0.0;

      _pressure = widget.barometer.currentPressure;
      _pressureChange =
          widget.barometer.pressureChangeRate;

      _rainProbability = null;
      _rainAmount = null;

      _weatherResult = 'Analyzujem...';
      _weatherDescription = '';
      _error = null;
    });

    try {
      /*
       * 10 záberov počas približne 10 sekúnd.
       *
       * Používateľ teda iba namieri telefón na oblohu,
       * stlačí tlačidlo a nemusí telefón držať hodinu.
       */
      for (int i = 0; i < 10; i++) {
        if (!mounted) return;

        final image = await controller.takePicture();

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

      /*
       * Najprv spracujeme všetky fotografie.
       */
      await _processImages();

      /*
       * Potom spojíme kameru, barometer a predpoveď.
       */
      _calculateCombinedWeatherResult();

      /*
       * Fotografie už nepotrebujeme.
       * Vymažeme ich zo zariadenia.
       */
      await _deleteCapturedImages();

      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
      });

      _showAnalysisResult();
    } catch (e) {
      /*
       * Aj pri chybe sa pokúsime fotografie odstrániť.
       */
      await _deleteCapturedImages();

      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
        _error = 'Analýza oblohy zlyhala: $e';
      });
    }
  }

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

    for (final cameraImage in _capturedImages) {
      try {
        final Uint8List bytes =
            await cameraImage.readAsBytes();

        final decoded = img.decodeImage(bytes);

        if (decoded == null) {
          continue;
        }

        final analysis =
            _analyzeImage(decoded);

        totalCloud += analysis.cloudCoverage;
        totalBlue += analysis.blueSky;
        totalBrightness += analysis.brightness;
        totalDark += analysis.darkClouds;

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

  _SkyAnalysis _analyzeImage(
    img.Image image,
  ) {
    int cloudPixels = 0;
    int bluePixels = 0;
    int darkPixels = 0;

    double brightnessSum = 0.0;

    int samples = 0;

    /*
     * Každý 8. pixel.
     *
     * Je to zámerne zjednodušené,
     * aby analýza telefón zbytočne nezaťažovala.
     */
    for (int y = 0; y < image.height; y += 8) {
      for (int x = 0; x < image.width; x += 8) {
        final pixel = image.getPixel(x, y);

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
                : (maxValue - minValue) /
                    maxValue;

        brightnessSum += brightness;

        /*
         * Modrá obloha.
         */
        final bool isBlue =
            b > r * 1.15 &&
            b > g * 1.05 &&
            saturation > 0.12 &&
            brightness > 60;

        /*
         * Biela/sivá oblačnosť.
         */
        final bool isCloud =
            saturation < 0.18 &&
            brightness > 90;

        /*
         * Tmavé oblasti.
         */
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
          cloudPixels / samples * 100.0,
      blueSky:
          bluePixels / samples * 100.0,
      brightness:
          brightnessSum / samples,
      darkClouds:
          darkPixels / samples * 100.0,
    );
  }

  void _calculateCombinedWeatherResult() {
    /*
     * ==========================================
     * 1. KAMERA
     * ==========================================
     */
    final double cloud = _cloudCoverage;
    final double blue = _blueSky;
    final double dark = _darkClouds;
    final double brightness = _brightness;
    final double cloudChange = _cloudChange;

    /*
     * ==========================================
     * 2. BAROMETER
     * ==========================================
     */
    _pressure =
        widget.barometer.currentPressure;

    _pressureChange =
        widget.barometer.pressureChangeRate;

    final bool phoneMoving =
        widget.barometer.isMovingVertically;

    /*
     * ==========================================
     * 3. METEO PREDPOVEĎ
     * ==========================================
     */

    final meteo = widget.meteoData;

    _rainProbability =
        _getCurrentRainProbability(meteo);

    _rainAmount =
        _getCurrentRainAmount(meteo);

    /*
     * ==========================================
     * BODOVANIE
     * ==========================================
     *
     * Nechceme, aby jeden senzor rozhodol sám.
     *
     * Kamera + tlak + predpoveď sa navzájom
     * podporujú.
     */

    double rainScore = 0.0;

    /*
     * Kamera.
     */

    if (cloud > 70) {
      rainScore += 25;
    } else if (cloud > 50) {
      rainScore += 15;
    } else if (cloud > 35) {
      rainScore += 8;
    }

    if (dark > 35) {
      rainScore += 20;
    } else if (dark > 20) {
      rainScore += 10;
    }

    if (cloudChange > 15) {
      rainScore += 15;
    } else if (cloudChange > 8) {
      rainScore += 8;
    }

    /*
     * Barometer.
     *
     * Záporná hodnota = tlak klesá.
     */
    if (!phoneMoving) {
      if (_pressureChange < -2.0) {
        rainScore += 20;
      } else if (_pressureChange < -1.0) {
        rainScore += 12;
      } else if (_pressureChange < -0.3) {
        rainScore += 5;
      }

      /*
       * Stabilný alebo rastúci tlak je skôr
       * priaznivý signál.
       */
      if (_pressureChange > 0.5) {
        rainScore -= 8;
      }
    }

    /*
     * Predpoveď Open-Meteo.
     */
    if (_rainProbability != null) {
      if (_rainProbability! >= 80) {
        rainScore += 20;
      } else if (_rainProbability! >= 60) {
        rainScore += 15;
      } else if (_rainProbability! >= 40) {
        rainScore += 8;
      } else if (_rainProbability! < 15) {
        rainScore -= 5;
      }
    }

    /*
     * Množstvo predpokladaných zrážok.
     */
    if (_rainAmount != null) {
      if (_rainAmount! >= 2.0) {
        rainScore += 10;
      } else if (_rainAmount! >= 0.5) {
        rainScore += 5;
      }
    }

    rainScore =
        rainScore.clamp(0.0, 100.0);

    /*
     * ==========================================
     * VÝSLEDNÝ STAV
     * ==========================================
     */

    if (rainScore >= 70) {
      _weatherResult =
          '🌧️ Vysoké riziko dažďa';

      _weatherDescription =
          'Kamera, tlak a meteorologická '
          'predpoveď vykazujú viacero '
          'signálov podporujúcich možnosť '
          'zrážok.';
    } else if (rainScore >= 50) {
      _weatherResult =
          '🌦️ Zvýšené riziko dažďa';

      _weatherDescription =
          'Podmienky naznačujú zvýšenú '
          'možnosť zrážok. Oblačnosť alebo '
          'pokles tlaku podporujú tento signál.';
    } else if (cloud > 70) {
      _weatherResult =
          '☁️ Zamračené';

      _weatherDescription =
          'Obloha je výrazne pokrytá '
          'oblačnosťou, ale kombinované '
          'údaje zatiaľ nepotvrdzujú vysoké '
          'riziko dažďa.';
    } else if (cloud > 40) {
      _weatherResult =
          '⛅ Polooblačno';

      _weatherDescription =
          'Kamera zaznamenala kombináciu '
          'oblačnosti a jasnej oblohy.';
    } else if (blue > 45) {
      _weatherResult =
          '☀️ Jasná obloha';

      _weatherDescription =
          'Kamera zaznamenala výrazný podiel '
          'modrej oblohy a nízku oblačnosť.';
    } else {
      _weatherResult =
          '🌤️ Premenlivá obloha';

      _weatherDescription =
          'Údaje z kamery nedávajú úplne '
          'jednoznačný obraz počasia.';
    }

    /*
     * Informácia o tlaku.
     */

    if (!phoneMoving) {
      if (_pressureChange < -1.0) {
        _weatherDescription +=
            ' Tlak momentálne klesá.';
      } else if (_pressureChange > 0.5) {
        _weatherDescription +=
            ' Tlak momentálne rastie.';
      } else {
        _weatherDescription +=
            ' Tlak je relatívne stabilný.';
      }
    } else {
      _weatherDescription +=
          ' Telefón bol počas merania v pohybe, '
          'preto tlak nehodnotím ako spoľahlivý '
          'trend.';
    }

    /*
     * Informácia o vývoji oblačnosti.
     */

    if (cloudChange > 15) {
      _weatherDescription +=
          ' Počas snímania oblačnosť výrazne '
          'pribúdala.';
    } else if (cloudChange < -15) {
      _weatherDescription +=
          ' Počas snímania oblačnosť ubúdala.';
    } else {
      _weatherDescription +=
          ' Počas snímania bola oblačnosť '
          'pomerne stabilná.';
    }
  }

  int? _getCurrentRainProbability(
    MeteoApiData? meteo,
  ) {
    if (meteo == null ||
        meteo.hourlyPrecipitationProbability ==
            null ||
        meteo.hourlyPrecipitationProbability!
            .isEmpty) {
      return null;
    }

    return meteo
        .hourlyPrecipitationProbability!
        .first;
  }

  double? _getCurrentRainAmount(
    MeteoApiData? meteo,
  ) {
    if (meteo == null ||
        meteo.hourlyPrecipitation == null ||
        meteo.hourlyPrecipitation!.isEmpty) {
      return null;
    }

    return meteo.hourlyPrecipitation!.first;
  }

  Future<void> _deleteCapturedImages() async {
    /*
     * Vymazanie fotografií z úložiska.
     *
     * Ak už súbor neexistuje, nič sa nedeje.
     */
    for (final image in _capturedImages) {
      try {
        final file = File(image.path);

        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint(
          'Nepodarilo sa vymazať snímku: $e',
        );
      }
    }

    _capturedImages.clear();
  }

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
                    color:
                        Colors.white,
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
                    color:
                        Colors.white,
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
                  '☁️ Oblačnosť',
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
                  '🌡️ Tlak',
                  _pressure > 0
                      ? '${_pressure.toStringAsFixed(1)} hPa'
                      : 'N/A',
                ),

                _buildResultRow(
                  '📉 Trend tlaku',
                  _pressureChange == 0
                      ? 'stabilný'
                      : '${_pressureChange >= 0 ? '+' : ''}'
                          '${_pressureChange.toStringAsFixed(2)}',
                ),

                _buildResultRow(
                  '📱 Pohyb',
                  widget.barometer
                          .isMovingVertically
                      ? 'detekovaný'
                      : 'bez pohybu',
                ),

                if (_rainProbability != null)
                  _buildResultRow(
                    '🌧️ Predpoveď zrážok',
                    '$_rainProbability %',
                  ),

                if (_rainAmount != null)
                  _buildResultRow(
                    '💧 Predpovedané zrážky',
                    '${_rainAmount!.toStringAsFixed(1)} mm',
                  ),

                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
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
                    'analýzu oblohy, tlakový trend, '
                    'detekciu pohybu telefónu a '
                    'údaje z meteorologickej '
                    'predpovede.',
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
              color:
                  Colors.white,
              fontSize: 15,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

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
                    'Kamera + tlak + predpoveď',
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
                  ? Icons.hourglass_top
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
