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
import 'components/rain_arrival_widget.dart';
import 'components/sensor_panel.dart';
import 'components/windy_map_container.dart';
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
  bool _showRadar = true;
  bool _useWindyView = true;
  bool _isLoadingMeteo = false;

  MeteoApiData? _meteoData;

  double _lat = 48.7576;
  double _lng = 17.8309;
  String _locationName = 'Nové Mesto nad Váhom';

  double _currentTimeOffset = 0.0;

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
      print('Akcelerometer nie je dostupný: $e');
    }
  }

  Future<void> _fetchWeatherData() async {
    setState(() {
      _isLoadingMeteo = true;
    });

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$_lat&longitude=$_lng&current_weather=true&hourly=precipitation_probability,weathercode,cloud_cover,surface_pressure,winddirection_10m&forecast_hours=12',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        double seaLevelP = 1013.25;
        if (data.containsKey('current_weather') && data['current_weather'].containsKey('pressure')) {
          seaLevelP = (data['current_weather']['pressure'] as num).toDouble();
        }

        setState(() {
          _meteoData = MeteoApiData.fromJson(data);
          _barometerState = _barometerState.copyWith(
            basePressure: seaLevelP,
            currentPressure: seaLevelP,
          );
          _isLoadingMeteo = false;
        });
      } else {
        setState(() {
          _isLoadingMeteo = false;
        });
      }
    } catch (e) {
      print('Chyba meteo API: $e');
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
                        onResetSensors: () {
                          setState(() {
                            _barometerState = _barometerState.copyWith(
                              basePressure: _barometerState.currentPressure,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Predpovedná mapa",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: true,
                                label: Text("Windy 3D"),
                                icon: Icon(Icons.air, size: 16),
                              ),
                              ButtonSegment(
                                value: false,
                                label: Text("Radar"),
                                icon: Icon(Icons.map, size: 16),
                              ),
                            ],
                            selected: {_useWindyView},
                            onSelectionChanged: (Set<bool> newSelection) {
                              setState(() {
                                _useWindyView = newSelection.first;
                              });
                            },
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_useWindyView)
                        WindyMapContainer(
                          key: ValueKey("windy_${_lat}_$_lng"),
                          userLocation: LatLng(_lat, _lng),
                        )
                      else
                        MapContainer(
                          userLocation: LatLng(_lat, _lng),
                          showRadarOverlay: _showRadar,
                          timeOffsetHours: _currentTimeOffset,
                          onLocationSelected: (LatLng newPoint) {
                            setState(() {
                              _lat = newPoint.latitude;
                              _lng = newPoint.longitude;
                              _locationName = "Vybrané miesto";
                            });
                            _fetchWeatherData();
                          },
                        ),
                      const SizedBox(height: 16),
                      RainArrivalWidget(
                        meteoData: _meteoData,
                        loading: _isLoadingMeteo,
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
