
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'components/header_bar.dart';
import 'components/map_container.dart';
import 'components/radar_widget.dart';
import 'components/sensor_panel.dart';
import 'models/meteo_data.dart';

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

  // Predvolené súradnice (Nové Mesto nad Váhom)
  double _lat = 48.7576;
  double _lng = 17.8309;
  String _locationName = 'Nové Mesto nad Váhom';

  // Stavy pre Barometer
  BarometerState _barometerState = BarometerState(
    currentPressure: 1013.25,
    pressureChangeRate: 0.0,
    isMovingVertically: false,
    pressureHistory: [],
  );

  StreamSubscription? _barometerSubscription;

  @override
  void initState() {
    super.initState();
    _initGpsLocation();
    _initBarometerSensor();
  }

  @override
  void dispose() {
    _barometerSubscription?.cancel();
    super.dispose();
  }

  // --- 1. ZÍSKANIE GPS POLOHY ---
  Future<void> _initGpsLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _fetchWeatherData();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _fetchWeatherData();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _fetchWeatherData();
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _locationName = 'Moja GPS poloha';
      });
    } catch (e) {
      print('Chyba GPS: $e');
    }

    _fetchWeatherData();
  }

  // --- 2. ČÍTANIE HARDVÉROVÉHO BAROMETRA ---
  void _initBarometerSensor() {
    try {
      // V sensors_plus 5.x sa používa barometerEvents
      _barometerSubscription = barometerEvents.listen(
        (event) {
          final double newPressure = event.pressure; // hPa

          setState(() {
            final updatedHistory = List<double>.from(_barometerState.pressureHistory);
            updatedHistory.add(newPressure);
            if (updatedHistory.length > 20) {
              updatedHistory.removeAt(0);
            }

            double changeRate = 0.0;
            if (updatedHistory.length > 1) {
              changeRate = updatedHistory.last - updatedHistory.first;
            }

            _barometerState = _barometerState.copyWith(
              currentPressure: newPressure,
              pressureChangeRate: changeRate,
              pressureHistory: updatedHistory,
            );
          });
        },
        onError: (error) {
          print('Barometer nie je dostupný na tomto zariadení: $error');
        },
      );
    } catch (e) {
      print('Senzor tlaku nie je podporovaný: $e');
    }
  }

  // --- 3. STIAHNUTIE METEO DÁT ---
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            HeaderBar(
              currentLocationName: _locationName,
              onSelectPreset: (preset) {
                setState(() {
                  _lat = preset.lat;
                  _lng = preset.lng;
                  _locationName = preset.name;
                });
                _fetchWeatherData();
              },
              onUseGps: _initGpsLocation,
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
                        barometer: _barometerState,
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
