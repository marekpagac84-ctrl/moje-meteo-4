import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

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
    });

    try {
      // Budeme pozorovať oblohu približne 5 sekúnd.
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
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
      });

      _showAnalysisResult();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
        _error = 'Nepodarilo sa nasnímať oblohu: $e';
      });
    }
  }

  void _showAnalysisResult() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
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
                'OBLOHA NASNÍMANÁ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Nasnímaných snímok: $_capturedFrames',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Snímky sú pripravené na ďalší krok – rozpoznanie oblačnosti a vyhodnotenie počasia.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        );
      },
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
          mainAxisAlignment: MainAxisAlignment.center,
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                icon: const Icon(Icons.refresh),
                label: const Text('Skúsiť znova'),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(14),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.70),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  const Text(
                    'Snímam oblohu...',
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
            onPressed: _isAnalyzing ? null : _analyzeSky,
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
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: 16,
              ),
              textStyle: const TextStyle(
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
