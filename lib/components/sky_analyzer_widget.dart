import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class SkyAnalyzerWidget extends StatefulWidget {
  const SkyAnalyzerWidget({super.key});

  @override
  State<SkyAnalyzerWidget> createState() =>
      _SkyAnalyzerWidgetState();
}

class _SkyAnalyzerWidgetState
    extends State<SkyAnalyzerWidget> {
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

  String _weatherResult =
      'Čakám na analýzu';

  String _weatherDescription = '';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras =
          await availableCameras();

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

      final controller =
          CameraController(
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

      _weatherResult =
          'Analyzujem...';

      _weatherDescription = '';

      _error = null;
    });

    try {
      /*
       * Nasnímame 10 záberov.
       *
       * Jeden záber približne každú sekundu.
       *
       * Telefón teda nemusí používateľ držať
       * na oblohe minúty.
       */
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
            const Duration(
              seconds: 1,
            ),
          );
        }
      }

      /*
       * Spracovanie všetkých 10 záberov.
       */
      await _processImages();

      /*
       * DÔLEŽITÉ:
       *
       * Po dokončení analýzy odstránime
       * vytvorené dočasné súbory.
       */
      await _deleteCapturedImages();

      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
      });

      _showAnalysisResult();
    } catch (e) {
      /*
       * Aj pri chybe sa pokúsime vymazať
       * už vytvorené obrázky.
       */
      await _deleteCapturedImages();

      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;

        _error =
            'Analýza oblohy zlyhala: $e';
      });
    }
  }

  Future<void> _deleteCapturedImages() async {
    /*
     * Prejdeme všetky vytvorené XFile
     * a odstránime ich z dočasného úložiska.
     */
    for (final image
        in List<XFile>.from(_capturedImages)) {
      try {
        final file = File(image.path);

        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint(
          'Nepodarilo sa vymazať obrázok: $e',
        );
      }
    }

    _capturedImages.clear();
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

    /*
     * Spracujeme všetkých 10 záberov.
     */
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

    /*
     * Zistíme, či sa počas 10 sekúnd
     * oblačnosť výraznejšie menila.
     */
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

      _calculateWeatherResult();
    });
  }

  Future<_SkyAnalysis> _analyzeImage(
    img.Image image,
  ) async {
    int cloudPixels = 0;
    int bluePixels = 0;
    int darkPixels = 0;

    double brightnessSum = 0.0;

    int samples = 0;

    /*
     * Nemusíme kontrolovať každý pixel.
     *
     * Každý 8. pixel je dostatočný na
     * rýchlu orientačnú analýzu.
     */
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
                : (maxValue - minValue) /
                    maxValue;

        brightnessSum +=
            brightness;

        /*
         * MODRÁ OBLOHA
         */
        final bool isBlue =
            b > r * 1.15 &&
            b > g * 1.05 &&
            saturation > 0.12 &&
            brightness > 60;

        /*
         * OBLAČNOSŤ
         *
         * Biele a sivé oblasti.
         */
        final bool isCloud =
            saturation < 0.18 &&
            brightness > 90;

        /*
         * TMAVÉ OBLASTI
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

  void _calculateWeatherResult() {
    final double cloud =
        _cloudCoverage;

    final double blue =
        _blueSky;

    final double dark =
        _darkClouds;

    final double brightness =
        _brightness;

    /*
     * Silná tmavá oblačnosť.
     */
    if (dark > 35 &&
        cloud > 35) {
      _weatherResult =
          '🌧️ Veľmi zamračené';

      _weatherDescription =
          'Obloha obsahuje veľké množstvo '
          'tmavých a hustých oblastí. '
          'Môže ísť o dažďovú alebo '
          'búrkovú oblačnosť.';
    }

    /*
     * Veľmi vysoká oblačnosť.
     */
    else if (cloud > 70) {
      _weatherResult =
          '☁️ Zamračené';

      _weatherDescription =
          'Väčšina pozorovanej oblohy '
          'vykazuje znaky oblačnosti.';
    }

    /*
     * Stredná oblačnosť.
     */
    else if (cloud > 40) {
      _weatherResult =
          '⛅ Polooblačno';

      _weatherDescription =
          'Analýza ukazuje kombináciu '
          'oblačnosti a jasnej oblohy.';
    }

    /*
     * Veľa modrej oblohy.
     */
    else if (blue > 45) {
      _weatherResult =
          '☀️ Jasná obloha';

      _weatherDescription =
          'Výrazná časť snímok obsahuje '
          'modrú oblohu a nízku mieru '
          'oblačnosti.';
    }

    /*
     * Tmavá scéna.
     */
    else if (brightness < 80) {
      _weatherResult =
          '🌥️ Tmavá obloha';

      _weatherDescription =
          'Obloha je výrazne tmavá. '
          'Môže ísť o hustú oblačnosť, '
          'večerné svetlo alebo slabé '
          'osvetlenie.';
    }

    /*
     * Nejednoznačný výsledok.
     */
    else {
      _weatherResult =
          '🌤️ Premenlivá obloha';

      _weatherDescription =
          'Obrazová analýza nedokázala '
          'jednoznačne zaradiť stav oblohy.';
    }

    /*
     * Vývoj oblačnosti počas snímania.
     */
    if (_cloudChange > 15) {
      _weatherDescription +=
          ' Počas snímania sa oblačnosť '
          'výrazne zvýšila.';
    } else if (_cloudChange < -15) {
      _weatherDescription +=
          ' Počas snímania sa oblačnosť '
          'mierne znižovala.';
    } else {
      _weatherDescription +=
          ' Počas snímania bola oblačnosť '
          'relatívne stabilná.';
    }
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
                  style: TextStyle(
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
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 24),

                _buildResultRow(
                  '☁️ Odhad oblačnosti',
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

                _buildResultRow(
                  '📷 Analyzované snímky',
                  '$_capturedFrames / 10',
                ),

                const SizedBox(height: 20),

                Container(
                  padding:
                      const EdgeInsets.all(12),
                  decoration:
                      BoxDecoration(
                    color: Colors.black26,
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: const Text(
                    'Snímky boli použité iba '
                    'na lokálnu analýzu oblohy. '
                    'Po dokončení analýzy boli '
                    'dočasné obrázky vymazané.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
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
                        const Text('HOTOVO'),
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

  @override
  void dispose() {
    /*
     * Ak používateľ opustí obrazovku
     * počas analýzy, pokúsime sa vymazať
     * aj prípadné zostávajúce obrázky.
     */
    _deleteCapturedImages();

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
              style: TextStyle(
                color: Colors.white70,
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
                color: Colors.white54,
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
                icon: const Icon(
                  Icons.refresh,
                ),
                label: const Text(
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
          style: TextStyle(
            color: Colors.white70,
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
                  'Namierte telefón '
                  'na oblohu',
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
