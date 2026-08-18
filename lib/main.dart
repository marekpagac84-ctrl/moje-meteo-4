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
  bool _showRadar = true;
  bool _isLoadingMeteo = false;

  MeteoApiData? _meteoData;

  double _lat = 48.7576;
  double _lng = 17.8309;
  String _locationName = 'Nové Mesto nad Váhom';

  double _currentTimeOffset = 0.0;
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

  Future<void> _fetchWeatherData() async {
    setState(() {
      _isLoadingMeteo = true;
    });

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$_lat&longitude=$_lng&current_weather=true&hourly=precipitation_probability,weathercode,cloud_cover,surface_pressure&forecast_hours=12',
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

  double _getInterpolatedPrecipProb(double offsetHours) {
    if (_meteoData == null || _meteoData!.hourlyPrecipProb.isEmpty) return 0.0;
    final list = _meteoData!.hourlyPrecipProb;

    int baseIndex = offsetHours.floor();
    int nextIndex = baseIndex + 1;

    if (baseIndex >= list.length - 1) return list.last;

    double progress = offsetHours - baseIndex;
    return list[baseIndex] + (list[nextIndex] - list[baseIndex]) * progress;
  }

  Map<String, dynamic> _getWeatherDescription(int code) {
    switch (code) {
      case 0:
        return {'text': 'Jasno / Slnečno', 'icon': Icons.wb_sunny, 'color': Colors.amber};
      case 1:
      case 2:
        return {'text': 'Mierne oblačno', 'icon': Icons.wb_cloudy, 'color': Colors.amberAccent};
      case 3:
        return {'text': 'Zamračené', 'icon': Icons.cloud, 'color': Colors.grey};
      case 45:
      case 48:
        return {'text': 'Hmla', 'icon': Icons.dehaze, 'color': Colors.blueGrey};
      case 51:
      case 53:
      case 55:
        return {'text': 'Mrholenie', 'icon': Icons.grain, 'color': Colors.lightBlue};
      case 61:
      case 63:
      case 65:
        return {'text': 'Dážď', 'icon': Icons.umbrella, 'color': Colors.blue};
      case 80:
      case 81:
      case 82:
        return {'text': 'Prehánky', 'icon': Icons.cloudy_snowing, 'color': Colors.blueAccent};
      case 95:
      case 96:
      case 99:
        return {'text': 'Búrky!', 'icon': Icons.flash_on, 'color': Colors.deepOrange};
      default:
        return {'text': 'Oblačno', 'icon': Icons.cloud, 'color': Colors.grey};
    }
  }

  int _getCurrentWeatherCode(double offsetHours) {
    if (_meteoData == null || _meteoData!.hourlyWeatherCodes.isEmpty) return 0;
    int index = offsetHours.round();
    if (index >= _meteoData!.hourlyWeatherCodes.length) {
      return _meteoData!.hourlyWeatherCodes.last;
    }
    return _meteoData!.hourlyWeatherCodes[index];
  }

  @override
  Widget build(BuildContext context) {
    final double precipProb = _getInterpolatedPrecipProb(_currentTimeOffset);
    final int weatherCode = _getCurrentWeatherCode(_currentTimeOffset);
    final weatherInfo = _getWeatherDescription(weatherCode);

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
                        onLocationSelected: (newPoint) {
                          setState(() {
                            _lat = newPoint.latitude;
                            _lng = newPoint.longitude;
                            _locationName = "Vybrané miesto";
                          });
                          _fetchWeatherData();
                        },
                      ),
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
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Row(
                              children: [
                                Icon(weatherInfo['icon'] as IconData, color: weatherInfo['color'] as Color, size: 28),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Stav', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                    Text(
                                      weatherInfo['text'] as String,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 30,
                              child: VerticalDivider(color: Colors.white24, thickness: 1),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.water_drop, color: Colors.cyanAccent, size: 28),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Riziko dažďa', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                    Text(
                                      '${precipProb.round()} %',
                                      style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ],
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
