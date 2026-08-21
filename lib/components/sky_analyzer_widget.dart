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
String? _error;

@override
void initState() {
super.initState();
_initializeCamera();
}

Future<void> _initializeCamera() async {
try {
final cameras = await availableCameras();

```
  if (cameras.isEmpty) {
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
```

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
style: TextStyle(color: Colors.white70),
),
],
),
);
}

```
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
            style: const TextStyle(color: Colors.white70),
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

if (controller == null || !controller.value.isInitialized) {
  return const Center(
    child: Text(
      'Kamera nie je pripravená.',
      style: TextStyle(color: Colors.white70),
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
              '📷 ANALÝZA OBLOHY',
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

    Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Kamera je pripravená. AI analýzu oblohy pridáme v ďalšom kroku.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
      ),
    ),
  ],
);
```

}
}
