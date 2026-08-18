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

  // Oblačnosť a plynulá animácia
  List<double> _cloudForecast = List.filled(12, 0.0);
  double _currentTimeOffset = 0.0; 
  bool _isPlayingAnimation = false;
  Timer? _animationTimer;

  // Stavy pre Barometer
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
    _animationTimer?.cancel();
    super.dispose();
  }

  // --- 1. ZÍSKANIE GPS POLOHY ---
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

  // --- 2. HARDVÉROVÉ SENZORY (BEZ TRASENIA) ---
  void _initSensors() {
    try {
      _accelSubscription = userAccelerometerEventStream().listen((event) {
        final now = DateTime.now();
        if (now.difference(_lastAccelUpdate).inMilliseconds < 500) return;

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

  // --- 3. STIAHNUTIE METEO DÁT + OBLAČNOSŤ ---
  Future<void> _fetchWeatherData() async {
    setState(() {
      _isLoadingMeteo = true;
    });

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$_lat&longitude=$_lng&current_weather=true&hourly=precipitation,surface_pressure,cloud_cover&forecast_hours=12',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        double seaLevelP = 1013.25;
        if (data.containsKey('current_weather') && data['current_weather'].containsKey('pressure')) {
          seaLevelP = (data['current_weather']['pressure'] as num).toDouble();
        }

        List<double> clouds = [];
        if (data.containsKey('hourly') && data['hourly'].containsKey('cloud_cover')) {
          final List rawClouds = data['hourly']['cloud_cover'];
          clouds = rawClouds.take(11).map((e) => (e as num).toDouble()).toList();
        }

        setState(() {
          _meteoData = MeteoApiData.fromJson(data);
          _barometerState = _barometerState.copyWith(
            basePressure: seaLevelP,
            currentPressure: seaLevelP,
          );
          if (clouds.isNotEmpty) {
            _cloudForecast = clouds;
          }
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

  // --- 4. LINEÁRNA INTERPOLÁCIA PRE OBLAČNOSŤ ---
  double _getInterpolatedCloudCover(double offsetHours) {
    if (_cloudForecast.isEmpty) return 0.0;

    int baseIndex = offsetHours.floor();
    int nextIndex = baseIndex + 1;

    if (baseIndex >= _cloudForecast.length - 1) {
      return _cloudForecast.last;
    }

    double progress = offsetHours - baseIndex;
    double startVal = _cloudForecast[baseIndex];
    double endVal = _cloudForecast[nextIndex];

    return startVal + (endVal - startVal) * progress;
  }

  // --- 5. PREHRÁVAČ ANIMÁCIE ---
  void _toggleAnimation() {
    if (_isPlayingAnimation) {
      _animationTimer?.cancel();
      setState(() {
        _isPlayingAnimation = false;
      });
    } else {
      setState(() {
        _isPlayingAnimation = true;
      });
      _animationTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        setState(() {
          _currentTimeOffset += 0.05;
          if (_currentTimeOffset >= 10.0) {
            _currentTimeOffset = 0.0;
          }
        });
      });
    }
  }

  String _formatOffsetTime(double offset) {
    if (offset < 0.05) return "Teraz";
    int hours = offset.floor();
    int minutes = ((offset - hours) * 60).round();
    if (hours == 0) return "+${minutes}m";
    if (minutes == 0) return "+${hours}h";
    return "+${hours}h ${minutes}m";
  }

  @override
  Widget build(BuildContext context) {
    final double currentCloudVal = _getInterpolatedCloudCover(_currentTimeOffset);

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
                      const SizedBox(height: 16),
                      
                      // MAPA
                      MapContainer(
                        userLocation: LatLng(_lat, _lng),
                        showRadarOverlay: _showRadar,
                        cloudCoverPercent: currentCloudVal,
                        onLocationSelected: (newPoint) {
                          setState(() {
                            _lat = newPoint.latitude;
                            _lng = newPoint.longitude;
                            _locationName = "Vybrané miesto";
                          });
                          _fetchWeatherData();
                        },
                      ),

                      // PLYNULÝ PREHRÁVAČ OBLAČNOSTI (10 HODÍN)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _isPlayingAnimation ? Icons.pause_circle : Icons.play_circle,
                                color: Colors.blueAccent,
                                size: 32,
                              ),
                              onPressed: _toggleAnimation,
                            ),
                            SizedBox(
                              width: 75,
                              child: Text(
                                _formatOffsetTime(_currentTimeOffset),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _currentTimeOffset,
                                min: 0.0,
                                max: 10.0,
                                onChanged: (val) {
                                  setState(() {
                                    _currentTimeOffset = val;
                                  });
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                              onPressed: () {
                                setState(() {
                                  _currentTimeOffset = 0.0;
                                });
                              },
                            ),
                          ],
                        ),
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
