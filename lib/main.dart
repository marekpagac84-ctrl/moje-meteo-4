import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'components/header_bar.dart';
import 'components/map_container.dart';
import 'components/sensor_panel.dart';
import 'components/radar_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Moje Meteo',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  StreamSubscription? _barometerSub;
  double _currentPressure = 1013.25;

  @override
  void initState() {
    super.initState();
    _initBarometer();
  }

  void _initBarometer() {
    try {
      _barometerSub = barometerEvents.listen(
        (event) {
          if (!mounted) return;
          setState(() {
            _currentPressure = event.pressure;
          });
        },
        onError: (error) {
          debugPrint("Barometer nedostupný: $error");
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint("Chyba barometra: $e");
    }
  }

  @override
  void dispose() {
    _barometerSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            HeaderBar(
              onSelectPreset: (preset) {},
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SensorPanel(
                        barometer: _currentPressure,
                      ),
                      const SizedBox(height: 16),
                      const MapContainer(
                        communityMarkers: [],
                      ),
                      const SizedBox(height: 16),
                      const RadarWidget(
                        loading: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
