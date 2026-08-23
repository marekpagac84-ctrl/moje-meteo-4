import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:latlong2/latlong.dart';

import 'models/meteo_data.dart';
import 'components/header_bar.dart';
import 'components/sensor_panel.dart';
import 'components/barometer_warning_widget.dart';
import 'components/map_container.dart';
import 'components/radar_widget.dart';
import 'components/rain_arrival_widget.dart';
import 'components/windy_map_container.dart';
import 'components/sky_analyzer_widget.dart';

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
  // ==========================================================
  // HLAVNÉ NASTAVENIA
  // ==========================================================

  bool _showRadar = true;
  bool _useWindyView = true;
  bool _isLoadingMeteo = false;

  MeteoApiData? _meteoData;

  int _currentPage = 0;

  final PageController _pageController = PageController();

  double _lat = 48.7576;
  double _lng = 17.8309;

  String _locationName = 'Nové Mesto nad Váhom';

  // ==========================================================
  // BAROMETER
  // ==========================================================

  BarometerState _barometerState = BarometerState(
    currentPressure: 0.0,
    pressureChangeRate: 0.0,
    isMovingVertically: false,
    pressureHistory: [],
    estimatedAltitude: 0.0,
    basePressure: 0.0,
  );

  // ==========================================================
  // AKCELEROMETER
  // ==========================================================

  double _accelX = 0.0;
  double _accelY = 0.0;
  double _accelZ = 0.0;

  double _accelerationMagnitude = 0.0;

  // ==========================================================
  // GYROSKOP
  // ==========================================================

  double _gyroX = 0.0;
  double _gyroY = 0.0;
  double _gyroZ = 0.0;

  double _rotationMagnitude = 0.0;

  // ==========================================================
  // MAGNETOMETER / KOMPAS
  // ==========================================================

  double _magX = 0.0;
  double _magY = 0.0;
  double _magZ = 0.0;

  double _heading = 0.0;

  // ==========================================================
  // ORIENTÁCIA
  // ==========================================================

  double _tiltX = 0.0;
  double _tiltY = 0.0;

  // ==========================================================
  // SENZORY
  // ==========================================================

  StreamSubscription<UserAccelerometerEvent>?
      _userAccelSubscription;

  StreamSubscription<AccelerometerEvent>?
      _accelerometerSubscription;

  StreamSubscription<GyroscopeEvent>?
      _gyroSubscription;

  StreamSubscription<MagnetometerEvent>?
      _magnetometerSubscription;

  StreamSubscription<BarometerEvent>?
      _pressureSubscription;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _initGpsLocation();
    _initSensors();
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _pageController.dispose();

    _userAccelSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _gyroSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _pressureSubscription?.cancel();

    super.dispose();
  }

  // ==========================================================
  // GPS
  // ==========================================================

  Future<void> _initGpsLocation() async {
    try {
      final bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (serviceEnabled) {
        LocationPermission permission =
            await Geolocator.checkPermission();

        if (permission == LocationPermission.denied) {
          permission =
              await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final Position position =
              await Geolocator.getCurrentPosition(
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

  // ==========================================================
  // VŠETKY SENZORY
  // ==========================================================

  void _initSensors() {
    _initUserAccelerometer();
    _initRawAccelerometer();
    _initGyroscope();
    _initMagnetometer();
    _initBarometer();
  }

  // ==========================================================
  // USER ACCELEROMETER
  // ==========================================================

  void _initUserAccelerometer() {
    try {
      _userAccelSubscription =
          userAccelerometerEventStream().listen(
        (event) {
          final double magnitude = math.sqrt(
            event.x * event.x +
                event.y * event.y +
                event.z * event.z,
          );

          _accelerationMagnitude = magnitude;

          _updateMovementState();
        },
        onError: (e) {
          debugPrint(
            'User accelerometer error: $e',
          );
        },
      );
    } catch (e) {
      debugPrint(
        'User accelerometer unavailable: $e',
      );
    }
  }

  // ==========================================================
  // RAW ACCELEROMETER
  // ==========================================================

  void _initRawAccelerometer() {
    try {
      _accelerometerSubscription =
          accelerometerEvents.listen(
        (event) {
          _accelX = event.x;
          _accelY = event.y;
          _accelZ = event.z;

          _calculateTilt();
        },
        onError: (e) {
          debugPrint(
            'Accelerometer error: $e',
          );
        },
      );
    } catch (e) {
      debugPrint(
        'Accelerometer unavailable: $e',
      );
    }
  }

  // ==========================================================
  // GYROSKOP
  // ==========================================================

  void _initGyroscope() {
    try {
      _gyroSubscription =
          gyroscopeEvents.listen(
        (event) {
          _gyroX = event.x;
          _gyroY = event.y;
          _gyroZ = event.z;

          _rotationMagnitude = math.sqrt(
            event.x * event.x +
                event.y * event.y +
                event.z * event.z,
          );

          _updateMovementState();
        },
        onError: (e) {
          debugPrint(
            'Gyroscope error: $e',
          );
        },
      );
    } catch (e) {
      debugPrint(
        'Gyroscope unavailable: $e',
      );
    }
  }

  // ==========================================================
  // MAGNETOMETER / KOMPAS
  // ==========================================================

  void _initMagnetometer() {
    try {
      _magnetometerSubscription =
          magnetometerEvents.listen(
        (event) {
          _magX = event.x;
          _magY = event.y;
          _magZ = event.z;

          _calculateHeading();
        },
        onError: (e) {
          debugPrint(
            'Magnetometer error: $e',
          );
        },
      );
    } catch (e) {
      debugPrint(
        'Magnetometer unavailable: $e',
      );
    }
  }

  // ==========================================================
  // BAROMETER
  // ==========================================================

  void _initBarometer() {
    try {
      _pressureSubscription =
          barometerEventStream().listen(
        (event) {
          final double newPressure = event.pressure;

          if (newPressure <= 0 || !mounted) {
            return;
          }

          final List<PressurePoint> history =
              List<PressurePoint>.from(
            _barometerState.pressureHistory,
          );

          final double oldPressure =
              _barometerState.currentPressure;

          double rate = 0.0;

          if (oldPressure > 0) {
            rate = newPressure - oldPressure;
          }

          history.add(
            PressurePoint(
              timestamp: DateTime.now(),
              pressure: newPressure,
            ),
          );

          if (history.length > 60) {
            history.removeAt(0);
          }

          double base =
              _barometerState.basePressure;

          if (base <= 0) {
            base = newPressure;
          }

          final double altitude =
              (base - newPressure) * 8.43;

          setState(() {
            _barometerState =
                _barometerState.copyWith(
              currentPressure: newPressure,
              pressureChangeRate: rate,
              estimatedAltitude: altitude,
              pressureHistory: history,
            );
          });
        },
        onError: (e) {
          debugPrint(
            'Barometer error: $e',
          );
        },
      );
    } catch (e) {
      debugPrint(
        'Barometer unavailable: $e',
      );
    }
  }

  // ==========================================================
  // POHYB
  // ==========================================================

  void _updateMovementState() {
    if (!mounted) return;

    final bool accelerationMovement =
        _accelerationMagnitude > 2.0;

    final bool rotationMovement =
        _rotationMagnitude > 1.2;

    final bool moving =
        accelerationMovement ||
        rotationMovement;

    if (moving !=
        _barometerState.isMovingVertically) {
      setState(() {
        _barometerState =
            _barometerState.copyWith(
          isMovingVertically: moving,
        );
      });
    }
  }

  // ==========================================================
  // NÁKLON TELEFÓNU
  // ==========================================================

  void _calculateTilt() {
    final double denominator = math.sqrt(
      _accelY * _accelY +
          _accelZ * _accelZ,
    );

    if (denominator == 0) {
      return;
    }

    final double tiltX =
        math.atan2(
          _accelX,
          denominator,
        ) *
        180 /
        math.pi;

    final double tiltY =
        math.atan2(
          _accelY,
          _accelZ,
        ) *
        180 /
        math.pi;

    _tiltX = tiltX;
    _tiltY = tiltY;
  }

  // ==========================================================
  // KOMPAS
  // ==========================================================

  void _calculateHeading() {
    double heading =
        math.atan2(
          _magY,
          _magX,
        ) *
        180 /
        math.pi;

    if (heading < 0) {
      heading += 360;
    }

    _heading = heading;
  }

  // ==========================================================
  // METEO API
  // ==========================================================

  Future<void> _fetchWeatherData() async {
    if (!mounted) return;

    setState(() {
      _isLoadingMeteo = true;
    });

    try {
      final Uri url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$_lat'
        '&longitude=$_lng'
        '&current_weather=true'
        '&hourly='
        'precipitation_probability,'
        'precipitation,'
        'wind_direction_10m,'
        'surface_pressure'
        '&forecast_hours=12',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(response.body)
                as Map<String, dynamic>;

        final MeteoApiData meteo =
            MeteoApiData.fromJson(data);

        if (!mounted) return;

        setState(() {
          _meteoData = meteo;
          _isLoadingMeteo = false;
        });
      } else {
        if (!mounted) return;

        setState(() {
          _isLoadingMeteo = false;
        });
      }
    } catch (e) {
      debugPrint(
        'Meteo API error: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoadingMeteo = false;
      });
    }
  }

  // ==========================================================
  // SIMULÁCIA POKLESU TLAKU
  // ==========================================================

  void _simulatePressureDrop() {
    setState(() {
      final double newPressure =
          _barometerState.currentPressure - 3.5;

      final List<PressurePoint> history =
          List<PressurePoint>.from(
        _barometerState.pressureHistory,
      );

      history.add(
        PressurePoint(
          timestamp: DateTime.now(),
          pressure: newPressure,
        ),
      );

      _barometerState =
          _barometerState.copyWith(
        currentPressure: newPressure,
        pressureChangeRate: -3.5,
        pressureHistory: history,
      );
    });
  }

  // ==========================================================
  // SIMULÁCIA POHYBU
  // ==========================================================

  void _simulateMotionToggle() {
    setState(() {
      _barometerState =
          _barometerState.copyWith(
        isMovingVertically:
            !_barometerState.isMovingVertically,
      );
    });
  }

  // ==========================================================
  // MAPA
  // ==========================================================

  void _openFullMap() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setModalState,
          ) {
            return Container(
              height:
                  MediaQuery.of(context).size.height *
                      0.88,
              decoration:
                  const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius:
                    BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Živá radarová mapa',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  _useWindyView =
                                      !_useWindyView;
                                });
                              },
                              icon: Icon(
                                _useWindyView
                                    ? Icons.map
                                    : Icons.thunderstorm,
                                color:
                                    Colors.blueAccent,
                                size: 18,
                              ),
                              label: Text(
                                _useWindyView
                                    ? 'Základná'
                                    : 'Windy',
                                style: const TextStyle(
                                  color:
                                      Colors.blueAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color:
                                    Colors.white70,
                              ),
                              onPressed: () =>
                                  Navigator.pop(
                                context,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    color: Colors.white12,
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                      child: _useWindyView
                          ? WindyMapContainer(
                              lat: _lat,
                              lng: _lng,
                            )
                          : (_showRadar
                              ? RadarWidget(
                                  lat: _lat,
                                  lng: _lng,
                                )
                              : MapContainer(
                                  center: LatLng(
                                    _lat,
                                    _lng,
                                  ),
                                )),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            HeaderBar(
              currentLocationName:
                  _locationName,
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
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller:
                          _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      children: [
                        // =================================================
                        // STRÁNKA 1 – DÁŽĎ
                        // =================================================

                        Padding(
                          padding:
                              const EdgeInsets.all(16),
                          child:
                              SingleChildScrollView(
                            child:
                                RainArrivalWidget(
                              meteoData:
                                  _meteoData,
                              isLoading:
                                  _isLoadingMeteo,
                              onRefresh:
                                  _fetchWeatherData,
                              onOpenMap:
                                  _openFullMap,
                            ),
                          ),
                        ),

                        // =================================================
                        // STRÁNKA 2 – SENZORY
                        // =================================================

                        Padding(
                          padding:
                              const EdgeInsets.all(16),
                          child:
                              SingleChildScrollView(
                            child: Column(
                              children: [
                                SensorPanel(
                                  barometer:
                                      _barometerState,
                                  onSimulateDrop:
                                      _simulatePressureDrop,
                                  onSimulateMotion:
                                      _simulateMotionToggle,
                                  onResetSensors: () {
                                    setState(() {
                                      _barometerState =
                                          _barometerState
                                              .copyWith(
                                        basePressure:
                                            _barometerState
                                                .currentPressure,
                                        pressureChangeRate:
                                            0.0,
                                        estimatedAltitude:
                                            0.0,
                                      );
                                    });
                                  },
                                ),

                                const SizedBox(
                                  height: 12,
                                ),

                                BarometerWarningWidget(
                                  barometer:
                                      _barometerState,
                                ),

                                const SizedBox(
                                  height: 12,
                                ),

                                _buildAdditionalSensorsPanel(),
                              ],
                            ),
                          ),
                        ),

                        // =================================================
                        // STRÁNKA 3 – SKY ANALYZER
                        // =================================================

                        Padding(
                          padding:
                              const EdgeInsets.all(16),
                          child: SkyAnalyzerWidget(
                            lat: _lat,
                            lng: _lng,
                            heading: _heading,
                            tiltX: _tiltX,
                            tiltY: _tiltY,
                            barometer:
                                _barometerState,
                            meteoData:
                                _meteoData,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // =======================================================
                  // INDIKÁTOR STRÁNOK
                  // =======================================================

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children:
                        List.generate(
                      3,
                      (index) {
                        return AnimatedContainer(
                          duration:
                              const Duration(
                            milliseconds: 300,
                          ),
                          margin:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                          width:
                              _currentPage == index
                                  ? 20
                                  : 8,
                          height: 8,
                          decoration:
                              BoxDecoration(
                            color:
                                _currentPage ==
                                        index
                                    ? Colors
                                        .blueAccent
                                    : Colors
                                        .white24,
                            borderRadius:
                                BorderRadius.circular(
                              4,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // PANEL ĎALŠÍCH SENZOROV
  // ==========================================================

  Widget _buildAdditionalSensorsPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            '📱 ĎALŠIE SENZORY',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 14),

          _sensorRow(
            '🔄 Gyroskop',
            '${_rotationMagnitude.toStringAsFixed(2)} rad/s',
          ),

          _sensorRow(
            '🧭 Kompas',
            '${_heading.toStringAsFixed(0)}°',
          ),

          _sensorRow(
            '📐 Náklon X',
            '${_tiltX.toStringAsFixed(1)}°',
          ),

          _sensorRow(
            '📐 Náklon Y',
            '${_tiltY.toStringAsFixed(1)}°',
          ),

          _sensorRow(
            '⚡ Akcelerácia',
            '${_accelerationMagnitude.toStringAsFixed(2)} m/s²',
          ),

          const Divider(
            color: Colors.white12,
            height: 24,
          ),

          _sensorRow(
            'X akcelerometer',
            _accelX.toStringAsFixed(2),
          ),

          _sensorRow(
            'Y akcelerometer',
            _accelY.toStringAsFixed(2),
          ),

          _sensorRow(
            'Z akcelerometer',
            _accelZ.toStringAsFixed(2),
          ),

          const Divider(
            color: Colors.white12,
            height: 24,
          ),

          _sensorRow(
            'Magnetometer X',
            _magX.toStringAsFixed(1),
          ),

          _sensorRow(
            'Magnetometer Y',
            _magY.toStringAsFixed(1),
          ),

          _sensorRow(
            'Magnetometer Z',
            _magZ.toStringAsFixed(1),
          ),

          const SizedBox(height: 8),

          const Text(
            'Tieto údaje môžeme použiť pri filtrovaní '
            'pohybu a pri vytváraní meteorologického modelu.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // RIADOK SENZORA
  // ==========================================================

  Widget _sensorRow(
    String name,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
