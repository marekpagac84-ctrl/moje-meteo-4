import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'models/meteo_data.dart';
import 'components/header_bar.dart';
import 'components/sensor_panel.dart';
import 'components/map_container.dart';
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
  bool _showRadar = false;

  @override
  Widget build(BuildContext context) {
    final defaultBarometerState = BarometerState(
      pressure: 1013.25,
      pressureChangeRate: 0.0,
      isDroppingFast: false,
      sensorAvailable: false,
    );

    final defaultMeteoData = MeteoApiData(
      temperature: 20.0,
      humidity: 50,
      windSpeed: 5.0,
      rainProbability: 0,
      isRainFromApi: false,
      condition: 'Clear',
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            HeaderBar(
              currentLocationName: 'Nové Mesto nad Váhom',
              onSelectPreset: (preset) {},
              onUseGps: () {},
              showRadarOverlay: _showRadar,
              onToggleRadar: () {
                setState(() {
                  _showRadar = !_showRadar;
                });
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SensorPanel(
                        barometer: defaultBarometerState,
                        onSimulateDrop: () {},
                        onSimulateMotion: () {},
                        onResetSensors: () {},
                      ),
                      const SizedBox(height: 16),
                      MapContainer(
                        userLocation: const LatLng(48.7576, 17.8309),
                        communityMarkers: const [],
                        showRadarOverlay: _showRadar,
                      ),
                      const SizedBox(height: 16),
                      RadarWidget(
                        meteoData: defaultMeteoData,
                        loading: false,
                        onRefresh: () {},
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
