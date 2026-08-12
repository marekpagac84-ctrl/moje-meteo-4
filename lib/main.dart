import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'models/meteo_data.dart';
import 'components/header_bar.dart';
import 'components/sensor_panel.dart';
import 'components/map_container.dart';
import 'components/radar_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  bool _isLoadingMeteo = false;

  MeteoApiData? _meteoData;

  // Súradnice pre Nové Mesto nad Váhom
  double _lat = 48.7576;
  double _lng = 17.8309;

  @override
  void initState() {
    super.initState();
    _fetchWeatherData();
  }

  // Funkcia na stiahnutie reálnych dát z Open-Meteo API
  Future<void> _fetchWeatherData() async {
    setState(() {
      _isLoadingMeteo = true;
    });

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$_lat&longitude=$_lng&current_weather=true&hourly=precipitation',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _meteoData = MeteoApiData.fromJson(data);
          _isLoadingMeteo = false;
        });
      } else {
        setState(() {
          _isLoadingMeteo = false;
        });
      }
    } catch (e) {
      print('Chyba pri sťahovaní počasia: $e');
      setState(() {
        _isLoadingMeteo = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultBarometerState = BarometerState(
      currentPressure: 1013.25,
      pressureChangeRate: 0.0,
      isMovingVertically: false,
      pressureHistory: const [],
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            HeaderBar(
              currentLocationName: 'Nové Mesto nad Váhom',
              onSelectPreset: (preset) {
                setState(() {
                  _lat = preset.lat;
                  _lng = preset.lng;
                });
                _fetchWeatherData();
              },
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
                        userLocation: LatLng(_lat, _lng),
                        communityMarkers: const [],
                        showRadarOverlay: _showRadar,
                      ),
                      const SizedBox(height: 16),
                      RadarWidget(
                        meteoData: _meteoData,
                        loading: _isLoadingMeteo,
                        onRefresh: _fetchWeatherData,
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
