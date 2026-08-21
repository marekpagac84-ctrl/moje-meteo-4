import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class SkyAnalyzerWidget extends StatefulWidget {
  const SkyAnalyzerWidget({super.key});

  @override
  State<SkyAnalyzerWidget> createState() => _SkyAnalyzerWidgetState();
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
      _capturedImages.clear();

      _cloudCoverage = 0;
      _blueSky = 0;
      _brightness = 0;
      _darkClouds = 0;

      _weatherResult = 'Analyzujem...';
      _weatherDescription = '';
    });

    try {
      for (int i = 0; i < 5; i++) {
        if (!mounted) return;

        final image = await controller.takePicture();

        _capturedImages.add(image);

        if (mounted) {
          setState(() {
            _capturedFrames++;
          });
        }

        if (i < 4) {
          await Future.delayed(
            const Duration(seconds: 1),
          );
        }
      }

      await _processImages();

      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
      });

      _showAnalysisResult();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
        _error = 'Analýza oblohy zlyhala: $e';
      });
    }
  }

  Future<void> _processImages() async {
    if (_capturedImages.isEmpty) {
      return;
    }

    double totalCloud = 0;
    double totalBlue = 0;
    double totalBrightness = 0;
    double totalDark = 0;

    int validImages = 0;

    for (final cameraImage in _capturedImages) {
      try {
        final Uint8List bytes =
            await cameraImage.readAsBytes();

        final decoded = img.decodeImage(bytes);

        if (decoded == null) {
          continue;
        }

        final analysis = await _analyzeImage(decoded);

        totalCloud += analysis.cloudCoverage;
        totalBlue += analysis.blueSky;
        totalBrightness += analysis.brightness;
        totalDark += analysis.darkClouds;

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

    final cloud = totalCloud / validImages;
    final blue = totalBlue / validImages;
    final brightness =
        totalBrightness / validImages;
    final dark = totalDark / validImages;

    if (!mounted) return;

    setState(() {
      _cloudCoverage = cloud;
      _blueSky = blue;
      _brightness = brightness;
      _darkClouds = dark;

      _calculateWeatherResult();
    });
  }

  Future<_SkyAnalysis> _analyzeImage(
    img.Image image,
  ) async {
    int cloudPixels = 0;
    int bluePixels = 0;
    int darkPixels = 0;

    double brightnessSum = 0;

    int samples = 0;

    /*
     * Nemusíme analyzovať každý pixel.
     * Každý 8. pixel je dostatočný na rýchlu
     * analýzu oblohy.
     */
    for (int y = 0; y < image.height; y += 8) {
      for (int x = 0; x < image.width; x += 8) {
        final pixel = image.getPixel(x, y);

        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();

        final maxValue =
            math.max(r, math.max(g, b));

        final minValue =
            math.min(r, math.min(g, b));

        final brightness =
            (r + g + b) / 3.0;

        final saturation =
            maxValue == 0
                ? 0
                : (maxValue - minValue) /
                    maxValue;

        brightnessSum += brightness;

        /*
         * Modrá obloha:
         *
         * modrá musí byť výraznejšia než
         * červená a zelená.
         */
        final isBlue =
            b > r * 1.15 &&
            b > g * 1.05 &&
            saturation > 0.12 &&
            brightness > 60;

        /*
         * Biela/sivá oblačnosť:
         *
         * RGB hodnoty sú si relatívne blízke.
         */
        final isCloud =
            saturation < 0.18 &&
            brightness > 90;

        /*
         * Tmavé mraky alebo veľmi tmavá obloha.
         */
        final isDark =
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
        cloudCoverage: 0,
        blueSky: 0,
        brightness: 0,
        darkClouds: 0,
      );
    }

    return _SkyAnalysis(
      cloudCoverage:
          cloudPixels / samples * 100,
      blueSky:
          bluePixels / samples * 100,
      brightness:
          brightnessSum / samples,
      darkClouds:
          darkPixels / samples * 100,
    );
  }

  void _calculateWeatherResult() {
    final cloud = _cloudCoverage;
    final blue = _blueSky;
    final dark = _darkClouds;
    final brightness = _brightness;

    if (dark > 35 && cloud > 35) {
      _weatherResult = '🌧️ Veľmi zamračené';

      _weatherDescription =
          'Obloha obsahuje veľké množstvo tmavých '
          'a hustých oblastí. Podmienky môžu '
          'zodpovedať blížiacemu sa dažďu.';
    } else if (cloud > 70) {
      _weatherResult = '☁️ Zamračené';

      _weatherDescription =
          'Väčšina pozorovanej oblohy vykazuje '
          'znaky oblačnosti.';
    } else if (cloud > 40) {
      _weatherResult = '⛅ Polooblačno';

      _weatherDescription =
          'Analýza ukazuje kombináciu oblačnosti '
          'a jasnej oblohy.';
    } else if (blue > 45) {
      _weatherResult = '☀️ Jasná obloha';

      _weatherDescription =
          'Výrazná časť snímok obsahuje modrú '
          'oblohu a nízku mieru oblačnosti.';
    } else if (brightness < 80) {
      _weatherResult = '🌥️ Tmavá obloha';

      _weatherDescription =
          'Obloha je výrazne tmavá. Môže ísť '
          'o hustú oblačnosť alebo slabé svetelné '
          'podmienky.';
    } else {
      _weatherResult = '🌤️ Premenlivá obloha';

      _weatherDescription =
          'Obrazová analýza nedokázala jednoznačne '
          'zaradiť stav oblohy.';
    }
  }

  void _showAnalysisResult() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud,
                  size: 55,
                  color: Colors.blueAccent,
                ),

                const SizedBox(height: 12),

                const Text(
                  'VÝSLEDOK ANALÝZY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  _weatherResult,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  _weatherDescription,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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
                  '📷 Snímky',
                  '$_capturedFrames / 5',
                ),

                const SizedBox(height: 20),

                Container(
                  padding:
                      const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Toto je prvá obrazová verzia '
                    'analýzy. V ďalšom kroku môžeme '
                    'pridať skutočný AI model na '
                    'rozpoznávanie oblakov.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context),
                    child: const Text('HOTOVO'),
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
            MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
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
  Widget build(BuildContext context) {
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
                Icons.camera_alt_outlined,
                size: 60,
                color: Colors.white54,
              ),

              const SizedBox(height: 16),

              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isInitializing = true;
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

    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
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
        CameraPreview(controller),

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
            decoration: BoxDecoration(
              color:
                  Colors.black.withOpacity(0.55),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: const Column(
              children: [
                Text(
                  'ANALÝZA OBLOHY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'Namierte telefón na oblohu',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
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
                  const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    Colors.black.withOpacity(0.70),
                borderRadius:
                    BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const CircularProgressIndicator(),

                  const SizedBox(height: 12),

                  const Text(
                    'Analyzujem oblohu...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Snímka $_capturedFrames / 5',
                    style: const TextStyle(
                      color: Colors.white70,
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
          child: ElevatedButton.icon(
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
                  const EdgeInsets.symmetric(
                vertical: 16,
              ),
              textStyle:
                  const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
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
