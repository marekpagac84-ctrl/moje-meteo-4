import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'models/meteo_data.dart';
import 'services/meteo_service.dart';
import 'components/header_bar.dart';
import 'components/map_container.dart';
import 'components/sensor_panel.dart';
import 'components/radar_widget.dart';
import 'components/warning_banner.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LiveMeteoApp());
}

class LiveMeteoApp extends StatelessWidget {
  const LiveMeteoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Storm Radar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
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
  // Location
  PresetLocation _currentLocation = MeteoService.presetLocations.first;
  LatLng _userLocation = LatLng(MeteoService.presetLocations.first.lat, MeteoService.presetLocations.first.lng);

  // Sensor state
  double _currentPressure = 1013.25;
  double _pressureChangeRate = 0.0;
  bool _isMovingVertically = false;
  final List<double> _pressureHistory = [1013.25];

  // Meteo API state
  MeteoApiData? _meteoApiData;
  bool _loadingApi = false;

  // Radar Layer toggle
  bool _showRadarOverlay = true;

  // Subscriptions
  StreamSubscription<BarometerEvent>? _barometerSub;
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;

  @override
  void initState() {
    super.initState();
    _initSensors();
    _loadMeteoData();
  }

  void _initSensors() {
    // Opravené kompatibilné načítanie barometra pre novšie verzie sensors_plus
    _barometerSub = barometerEventStream().listen((event) {
      if (!mounted) return;
      setState(() {
        _currentPressure = event.pressure;
        _pressureHistory.add(_currentPressure);
        if (_pressureHistory.length > 30) _pressureHistory.removeAt(0);

        if (_pressureHistory.length > 3) {
          double diff = _pressureHistory.last - _pressureHistory.first;
          _pressureChangeRate = diff * 12;
        }
      });
    }, onError: (err) {
      debugPrint('Senzor barometra nedostupný na tomto zariadení (používa sa simulátor)');
    });

    _accelerometerSub = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      double vertAcc = (event.z.abs() - 9.81).abs();
      setState(() {
        _isMovingVertically = vertAcc > 1.5;
      });
    }, onError: (err) {
      debugPrint('Akcelerometer nedostupný');
    });
  }

  Future<void> _loadMeteoData() async {
    setState(() => _loadingApi = true);
    try {
      final data = await MeteoService.fetchOfficialWeatherData(
        _userLocation.latitude,
        _userLocation.longitude,
      );
      if (!mounted) return;
      setState(() {
        _meteoApiData = data;
        _loadingApi = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingApi = false);
    }
  }

  Future<void> _useGpsLocation() async {
    final pos = await MeteoService.getDeviceLocation();
    if (pos != null && mounted) {
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
        _currentLocation = PresetLocation(name: 'Moja GPS poloha', lat: pos.latitude, lng: pos.longitude);
      });
      _loadMeteoData();
    }
  }

  void _handleSimulateDrop() {
    setState(() {
      _currentPressure -= 2.5;
      _pressureHistory.add(_currentPressure);
      if (_pressureHistory.length > 30) _pressureHistory.removeAt(0);
      _pressureChangeRate = -3.2;
    });
  }

  void _handleSimulateMotion() {
    setState(() {
      _isMovingVertically = !_isMovingVertically;
    });
  }

  void _handleResetSensors() {
    setState(() {
      _currentPressure = 1013.25;
      _pressureChangeRate = 0.0;
      _isMovingVertically = false;
      _pressureHistory.clear();
      _pressureHistory.add(1013.25);
    });
  }

  @override
  void dispose() {
    _barometerSub?.cancel();
    _accelerometerSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barometerState = BarometerState(
      currentPressure: _currentPressure,
      pressureChangeRate: _pressureChangeRate,
      isMovingVertically: _isMovingVertically,
      pressureHistory: _pressureHistory,
    );

    final communityMarkers = MeteoService.getSampleCommunityMarkers(
      _userLocation.latitude,
      _userLocation.longitude,
    );

    return Scaffold(
      appBar: HeaderBar(
        currentLocationName: _currentLocation.name,
        onSelectPreset: (preset) {
          setState(() {
            _currentLocation = preset;
            _userLocation = LatLng(preset.lat, preset.lng);
          });
          _loadMeteoData();
        },
        onUseGps: _useGpsLocation,
        showRadarOverlay: _showRadarOverlay,
        onToggleRadar: () {
          setState(() => _showRadarOverlay = !_showRadarOverlay);
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            MapContainer(
              userLocation: _userLocation,
              communityMarkers: communityMarkers,
              showRadarOverlay: _showRadarOverlay,
            ),
            const SizedBox(height: 16),
            WarningBanner(
              pressureChangeRate: _pressureChangeRate,
              isRainFromApi: _meteoApiData?.isRain ?? false,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SensorPanel(
                          barometer: barometerState,
                          onSimulateDrop: _handleSimulateDrop,
                          onSimulateMotion: _handleSimulateMotion,
                          onResetSensors: _handleResetSensors,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: RadarWidget(
                          meteoData: _meteoApiData,
                          loading: _loadingApi,
                          onRefresh: _loadMeteoData,
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      SensorPanel(
                        barometer: barometerState,
                        onSimulateDrop: _handleSimulateDrop,
                        onSimulateMotion: _handleSimulateMotion,
                        onResetSensors: _handleResetSensors,
                      ),
                      const SizedBox(height: 16),
                      RadarWidget(
                        meteoData: _meteoApiData,
                        loading: _loadingApi,
                        onRefresh: _loadMeteoData,
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
