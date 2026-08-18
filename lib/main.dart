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

class RadarFrame {
  final String path;
  final int time;

  RadarFrame({required this.path, required this.time});
}

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
  bool _isLoadingMeteo = false;

  MeteoApiData? _meteoData;

  double _lat = 48.7576;
  double _lng = 17.8309;
  String _locationName = 'Nové Mesto nad Váhom';

  List<RadarFrame> _radarFrames = [];
  int _currentFrameIndex = 0;
  bool _isPlayingAnimation = false;
  Timer? _animationTimer;

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
    _fetchRadarFrames();
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _animationTimer?.cancel();
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
        // Hlásenie senzorov 1x za minútu (60 000 ms) pre plynulý chod
        if (now.difference(_lastAccelUpdate).inMilliseconds < 60000) return;

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

  Future<void> _fetchRadarFrames() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.rainviewer.com/public/weather-maps.json'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<RadarFrame> frames = [];

        if (data.containsKey('radar')) {
          if (data['radar'].containsKey('past')) {
            for (var item in data['radar']['past']) {
              frames.add(RadarFrame(path: item['path'], time: item['time']));
            }
          }
          if (data['radar'].containsKey('nowcast')) {
            for (var item in data['radar']['nowcast']) {
              frames.add(RadarFrame(path: item['path'], time: item['time']));
            }
          }
        }

        setState(() {
          _radarFrames = frames;
          if (_radarFrames.isNotEmpty) {
            _currentFrameIndex = _radarFrames.length ~/ 2;
          }
        });
      }
    } catch (e) {
      print('Chyba načítania radarových snímok: $e');
    }
  }

  Future<void> _fetchWeatherData() async {
    setState(() {
      _isLoadingMeteo = true;
    });

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$_lat&longitude=$_lng&current_weather=true&hourly=precipitation,surface_pressure&forecast_hours=12',
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

  void _toggleAnimation() {
    if (_radarFrames.isEmpty) return;

    if (_isPlayingAnimation) {
      _animationTimer?.cancel();
      setState(() {
        _isPlayingAnimation = false;
      });
    } else {
      setState(() {
        _isPlayingAnimation = true;
      });
      _animationTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
        setState(() {
          _currentFrameIndex = (_currentFrameIndex + 1) % _radarFrames.length;
        });
      });
    }
  }

  String _formatFrameTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toLocal();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final String? currentTile = _radarFrames.isNotEmpty && _currentFrameIndex < _radarFrames.length
        ? _radarFrames[_currentFrameIndex].path
        : null;

    final String timeDisplay = _radarFrames.isNotEmpty && _currentFrameIndex < _radarFrames.length
        ? _formatFrameTime(_radarFrames[_currentFrameIndex].time)
        : "--:--";

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
                      MapContainer(
                        userLocation: LatLng(_lat, _lng),
                        showRadarOverlay: _showRadar,
                        currentTilePath: currentTile,
                        onLocationSelected: (newPoint) {
                          setState(() {
                            _lat = newPoint.latitude;
                            _lng = newPoint.longitude;
                            _locationName = "Vybrané miesto";
                          });
                          _fetchWeatherData();
                        },
                      ),
                      
                      // OVLÁDANIE S PRESNÝM ČASOM SNÍMKY
                      if (_radarFrames.isNotEmpty)
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  timeDisplay,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Slider(
                                  value: _currentFrameIndex.toDouble(),
                                  min: 0.0,
                                  max: (_radarFrames.length - 1).toDouble(),
                                  divisions: _radarFrames.length > 1 ? _radarFrames.length - 1 : 1,
                                  onChanged: (val) {
                                    setState(() {
                                      _currentFrameIndex = val.toInt();
                                    });
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                                onPressed: () {
                                  _fetchRadarFrames();
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
