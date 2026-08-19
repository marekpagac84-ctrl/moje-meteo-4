import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';

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
  bool _showRadar = true;
  bool _useWindyView = true;
  bool _isLoadingMeteo = false;
  MeteoApiData? _meteoData;

  // Predvolené súradnice pre Nové Mesto nad Váhom
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
  StreamSubscription? _pressureSubscription;

  @override
  void initState() {
    super.initState();
    _initGpsLocation();
    _initSensors();
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _pressureSubscription?.cancel();
    super.dispose();
  }

  // 1. Získanie GPS polohy (ak je nedostupná, použije Nové Mesto)
  Future<void> _initGpsLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          setState(() {
            _lat = position.latitude;
            _lng = position.longitude;
            _locationName = 'Moja GPS poloha';
          });
        }
      }
    } catch (e) {
      debugPrint('GPS chyba: $e');
    }
    _fetchWeatherData();
  }

  // 2. Bezpečné počúvanie senzorov prispôsobené pre novší sensors_plus
  void _initSensors() {
    try {
      _accelSubscription = userAccelerometerEvents.listen((UserAccelerometerEvent event) {
        final double motion = event.x.abs() + event.y.abs() + event.z.abs();
        final bool isMoving = motion > 3.0;
        if (isMoving != _barometerState.isMovingVertically) {
          setState(() {
            _barometerState = _barometerState.copyWith(isMovingVertically: isMoving);
          });
        }
      });
    } catch (e) {
      debugPrint('Akcelerometer nedostupný: $e');
    }

    try {
      _pressureSubscription = barometerEvents.listen((BarometerEvent event) {
        if (event.pressure > 0) {
          List<PressurePoint> history = List.from(_barometerState.pressureHistory);
          history.add(PressurePoint(timestamp: DateTime.now(), pressure: event.pressure));
          if (history.length > 20) history.removeAt(0);

          setState(() {
            _barometerState = _barometerState.copyWith(
              currentPressure: event.pressure,
              pressureHistory: history,
            );
          });
        }
      });
    } catch (e) {
      debugPrint('Barometer nedostupný: $e');
    }
  }

  // 3. Stiahnutie dát o zrážkach pre widget predpovede
  Future<void> _fetchWeatherData() async {
    setState(() => _isLoadingMeteo = true);
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$_lat&longitude=$_lng&current_weather=true&hourly=precipitation_probability,surface_pressure&forecast_hours=12',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final meteo = MeteoApiData.fromJson(data);

        setState(() {
          _meteoData = meteo;
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
                      onResetSensors: () => setState(() => _barometerState = _barometerState.copyWith(
                        basePressure: _barometerState.currentPressure,
                      )),
                    ),
                    const SizedBox(height: 12),
                    BarometerWarningWidget(barometer: _barometerState),
                    const SizedBox(height: 16),
                    RainArrivalWidget(
                      meteoData: _meteoData,
                      isLoading: _isLoadingMeteo,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Radar & Mapa",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _useWindyView = !_useWindyView),
                          icon: Icon(
                            _useWindyView ? Icons.map : Icons.thunderstorm,
                            color: Colors.blueAccent,
                          ),
                          label: Text(
                            _useWindyView ? "Prepnúť na Základnú" : "Prepnúť na Windy",
                            style: const TextStyle(color: Colors.blueAccent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 350,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _useWindyView
                            ? WindyMapContainer(lat: _lat, lng: _lng)
                            : (_showRadar
                                ? RadarWidget(lat: _lat, lng: _lng)
                                : MapContainer(center: LatLng(_lat, _lng))),
                      ),
                    ),
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
