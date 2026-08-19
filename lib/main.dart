import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';

// Importy tvojich komponentov a modelov
import 'models/meteo_data.dart';
import 'components/header_bar.dart';
import 'components/sensor_panel.dart';
import 'components/barometer_warning_widget.dart';
import 'components/map_container.dart';
import 'components/radar_widget.dart';
import 'components/rain_arrival_widget.dart';
import 'components/windy_map_container.dart';

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
  // Stavové premenné
  bool _showRadar = true;
  bool _useWindyView = true;
  bool _isLoadingMeteo = false;
  MeteoApiData? _meteoData;

  double _lat = 48.7576;
  double _lng = 17.8309;
  String _locationName = 'Nové Mesto nad Váhom';

  BarometerState _barometerState = BarometerState(
    currentPressure: 1013.25,
    pressureChangeRate: 0.0,
    isMovingVertically: false,
    pressureHistory: [],
    estimatedAltitude: 0.0,
    basePressure: 1013.25,
  );

  StreamSubscription? _accelSubscription;
  DateTime _lastAccelUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initGpsLocation();
    _initSensors();
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    super.dispose();
  }

  // GPS logika
  Future<void> _initGpsLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _fetchWeatherData();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _fetchWeatherData();
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
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

  // Senzor logika
  void _initSensors() {
    try {
      _accelSubscription = userAccelerometerEventStream().listen((event) {
        final now = DateTime.now();
        if (now.difference(_lastAccelUpdate).inMilliseconds < 1000) return;
        final double totalMotion = event.x.abs() + event.y.abs() + event.z.abs();
        final bool isMovingNow = totalMotion > 3.0;

        if (isMovingNow != _barometerState.isMovingVertically) {
          _lastAccelUpdate = now;
          setState(() {
            _barometerState = _barometerState.copyWith(isMovingVertically: isMovingNow);
          });
        }
      });
    } catch (e) {
      print('Akcelerometer nedostupný');
    }
  }

  Future<void> _fetchWeatherData() async {
    setState(() => _isLoadingMeteo = true);
    try {
      final url = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$_lat&longitude=$_lng&current_weather=true&hourly=precipitation_probability,surface_pressure&forecast_hours=12');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _meteoData = MeteoApiData.fromJson(data);
          _isLoadingMeteo = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingMeteo = false);
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
              onToggleRadar: () => setState(() => _showRadar = !_showRadar),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    SensorPanel(
                      barometer: _barometerState,
                      onSimulateDrop: () {}, 
                      onSimulateMotion: () {},
                      onResetSensors: () => setState(() => _barometerState = _barometerState.copyWith(basePressure: _barometerState.currentPressure)),
                    ),
                    const SizedBox(height: 12),
                    BarometerWarningWidget(barometer: _barometerState),
                    const SizedBox(height: 16),
                    // ... zbytok widgetov (MapContainer, WindyMap atd.) ...
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
