import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
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

  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  StreamSubscription<BarometerEvent>? _pressureSubscription;

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

  Future<void> _initGpsLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          if (!mounted) return;
          setState(() {
            _lat = position.latitude;
            _lng = position.longitude;
            _locationName = 'Moja GPS poloha';
          });
        }
      }
    } catch (e) {
      debugPrint('GPS error: $e');
    }
    _fetchWeatherData();
  }

  void _initSensors() {
    try {
      _accelSubscription = userAccelerometerEventStream().listen(
        (event) {
          final double motion = event.x.abs() + event.y.abs() + event.z.abs();
          final bool isMoving = motion > 3.0;
          if (isMoving != _barometerState.isMovingVertically && mounted) {
            setState(() {
              _barometerState =
                  _barometerState.copyWith(isMovingVertically: isMoving);
            });
          }
        },
        onError: (e) => debugPrint('Accelerometer error: $e'),
      );
    } catch (e) {
      debugPrint('Accelerometer not available: $e');
    }

    try {
      _pressureSubscription = barometerEventStream().listen(
        (event) {
          final double newPressure = event.pressure;

          if (newPressure > 0 && mounted) {
            setState(() {
              List<PressurePoint> history =
                  List.from(_barometerState.pressureHistory);

              // Výpočet zmeny tlaku oproti poslednej hodnote
              final double rate =
                  newPressure - _barometerState.currentPressure;

              history.add(PressurePoint(
                timestamp: DateTime.now(),
                pressure: newPressure,
              ));

              if (history.length > 20) {
                history.removeAt(0);
              }

              // Výpočet odhadovanej výšky od základného tlaku (1 hPa ≈ 8.43 m)
              final double base = _barometerState.basePressure > 0
                  ? _barometerState.basePressure
                  : newPressure;
              final double altitude = (base - newPressure) * 8.43;

              _barometerState = _barometerState.copyWith(
                currentPressure: newPressure,
                pressureChangeRate: rate,
                estimatedAltitude: altitude,
                pressureHistory: history,
              );
            });
          }
        },
        onError: (e) => debugPrint('Barometer error: $e'),
      );
    } catch (e) {
      debugPrint('Barometer not available: $e');
    }
  }

  Future<void> _fetchWeatherData() async {
    if (!mounted) return;
    setState(() => _isLoadingMeteo = true);

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$_lat&longitude=$_lng&current_weather=true&hourly=precipitation_probability,surface_pressure&forecast_hours=12',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final meteo = MeteoApiData.fromJson(data);

        if (!mounted) return;
        setState(() {
          _meteoData = meteo;
          _isLoadingMeteo = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isLoadingMeteo = false);
      }
    } catch (e) {
      debugPrint('Meteo API error: $e');
      if (!mounted) return;
      setState(() => _isLoadingMeteo = false);
    }
  }

  void _simulatePressureDrop() {
    setState(() {
      final double newPressure = _barometerState.currentPressure - 3.5;
      List<PressurePoint> history = List.from(_barometerState.pressureHistory);
      history.add(PressurePoint(
        timestamp: DateTime.now(),
        pressure: newPressure,
      ));

      _barometerState = _barometerState.copyWith(
        currentPressure: newPressure,
        pressureChangeRate: -3.5,
        pressureHistory: history,
      );
    });
  }

  void _simulateMotionToggle() {
    setState(() {
      _barometerState = _barometerState.copyWith(
        isMovingVertically: !_barometerState.isMovingVertically,
      );
    });
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
                      onSimulateDrop: _simulatePressureDrop,
                      onSimulateMotion: _simulateMotionToggle,
                      onResetSensors: () => setState(() => _barometerState =
                          _barometerState.copyWith(
                            basePressure: _barometerState.currentPressure,
                            pressureChangeRate: 0.0,
                            estimatedAltitude: 0.0,
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
                          onPressed: () =>
                              setState(() => _useWindyView = !_useWindyView),
                          icon: Icon(
                            _useWindyView ? Icons.map : Icons.thunderstorm,
                            color: Colors.blueAccent,
                          ),
                          label: Text(
                            _useWindyView
                                ? "Prepnúť na Základnú"
                                : "Prepnúť na Windy",
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
                                : MapContainer(lat: _lat, lng: _lng)),
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
