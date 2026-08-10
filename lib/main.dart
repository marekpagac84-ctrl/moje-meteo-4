import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

// Importy tvojich komponentov
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
  // Dynamické pripojenie na stream, aby sme sa vyhli chybám s chýbajúcim typom BarometerEvent
  StreamSubscription? _barometerSub;
  double _currentPressure = 1013.25;

  @override
  void initState() {
    super.initState();
    _initBarometer();
  }

  void _initBarometer() {
    try {
      // Bezpečné volanie streamu barometra
      _barometerSub = barometerEventStream().listen(
        (dynamic event) {
          if (!mounted) return;
          setState(() {
            // Unifikované načítanie hodnoty tlaku bez ohľadu na verziu balíčka
            if (event is double) {
              _currentPressure = event;
            } else if (event != null) {
              _currentPressure = (event.pressure as num).toDouble();
            }
          });
        },
        onError: (error) {
          debugPrint("Barometer nie je dostupný: $error");
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint("Chyba pri inicializácii barometra: $e");
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
            const HeaderBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SensorPanel(pressure: _currentPressure),
                      const SizedBox(height: 16),
                      const MapContainer(),
                      const SizedBox(height: 16),
                      const RadarWidget(),
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
