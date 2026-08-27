import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/meteo_data.dart';
import '../services/cloud_classifier_service.dart';
import '../services/sky_context_service.dart';

class RainArrivalWidget extends StatefulWidget {
  final MeteoApiData? meteoData;
  final bool isLoading;
  final VoidCallback onRefresh;
  final VoidCallback onOpenMap;

  const RainArrivalWidget({
    super.key,
    required this.meteoData,
    required this.isLoading,
    required this.onRefresh,
    required this.onOpenMap,
  });

  @override
  State<RainArrivalWidget> createState() => _RainArrivalWidgetState();
}

class _RainArrivalWidgetState extends State<RainArrivalWidget>
    with SingleTickerProviderStateMixin {
  final SkyContextService _contextService = SkyContextService();
  final CloudClassifierService _cloudClassifier = CloudClassifierService();
  final ImagePicker _picker = ImagePicker();

  StreamSubscription<BarometerEvent>? _barometerSub;
  StreamSubscription<MagnetometerEvent>? _magnetometerSub;
  late final AnimationController _sceneController;

  SkyContextResult? _context;
  Position? _position;

  double? _devicePressure;
  double? _altitude;
  double _heading = 0.0;

  bool _contextLoading = true;
  bool _analyzing = false;
  String? _error;

  String? _cloudName;
  String? _cloudCode;
  double? _cloudConfidence;
  DateTime? _lastAnalysis;

  @override
  void initState() {
    super.initState();
    _sceneController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _startSensors();
    _loadContext();
  }

  @override
  void dispose() {
    _sceneController.dispose();
    _barometerSub?.cancel();
    _magnetometerSub?.cancel();
    _cloudClassifier.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RainArrivalWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meteoData != widget.meteoData && widget.meteoData != null) {
      _recalculateAltitude();
    }
  }

  void _startSensors() {
    try {
      _barometerSub = barometerEventStream().listen(
        (event) {
          if (!mounted) return;
          setState(() {
            _devicePressure = event.pressure;
            _recalculateAltitude();
          });
        },
        onError: (_) {},
      );
    } catch (_) {}

    try {
      _magnetometerSub = magnetometerEventStream().listen(
        (event) {
          final radians = math.atan2(event.y, event.x);
          var degrees = radians * 180 / math.pi;
          degrees = (degrees + 360) % 360;
          if (!mounted) return;
          setState(() => _heading = degrees);
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  Future<Position> _getPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('Zapni polohu / GPS.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Aplikácia nemá povolenie používať polohu.');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _loadContext() async {
    if (mounted) {
      setState(() {
        _contextLoading = true;
        _error = null;
      });
    }

    try {
      final position = await _getPosition();
      final result = await _contextService.load(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;
      setState(() {
        _position = position;
        _context = result;
        _contextLoading = false;
        _recalculateAltitude();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _contextLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _refreshEverything() async {
    widget.onRefresh();
    await _loadContext();
  }

  void _recalculateAltitude() {
    final ctx = _context;
    if (_devicePressure != null && ctx != null && ctx.seaLevelPressure > 0) {
      _altitude = SkyContextService.pressureAltitude(
        pressure: _devicePressure!,
        seaLevelPressure: ctx.seaLevelPressure,
      );
      return;
    }
    if (_position != null) {
      _altitude = _position!.altitude;
    }
  }

  Future<void> _analyzeSky() async {
    if (_analyzing) return;

    setState(() {
      _analyzing = true;
      _error = null;
    });

    try {
      final photoHeading = _heading;
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 1920,
      );

      if (photo == null) {
        if (mounted) setState(() => _analyzing = false);
        return;
      }

      final Uint8List bytes = await photo.readAsBytes();
      final classification = await _cloudClassifier.classify(bytes);
      final position = await _getPosition();
      final context = await _contextService.load(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;
      setState(() {
        _heading = photoHeading;
        _position = position;
        _context = context;
        _cloudName = classification?.name;
        _cloudCode = classification?.code;
        _cloudConfidence = classification?.confidence;
        _lastAnalysis = DateTime.now();
        _analyzing = false;
        _recalculateAltitude();
      });

      _showAiDetail();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  MeteoApiData? get _meteo => widget.meteoData;
  SkyContextResult? get _ctx => _context;

  double get _temperature => _ctx?.temperature ?? _meteo?.currentTemperature ?? 0;
  double get _apparentTemperature => _ctx?.apparentTemperature ?? _temperature;
  double get _humidity => _ctx?.humidity ?? _currentHourlyValue(_meteo?.hourlyHumidity) ?? 0;
  double get _windSpeed => _ctx?.windSpeed ?? _meteo?.currentWindSpeed ?? 0;
  double get _windDirection => _ctx?.windDirection ?? _meteo?.currentWindDirection ?? 0;
  double get _pressure => _devicePressure ?? _ctx?.surfacePressure ?? _meteo?.currentPressure ?? 0;
  int get _weatherCode => _meteo?.currentWeatherCode ?? _ctx?.nextRainWeatherCode ?? 0;

  T? _currentHourlyValue<T>(List<T>? values) {
    if (values == null || values.isEmpty || _meteo == null) return null;
    final i = _meteo!.currentHourlyIndex.clamp(0, values.length - 1).toInt();
    return values[i];
  }

  bool get _isNight {
    final data = _meteo;
    if (data?.dailySunrise != null &&
        data!.dailySunrise!.isNotEmpty &&
        data.dailySunset != null &&
        data.dailySunset!.isNotEmpty) {
      final sunrise = DateTime.tryParse(data.dailySunrise!.first);
      final sunset = DateTime.tryParse(data.dailySunset!.first);
      final now = DateTime.now();
      if (sunrise != null && sunset != null) {
        return now.isBefore(sunrise) || now.isAfter(sunset);
      }
    }
    final hour = DateTime.now().hour;
    return hour < 6 || hour >= 20;
  }

  bool get _rainCloud => _cloudCode == 'Cb' || _cloudCode == 'Ns';
  bool get _stormCloud => _cloudCode == 'Cb';

  double get _arrivalDirectionDifference {
    final ctx = _ctx;
    if (ctx == null) return 180;
    return SkyContextService.circularDifference(_heading, ctx.windDirection);
  }

  String get _aiHeadline {
    final ctx = _ctx;
    if (_analyzing) return 'Pozerám sa na oblohu…';
    if (ctx == null) return 'AI analýza oblohy';

    final minutes = ctx.nextRainMinutes;
    if (ctx.stormSignal && minutes != null && minutes <= 120) {
      return 'Búrkový signál sa približuje';
    }
    if (minutes != null && minutes <= 60) {
      return 'Dážď ${SkyContextService.formatMinutes(minutes)}';
    }
    if (_stormCloud) return 'Toto už nie je oblak na okrasu';
    if (_rainCloud) return 'Tento oblak stojí za pozornosť';
    if (_cloudName != null) return 'Vidím $_cloudName';
    if (ctx.modelsAgreeOnDry) return 'Dáždnik môže zatiaľ oddychovať';
    if (ctx.modelsDisagree) return 'Modely sa hádajú. Pozrime sa hore.';
    return 'AI analýza oblohy';
  }

  String get _aiSubtitle {
    final ctx = _ctx;
    if (ctx == null) return 'Kamera + ECMWF + Open-Meteo + senzory';

    final minutes = ctx.nextRainMinutes;
    if (_cloudName == null) {
      if (minutes != null) {
        return 'Najbližší dážď ${SkyContextService.formatMinutes(minutes)} • jedna fotka a preveríme to';
      }
      return 'Jedna fotka • typ oblaku • smer • tlak • modely';
    }

    if (_rainCloud && ctx.modelsAgreeOnRain) {
      if (_arrivalDirectionDifference <= 50) {
        return 'To, čo vidíš, môže súvisieť s prichádzajúcim počasím';
      }
      if (_arrivalDirectionDifference >= 130) {
        return 'Pozor — hlavné počasie môže prichádzať spoza teba';
      }
      return 'Zrážkový systém môže prichádzať skôr zboku';
    }

    if (minutes != null && minutes <= 120) {
      if (_arrivalDirectionDifference >= 130) {
        return 'To pred tebou nemusí byť problém. Niečo však môže prísť zozadu.';
      }
      return 'Modely čakajú zrážky. Kamera ich zatiaľ úplne nepotvrdzuje.';
    }

    if (ctx.modelsAgreeOnDry) return 'Obloha aj modely zatiaľ pôsobia pokojne';
    return 'Klikni a pozri kompletnú analýzu';
  }

  String get _weatherTitle {
    final code = _weatherCode;
    if (code == 0) return _isNight ? 'Jasná noc' : 'Jasno';
    if (code == 1) return 'Prevažne jasno';
    if (code == 2) return 'Polooblačno';
    if (code == 3) return 'Zamračené';
    if (code == 45 || code == 48) return 'Hmla';
    if ([51, 53, 55, 56, 57].contains(code)) return 'Mrholenie';
    if ([61, 63, 65, 66, 67, 80, 81, 82].contains(code)) return 'Dážď';
    if ([71, 73, 75, 77, 85, 86].contains(code)) return 'Sneženie';
    if ([95, 96, 99].contains(code)) return 'Búrka';
    return 'Aktuálne počasie';
  }

  String get _humanWeatherComment {
    final ctx = _ctx;
    if (ctx?.stormSignal == true) return 'Atmosféra dnes nechce byť nenápadná.';
    if (_weatherCode == 0 && !_isNight) return 'Obloha dnes hrá na čistotu.';
    if (_weatherCode == 0 && _isNight) return 'Pokojná noc. Radar zatiaľ nešomre.';
    if (ctx?.nextRainMinutes != null && ctx!.nextRainMinutes! <= 60) {
      return 'Dáždnik by som úplne ďaleko neodkladal.';
    }
    if (ctx?.modelsAgreeOnDry == true) return 'Zatiaľ pokoj. Dáždnik môže oddychovať.';
    if (ctx?.modelsDisagree == true) return 'Modely majú rozdielny názor. O to zaujímavejšie.';
    return 'Počasie zatiaľ bez veľkej drámy.';
  }

  IconData _weatherIcon(int code) {
    if (code == 0) return _isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded;
    if (code <= 2) return _isNight ? Icons.nights_stay_rounded : Icons.wb_cloudy_rounded;
    if (code == 3) return Icons.cloud_rounded;
    if (code == 45 || code == 48) return Icons.blur_on_rounded;
    if ([51, 53, 55, 56, 57].contains(code)) return Icons.grain_rounded;
    if ([61, 63, 65, 66, 67, 80, 81, 82].contains(code)) return Icons.water_drop_rounded;
    if ([71, 73, 75, 77, 85, 86].contains(code)) return Icons.ac_unit_rounded;
    if ([95, 96, 99].contains(code)) return Icons.thunderstorm_rounded;
    return Icons.cloud_queue_rounded;
  }

  Color get _accent {
    if (_ctx?.stormSignal == true || [95, 96, 99].contains(_weatherCode)) {
      return const Color(0xFFC49BFF);
    }
    if (_ctx?.rainExpectedNext6Hours == true ||
        [51, 53, 55, 61, 63, 65, 80, 81, 82].contains(_weatherCode)) {
      return const Color(0xFF62D2FF);
    }
    if (_isNight) return const Color(0xFF8DA9FF);
    return const Color(0xFFFFD56A);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        Transform.translate(
          offset: const Offset(0, -18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _buildAiBanner(),
          ),
        ),
        if (_error != null) ...[
          Transform.translate(
            offset: const Offset(0, -8),
            child: _buildError(),
          ),
        ],
        Transform.translate(
          offset: const Offset(0, -4),
          child: _buildNextRainCard(),
        ),
        const SizedBox(height: 10),
        _buildQuickMetrics(),
        const SizedBox(height: 12),
        _buildHourlyForecast(),
        const SizedBox(height: 12),
        _buildDailyForecast(),
        const SizedBox(height: 12),
        _buildSunAndAtmosphere(),
        const SizedBox(height: 12),
        _buildActionRow(),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _buildHero() {
    final loading = widget.isLoading || (_contextLoading && _meteo == null);

    return AnimatedBuilder(
      animation: _sceneController,
      builder: (context, _) {
        return GestureDetector(
          onTap: _showCurrentWeatherDetail,
          child: Container(
            height: 390,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              gradient: _heroGradient(),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(0.20),
                  blurRadius: 42,
                  spreadRadius: -10,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.36),
                  blurRadius: 34,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _WeatherScenePainter(
                        animation: _sceneController.value,
                        weatherCode: _weatherCode,
                        isNight: _isNight,
                        heading: _heading,
                      ),
                    ),
                  ),

                  // Jemný tmavý prechod pre čitateľnosť textu.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.04),
                            Colors.transparent,
                            Colors.black.withOpacity(0.34),
                          ],
                          stops: const [0.0, 0.54, 1.0],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 18,
                    left: 18,
                    right: 18,
                    child: Row(
                      children: [
                        _glassPill(
                          icon: Icons.location_on_rounded,
                          text: 'MOJE METEO • LIVE',
                        ),
                        const Spacer(),
                        _roundHeroButton(
                          icon: Icons.refresh_rounded,
                          onTap: _refreshEverything,
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    left: 22,
                    right: 22,
                    top: 78,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (loading)
                                    const SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    Text(
                                      '${_temperature.toStringAsFixed(0)}°',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 82,
                                        height: 0.90,
                                        fontWeight: FontWeight.w200,
                                        letterSpacing: -6,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _weatherTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _humanWeatherComment,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 12,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Transform.translate(
                              offset: Offset(
                                math.sin(_sceneController.value * math.pi * 2) * 5,
                                math.cos(_sceneController.value * math.pi * 2) * 2.5,
                              ),
                              child: _heroWeatherOrb(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // "Živé" údaje plávajú priamo nad krajinou.
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 27,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF07111D).withOpacity(0.50),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withOpacity(0.11)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _heroMetric(
                              icon: Icons.thermostat_rounded,
                              value: '${_apparentTemperature.toStringAsFixed(0)}°',
                              label: 'Pocitovo',
                              onTap: () => _showParameterSheet(_MetricType.temperature),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _heroMetric(
                              icon: Icons.water_drop_outlined,
                              value: '${_humidity.toStringAsFixed(0)}%',
                              label: 'Vlhkosť',
                              onTap: () => _showParameterSheet(_MetricType.humidity),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _heroMetric(
                              icon: Icons.air_rounded,
                              value: '${_windSpeed.toStringAsFixed(0)} km/h',
                              label: SkyContextService.directionName(_windDirection),
                              onTap: () => _showParameterSheet(_MetricType.wind),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _heroMetric(
                              icon: Icons.speed_rounded,
                              value: _pressure > 0 ? _pressure.toStringAsFixed(0) : '—',
                              label: 'hPa',
                              onTap: () => _showParameterSheet(_MetricType.pressure),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    right: 20,
                    top: 205,
                    child: GestureDetector(
                      onTap: _showAltitudeInfo,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF07111D).withOpacity(0.42),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.10)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.terrain_rounded, color: Colors.white70, size: 14),
                            const SizedBox(width: 5),
                            Text(
                              _altitude == null
                                  ? 'Výška —'
                                  : '${_altitude!.toStringAsFixed(0)} m n. m.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  LinearGradient _heroGradient() {
    if (_ctx?.stormSignal == true || [95, 96, 99].contains(_weatherCode)) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF090A17),
          Color(0xFF201B3E),
          Color(0xFF4D365D),
          Color(0xFF182536),
        ],
        stops: [0.0, 0.35, 0.66, 1.0],
      );
    }
    if (_ctx?.rainExpectedNext6Hours == true ||
        [51, 53, 55, 61, 63, 65, 80, 81, 82].contains(_weatherCode)) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF071421),
          Color(0xFF17364B),
          Color(0xFF3D6470),
          Color(0xFF172A31),
        ],
        stops: [0.0, 0.36, 0.68, 1.0],
      );
    }
    if (_isNight) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF030817),
          Color(0xFF0E2148),
          Color(0xFF293C69),
          Color(0xFF101C2F),
        ],
        stops: [0.0, 0.38, 0.70, 1.0],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF073659),
        Color(0xFF167FA5),
        Color(0xFF6DB7C0),
        Color(0xFF345F58),
      ],
      stops: [0.0, 0.36, 0.68, 1.0],
    );
  }

  Widget _heroWeatherOrb() {
    return Container(
      width: 116,
      height: 116,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(0.18),
            _accent.withOpacity(0.15),
            Colors.transparent,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.07),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, _accent],
            ).createShader(bounds),
            child: Icon(
              _weatherIcon(_weatherCode),
              size: 58,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassPill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.11)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundHeroButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
      ),
    );
  }

  Widget _heroMetric({
    required IconData icon,
    required String value,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.09),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white70, size: 15),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiBanner() {
    final accent = _ctx?.stormSignal == true
        ? const Color(0xFFC49BFF)
        : _ctx?.rainExpectedNext6Hours == true
            ? const Color(0xFFFFBF69)
            : const Color(0xFF69E2C2);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showAiDetail,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF101927), Color(0xFF111F31)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withOpacity(0.28)),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(
                      colors: [accent.withOpacity(0.30), accent.withOpacity(0.08)],
                    ),
                  ),
                  child: Icon(Icons.psychology_alt_rounded, color: accent, size: 25),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'AI ANALÝZA OBLOHY',
                            style: TextStyle(
                              color: accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (_lastAnalysis != null) ...[
                            const SizedBox(width: 5),
                            Icon(Icons.check_circle_rounded, color: accent, size: 12),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _aiHeadline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _aiSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.52), fontSize: 10),
                      ),
                    ],
                  ),
                ),
                if (_analyzing)
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Odfotiť oblohu',
                    onPressed: _analyzeSky,
                    icon: const Icon(Icons.camera_alt_rounded),
                    color: accent,
                  ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNextRainCard() {
    final ctx = _ctx;
    final minutes = ctx?.nextRainMinutes ?? _meteo?.rainArrivalMinutes;
    final probability = ctx?.nextRainProbability ?? _currentHourlyValue(_meteo?.hourlyPrecipitationProbability);
    final amount = ctx?.nextRainAmount ?? _currentHourlyValue(_meteo?.hourlyPrecipitation);

    final title = minutes == null
        ? 'Najbližší dážď sa zatiaľ nehlási'
        : 'Dážď ${SkyContextService.formatMinutes(minutes)}';
    final subtitle = minutes == null
        ? 'Modely momentálne nevidia jasný zrážkový nástup v blízkom horizonte.'
        : '${ctx?.nextRainTime == null ? '' : 'Okolo ${SkyContextService.formatClock(ctx!.nextRainTime!)} • '}${ctx?.precipitationDescription ?? 'zrážky'}';

    return _sectionCard(
      onTap: () => _showParameterSheet(_MetricType.rain),
      accent: ctx?.stormSignal == true ? const Color(0xFFC49BFF) : const Color(0xFF62D2FF),
      icon: ctx?.stormSignal == true ? Icons.thunderstorm_rounded : Icons.umbrella_rounded,
      title: title,
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
      child: Row(
        children: [
          Expanded(
            child: _smallStat(
              'Pravdepodobnosť',
              probability == null ? '—' : '$probability %',
            ),
          ),
          _dividerVertical(),
          Expanded(
            child: _smallStat(
              'Množstvo',
              amount == null ? '—' : '${amount.toStringAsFixed(1)} mm',
            ),
          ),
          _dividerVertical(),
          Expanded(
            child: _smallStat(
              'Modely',
              ctx == null
                  ? '—'
                  : ctx.modelsAgreeOnRain
                      ? 'ZHODA'
                      : ctx.modelsDisagree
                          ? 'ROZPOR'
                          : 'POKOJ',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMetrics() {
    final pressureTrend = _pressureTrendText();
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.72,
      children: [
        _metricTile(
          icon: Icons.thermostat_rounded,
          label: 'Teplota',
          value: '${_temperature.toStringAsFixed(1)} °C',
          hint: 'Pocitovo ${_apparentTemperature.toStringAsFixed(1)}°',
          accent: const Color(0xFFFFB86C),
          onTap: () => _showParameterSheet(_MetricType.temperature),
        ),
        _metricTile(
          icon: Icons.water_drop_rounded,
          label: 'Vlhkosť',
          value: '${_humidity.toStringAsFixed(0)} %',
          hint: _humidity >= 80 ? 'Vzduch má vody dosť.' : 'Relatívna vlhkosť',
          accent: const Color(0xFF63D7FF),
          onTap: () => _showParameterSheet(_MetricType.humidity),
        ),
        _metricTile(
          icon: Icons.air_rounded,
          label: 'Vietor',
          value: '${_windSpeed.toStringAsFixed(1)} km/h',
          hint: '${SkyContextService.longDirectionName(_windDirection)} • ${_windDirection.toStringAsFixed(0)}°',
          accent: const Color(0xFF75E6C1),
          onTap: () => _showParameterSheet(_MetricType.wind),
        ),
        _metricTile(
          icon: Icons.speed_rounded,
          label: 'Tlak',
          value: _pressure > 0 ? '${_pressure.toStringAsFixed(1)} hPa' : '—',
          hint: pressureTrend,
          accent: const Color(0xFFB49BFF),
          onTap: () => _showParameterSheet(_MetricType.pressure),
        ),
      ],
    );
  }

  Widget _buildHourlyForecast() {
    final data = _meteo;
    if (data == null || data.hourlyTimes == null || data.hourlyTimes!.isEmpty) {
      return _sectionCard(
        icon: Icons.schedule_rounded,
        title: 'Najbližšie hodiny',
        subtitle: 'Načítavam hodinovú predpoveď…',
        child: const SizedBox(height: 50),
      );
    }

    final start = data.currentHourlyIndex;
    final end = math.min(start + 10, data.hourlyTimes!.length);

    return _sectionCard(
      icon: Icons.schedule_rounded,
      title: 'Najbližšie hodiny',
      subtitle: 'Klikni na hodinu a ukážem všetky dostupné údaje.',
      child: SizedBox(
        height: 132,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: end - start,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, offset) {
            final i = start + offset;
            final temp = data.temperatureAt(i);
            final code = data.weatherCodeAt(i) ?? 0;
            final rain = data.precipitationProbabilityAt(i);
            return GestureDetector(
              onTap: () => _showHourDetail(i),
              child: Container(
                width: 76,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 7),
                decoration: BoxDecoration(
                  color: offset == 0
                      ? _accent.withOpacity(0.12)
                      : Colors.white.withOpacity(0.035),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: offset == 0
                        ? _accent.withOpacity(0.25)
                        : Colors.white.withOpacity(0.055),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      offset == 0 ? 'TERAZ' : data.formattedHourlyTime(i),
                      style: TextStyle(
                        color: offset == 0 ? _accent : Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Icon(_weatherIcon(code), color: Colors.white, size: 25),
                    const Spacer(),
                    Text(
                      temp == null ? '—' : '${temp.toStringAsFixed(0)}°',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.water_drop, size: 10, color: Color(0xFF63D7FF)),
                        const SizedBox(width: 2),
                        Text(
                          rain == null ? '—' : '$rain%',
                          style: const TextStyle(color: Colors.white54, fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDailyForecast() {
    final data = _meteo;
    final times = data?.dailyTimes;
    if (data == null || times == null || times.isEmpty) return const SizedBox.shrink();

    final count = math.min(5, times.length);
    return _sectionCard(
      icon: Icons.calendar_month_rounded,
      title: 'Ďalšie dni',
      subtitle: 'Rýchly pohľad na vývoj počasia.',
      child: Column(
        children: List.generate(count, (i) {
          final date = DateTime.tryParse(times[i]);
          final maxT = _listValue(data.dailyTemperatureMax, i);
          final minT = _listValue(data.dailyTemperatureMin, i);
          final code = _listValue(data.dailyWeatherCode, i) ?? 0;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _showDayDetail(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 74,
                    child: Text(
                      i == 0 ? 'Dnes' : _weekdayName(date?.weekday),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Icon(_weatherIcon(code), color: _accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _weatherTitleForCode(code),
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
                  Text(
                    '${maxT?.toStringAsFixed(0) ?? '—'}°',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${minT?.toStringAsFixed(0) ?? '—'}°',
                    style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  T? _listValue<T>(List<T>? list, int index) {
    if (list == null || index < 0 || index >= list.length) return null;
    return list[index];
  }

  String _weekdayName(int? weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Pondelok';
      case DateTime.tuesday:
        return 'Utorok';
      case DateTime.wednesday:
        return 'Streda';
      case DateTime.thursday:
        return 'Štvrtok';
      case DateTime.friday:
        return 'Piatok';
      case DateTime.saturday:
        return 'Sobota';
      case DateTime.sunday:
        return 'Nedeľa';
      default:
        return '—';
    }
  }

  String _weatherTitleForCode(int code) {
    if (code == 0) return 'Jasno';
    if (code == 1) return 'Prevažne jasno';
    if (code == 2) return 'Polooblačno';
    if (code == 3) return 'Zamračené';
    if (code == 45 || code == 48) return 'Hmla';
    if ([51, 53, 55, 56, 57].contains(code)) return 'Mrholenie';
    if ([61, 63, 65, 66, 67, 80, 81, 82].contains(code)) return 'Dážď';
    if ([71, 73, 75, 77, 85, 86].contains(code)) return 'Sneh';
    if ([95, 96, 99].contains(code)) return 'Búrka';
    return 'Premenlivé';
  }

  Widget _buildSunAndAtmosphere() {
    final sunrise = _meteo?.dailySunrise?.isNotEmpty == true
        ? DateTime.tryParse(_meteo!.dailySunrise!.first)
        : null;
    final sunset = _meteo?.dailySunset?.isNotEmpty == true
        ? DateTime.tryParse(_meteo!.dailySunset!.first)
        : null;

    return _sectionCard(
      icon: Icons.public_rounded,
      title: 'Atmosféra a deň',
      subtitle: 'Detaily, ktoré sa hodia, keď chceš vedieť viac než len teplotu.',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _miniInfoTile(
                  icon: Icons.wb_twilight_rounded,
                  title: 'Východ',
                  value: sunrise == null ? '—' : SkyContextService.formatClock(sunrise),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniInfoTile(
                  icon: Icons.nights_stay_rounded,
                  title: 'Západ',
                  value: sunset == null ? '—' : SkyContextService.formatClock(sunset),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _showAltitudeInfo,
                  child: _miniInfoTile(
                    icon: Icons.terrain_rounded,
                    title: 'Výška',
                    value: _altitude == null ? '—' : '${_altitude!.toStringAsFixed(0)} m',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _atmosphereStatusStrip(),
        ],
      ),
    );
  }

  Widget _atmosphereStatusStrip() {
    final ctx = _ctx;
    String text;
    IconData icon;
    Color accent;

    if (ctx?.stormSignal == true) {
      text = 'Búrkový signál: atmosféra má dnes ambície.';
      icon = Icons.thunderstorm_rounded;
      accent = const Color(0xFFC49BFF);
    } else if (ctx?.modelsDisagree == true) {
      text = 'ECMWF a Open-Meteo sa nezhodujú. Kamera a radar tu majú väčšiu cenu.';
      icon = Icons.compare_arrows_rounded;
      accent = const Color(0xFFFFC66D);
    } else if (ctx?.modelsAgreeOnRain == true) {
      text = 'Modely sa zhodujú na zrážkovom scenári.';
      icon = Icons.verified_rounded;
      accent = const Color(0xFF62D2FF);
    } else {
      text = 'Modely momentálne podporujú pokojnejší scenár.';
      icon = Icons.check_circle_outline_rounded;
      accent = const Color(0xFF69E2C2);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _refreshEverything,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Obnoviť'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.12)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: widget.onOpenMap,
            icon: const Icon(Icons.radar_rounded),
            label: const Text('Radar / mapa'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 50),
              backgroundColor: const Color(0xFF1D80B7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    VoidCallback? onTap,
    Color? accent,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    final active = accent ?? const Color(0xFF7BCFD8);
    final body = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF12202A).withOpacity(0.96),
            const Color(0xFF0B151F).withOpacity(0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: active.withOpacity(accent == null ? 0.08 : 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          if (accent != null)
            BoxShadow(
              color: active.withOpacity(0.05),
              blurRadius: 22,
              spreadRadius: -5,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      active.withOpacity(0.22),
                      active.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(color: active.withOpacity(0.12)),
                ),
                child: Icon(icon, color: active, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.50),
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: body,
      ),
    );
  }

  Widget _metricTile({
    required IconData icon,
    required String label,
    required String value,
    required String hint,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1827),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withOpacity(0.13)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: Colors.white.withOpacity(0.46), fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.36), fontSize: 8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniInfoTile({required IconData icon, required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white54, size: 17),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 1),
          Text(title, style: const TextStyle(color: Colors.white38, fontSize: 8)),
        ],
      ),
    );
  }

  Widget _smallStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 8)),
      ],
    );
  }

  Widget _dividerVertical() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white.withOpacity(0.06),
    );
  }

  String _pressureTrendText() {
    final values = _meteo?.hourlyPressure;
    final data = _meteo;
    if (values == null || values.isEmpty || data == null) return 'Klikni pre vývoj';
    final now = data.currentHourlyIndex;
    final next = math.min(now + 3, values.length - 1);
    if (now >= values.length || next <= now) return 'Klikni pre vývoj';
    final diff = values[next] - values[now];
    if (diff <= -2) return 'Výraznejšie klesá';
    if (diff <= -0.6) return 'Klesá';
    if (diff >= 2) return 'Výraznejšie rastie';
    if (diff >= 0.6) return 'Rastie';
    return 'Takmer stabilný';
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 11))),
        ],
      ),
    );
  }

  void _showCurrentWeatherDetail() {
    _showSheet(
      title: 'Aktuálne počasie',
      icon: _weatherIcon(_weatherCode),
      accent: _accent,
      child: Column(
        children: [
          _detailRow('Stav', _weatherTitle),
          _detailRow('Teplota', '${_temperature.toStringAsFixed(1)} °C'),
          _detailRow('Pocitovo', '${_apparentTemperature.toStringAsFixed(1)} °C'),
          _detailRow('Vlhkosť', '${_humidity.toStringAsFixed(0)} %'),
          _detailRow('Vietor', '${_windSpeed.toStringAsFixed(1)} km/h z ${SkyContextService.directionName(_windDirection)}'),
          _detailRow('Tlak', _pressure > 0 ? '${_pressure.toStringAsFixed(1)} hPa' : '—'),
          _detailRow('Výška', _altitude == null ? '—' : '${_altitude!.toStringAsFixed(0)} m n. m.'),
          _detailRow('Aktuálne zrážky', _ctx == null ? '—' : '${_ctx!.currentPrecipitation.toStringAsFixed(1)} mm'),
          const SizedBox(height: 14),
          _sheetButton('Zobraziť radar', Icons.radar_rounded, widget.onOpenMap),
        ],
      ),
    );
  }

  void _showAltitudeInfo() {
    _showSheet(
      title: 'Výškomer',
      icon: Icons.terrain_rounded,
      accent: const Color(0xFF75E6C1),
      child: Column(
        children: [
          _detailRow('Odhadovaná výška', _altitude == null ? '—' : '${_altitude!.toStringAsFixed(0)} m n. m.'),
          _detailRow('Tlak v telefóne', _devicePressure == null ? 'nedostupný' : '${_devicePressure!.toStringAsFixed(1)} hPa'),
          _detailRow('Modelový tlak pri mori', _ctx == null ? '—' : '${_ctx!.seaLevelPressure.toStringAsFixed(1)} hPa'),
          const SizedBox(height: 12),
          Text(
            _devicePressure == null
                ? 'Barometer nebol dostupný, preto používam GPS výšku.'
                : 'Výška sa odhaduje kombináciou barometra a modelového tlaku pri hladine mora. Pri rýchlych zmenách počasia môže byť odhad o niekoľko metrov mimo.',
            style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.45),
          ),
        ],
      ),
    );
  }

  void _showParameterSheet(_MetricType type) {
    final series = _seriesFor(type);
    final accent = _metricAccent(type);
    final title = _metricTitle(type);
    final icon = _metricIcon(type);

    _showSheet(
      title: title,
      icon: icon,
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _currentMetricSummary(type),
          const SizedBox(height: 18),
          if (series.points.isNotEmpty) ...[
            Text(
              'Vývoj najbližších hodín',
              style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 12, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 190,
              child: CustomPaint(
                painter: _ForecastChartPainter(
                  values: series.points.map((e) => e.value).toList(),
                  accent: accent,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 68,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: series.points.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (_, i) {
                  final p = series.points[i];
                  return Container(
                    width: 67,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.035),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Column(
                      children: [
                        Text(p.time, style: const TextStyle(color: Colors.white38, fontSize: 8)),
                        const Spacer(),
                        Text(
                          '${p.value.toStringAsFixed(series.decimals)}${series.unit}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ] else
            const Text(
              'Pre tento údaj momentálne nemám hodinový rad.',
              style: TextStyle(color: Colors.white54),
            ),
          if (type == _MetricType.rain) ...[
            const SizedBox(height: 14),
            _sheetButton('Otvoriť radar / mapu', Icons.radar_rounded, widget.onOpenMap),
          ],
        ],
      ),
    );
  }

  _ForecastSeries _seriesFor(_MetricType type) {
    final data = _meteo;
    if (data == null || data.hourlyTimes == null) return _ForecastSeries.empty();
    final start = data.currentHourlyIndex;
    final total = data.hourlyTimes!.length;
    final end = math.min(start + 12, total);
    final points = <_ForecastPoint>[];
    String unit = '';
    int decimals = 0;

    for (int i = start; i < end; i++) {
      double? value;
      switch (type) {
        case _MetricType.temperature:
          value = data.temperatureAt(i);
          unit = '°';
          decimals = 0;
          break;
        case _MetricType.humidity:
          value = data.humidityAt(i);
          unit = '%';
          decimals = 0;
          break;
        case _MetricType.wind:
          value = data.windSpeedAt(i);
          unit = '';
          decimals = 0;
          break;
        case _MetricType.pressure:
          value = data.pressureAt(i);
          unit = '';
          decimals = 0;
          break;
        case _MetricType.rain:
          value = data.precipitationProbabilityAt(i)?.toDouble();
          unit = '%';
          decimals = 0;
          break;
      }
      if (value != null) {
        points.add(_ForecastPoint(time: data.formattedHourlyTime(i), value: value));
      }
    }
    return _ForecastSeries(points: points, unit: unit, decimals: decimals);
  }

  Widget _currentMetricSummary(_MetricType type) {
    String value;
    String hint;
    switch (type) {
      case _MetricType.temperature:
        value = '${_temperature.toStringAsFixed(1)} °C';
        hint = 'Pocitová teplota ${_apparentTemperature.toStringAsFixed(1)} °C';
        break;
      case _MetricType.humidity:
        value = '${_humidity.toStringAsFixed(0)} %';
        hint = _humidity >= 80 ? 'Vzduch je už poriadne vlhký.' : 'Relatívna vlhkosť vzduchu';
        break;
      case _MetricType.wind:
        value = '${_windSpeed.toStringAsFixed(1)} km/h';
        hint = 'Z ${SkyContextService.longDirectionName(_windDirection)} (${_windDirection.toStringAsFixed(0)}°)';
        break;
      case _MetricType.pressure:
        value = _pressure > 0 ? '${_pressure.toStringAsFixed(1)} hPa' : '—';
        hint = _pressureTrendText();
        break;
      case _MetricType.rain:
        final p = _ctx?.nextRainProbability ?? _currentHourlyValue(_meteo?.hourlyPrecipitationProbability);
        value = p == null ? '—' : '$p %';
        hint = _ctx?.nextRainMinutes == null
            ? 'Bez jasného blízkeho nástupu'
            : 'Najbližší signál ${SkyContextService.formatMinutes(_ctx!.nextRainMinutes!)}';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _metricAccent(type).withOpacity(0.08),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _metricAccent(type).withOpacity(0.13)),
      ),
      child: Row(
        children: [
          Icon(_metricIcon(type), color: _metricAccent(type), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(hint, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _metricTitle(_MetricType type) {
    switch (type) {
      case _MetricType.temperature:
        return 'Teplota';
      case _MetricType.humidity:
        return 'Vlhkosť';
      case _MetricType.wind:
        return 'Vietor';
      case _MetricType.pressure:
        return 'Tlak';
      case _MetricType.rain:
        return 'Zrážky';
    }
  }

  IconData _metricIcon(_MetricType type) {
    switch (type) {
      case _MetricType.temperature:
        return Icons.thermostat_rounded;
      case _MetricType.humidity:
        return Icons.water_drop_rounded;
      case _MetricType.wind:
        return Icons.air_rounded;
      case _MetricType.pressure:
        return Icons.speed_rounded;
      case _MetricType.rain:
        return Icons.umbrella_rounded;
    }
  }

  Color _metricAccent(_MetricType type) {
    switch (type) {
      case _MetricType.temperature:
        return const Color(0xFFFFB86C);
      case _MetricType.humidity:
        return const Color(0xFF63D7FF);
      case _MetricType.wind:
        return const Color(0xFF75E6C1);
      case _MetricType.pressure:
        return const Color(0xFFB49BFF);
      case _MetricType.rain:
        return const Color(0xFF62D2FF);
    }
  }

  void _showHourDetail(int index) {
    final data = _meteo;
    if (data == null) return;
    final temp = data.temperatureAt(index);
    final rainP = data.precipitationProbabilityAt(index);
    final rain = data.precipitationAt(index);
    final wind = data.windSpeedAt(index);
    final windDir = data.windDirectionAt(index);
    final humidity = data.humidityAt(index);
    final pressure = data.pressureAt(index);
    final code = data.weatherCodeAt(index) ?? 0;

    _showSheet(
      title: data.formattedHourlyTime(index),
      icon: _weatherIcon(code),
      accent: _accent,
      child: Column(
        children: [
          _detailRow('Stav', _weatherTitleForCode(code)),
          _detailRow('Teplota', temp == null ? '—' : '${temp.toStringAsFixed(1)} °C'),
          _detailRow('Pravdepodobnosť zrážok', rainP == null ? '—' : '$rainP %'),
          _detailRow('Zrážky', rain == null ? '—' : '${rain.toStringAsFixed(1)} mm'),
          _detailRow('Vlhkosť', humidity == null ? '—' : '${humidity.toStringAsFixed(0)} %'),
          _detailRow('Vietor', wind == null ? '—' : '${wind.toStringAsFixed(1)} km/h'),
          _detailRow('Smer vetra', windDir == null ? '—' : '${SkyContextService.directionName(windDir)} • ${windDir.toStringAsFixed(0)}°'),
          _detailRow('Tlak', pressure == null ? '—' : '${pressure.toStringAsFixed(1)} hPa'),
        ],
      ),
    );
  }

  void _showDayDetail(int index) {
    final data = _meteo;
    if (data == null || data.dailyTimes == null || index >= data.dailyTimes!.length) return;
    final date = DateTime.tryParse(data.dailyTimes![index]);
    final maxT = _listValue(data.dailyTemperatureMax, index);
    final minT = _listValue(data.dailyTemperatureMin, index);
    final code = _listValue(data.dailyWeatherCode, index) ?? 0;
    final sunrise = _listValue(data.dailySunrise, index);
    final sunset = _listValue(data.dailySunset, index);

    _showSheet(
      title: index == 0 ? 'Dnes' : _weekdayName(date?.weekday),
      icon: _weatherIcon(code),
      accent: _accent,
      child: Column(
        children: [
          _detailRow('Stav', _weatherTitleForCode(code)),
          _detailRow('Maximum', maxT == null ? '—' : '${maxT.toStringAsFixed(1)} °C'),
          _detailRow('Minimum', minT == null ? '—' : '${minT.toStringAsFixed(1)} °C'),
          _detailRow('Východ slnka', sunrise == null ? '—' : _clockFromString(sunrise)),
          _detailRow('Západ slnka', sunset == null ? '—' : _clockFromString(sunset)),
        ],
      ),
    );
  }

  String _clockFromString(String value) {
    final date = DateTime.tryParse(value);
    return date == null ? '—' : SkyContextService.formatClock(date);
  }

  void _showAiDetail() {
    final ctx = _ctx;
    final cloud = _cloudName == null
        ? 'Zatiaľ neodfotené'
        : '$_cloudName (${_cloudCode ?? '?'}) • ${((_cloudConfidence ?? 0) * 100).toStringAsFixed(0)} %';

    String relation = 'Najprv odfoť oblohu.';
    if (_cloudName != null && ctx != null) {
      if (_rainCloud && ctx.modelsAgreeOnRain && _arrivalDirectionDifference <= 50) {
        relation = 'Kamera aj modely dávajú zrážkový signál a pozeráš sa približne do sektora, odkiaľ prichádza počasie.';
      } else if (ctx.nextRainMinutes != null && _arrivalDirectionDifference >= 130) {
        relation = 'To, čo vidíš pred sebou, nemusí byť hlavný problém. Modelový smer príchodu je skôr za tebou.';
      } else if (_rainCloud && !ctx.rainExpectedNext6Hours && !ctx.ecmwfRainExpected) {
        relation = 'Oblak vyzerá zrážkovo, ale oba modely zatiaľ nepotvrdzujú zásah tvojej polohy.';
      } else if (ctx.modelsDisagree) {
        relation = 'Modely sa rozchádzajú. Kamera a lokálne senzory sú v tejto situácii užitočný ďalší hlas.';
      } else {
        relation = 'Kamera, smer pohľadu a modely boli porovnané. Zatiaľ bez jednoznačného blízkeho rizika.';
      }
    }

    _showSheet(
      title: 'AI analýza oblohy',
      icon: Icons.psychology_alt_rounded,
      accent: const Color(0xFF69E2C2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _aiInsightBlock(
            title: 'Čo vidím',
            text: cloud,
            icon: Icons.visibility_rounded,
          ),
          const SizedBox(height: 9),
          _aiInsightBlock(
            title: 'Smer pohľadu',
            text: '${SkyContextService.longDirectionName(_heading)} • ${_heading.toStringAsFixed(0)}°',
            icon: Icons.explore_rounded,
          ),
          const SizedBox(height: 9),
          _aiInsightBlock(
            title: 'Čo z toho vyplýva',
            text: relation,
            icon: Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 15),
          if (ctx != null) ...[
            _detailRow('Najbližší dážď', ctx.nextRainMinutes == null ? 'bez jasného signálu' : SkyContextService.formatMinutes(ctx.nextRainMinutes!)),
            _detailRow('Open-Meteo', ctx.rainExpectedNext6Hours ? 'očakáva zrážkový signál' : 'bez výrazného signálu'),
            _detailRow('ECMWF IFS', ctx.ecmwfRainExpected ? 'očakáva zrážkový signál' : 'bez výrazného signálu'),
            _detailRow('ECMWF max. zrážky 6 h', ctx.ecmwfMaxRain6h == null ? '—' : '${ctx.ecmwfMaxRain6h!.toStringAsFixed(1)} mm'),
            _detailRow('Smer vetra', '${SkyContextService.longDirectionName(ctx.windDirection)} • ${ctx.windDirection.toStringAsFixed(0)}°'),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _sheetButton(
                  _analyzing ? 'Analyzujem…' : 'Odfotiť oblohu',
                  Icons.camera_alt_rounded,
                  () {
                    Navigator.pop(context);
                    _analyzeSky();
                  },
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _sheetButton(
                  'Radar',
                  Icons.radar_rounded,
                  () {
                    Navigator.pop(context);
                    widget.onOpenMap();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Poznámka: smer príchodu je zatiaľ modelový odhad podľa vetra. Skutočný tracking radarovej bunky doplníme ako ďalšiu vrstvu.',
            style: TextStyle(color: Colors.white.withOpacity(0.34), fontSize: 9, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _aiInsightBlock({required String title, required String text, required IconData icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF69E2C2), size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.4, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: const Color(0x75FFFFFF), fontSize: 11)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetButton(String label, IconData icon, VoidCallback onTap) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        backgroundColor: const Color(0xFF1C79AA),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showSheet({
    required String title,
    required IconData icon,
    required Color accent,
    required Widget child,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF09111D),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(icon, color: accent, size: 24),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  child,
                ],
              ),
            );
          },
        );
      },
    );
  }
}

enum _MetricType { temperature, humidity, wind, pressure, rain }

class _ForecastPoint {
  final String time;
  final double value;

  const _ForecastPoint({required this.time, required this.value});
}

class _ForecastSeries {
  final List<_ForecastPoint> points;
  final String unit;
  final int decimals;

  const _ForecastSeries({required this.points, required this.unit, required this.decimals});

  factory _ForecastSeries.empty() => const _ForecastSeries(points: [], unit: '', decimals: 0);
}

class _ForecastChartPainter extends CustomPainter {
  final List<double> values;
  final Color accent;

  const _ForecastChartPainter({required this.values, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : maxV - minV;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = values.length == 1 ? 0.0 : size.width * i / (values.length - 1);
      final normalized = (values[i] - minV) / range;
      final y = size.height - (normalized * (size.height - 24)) - 12;
      points.add(Offset(x, y));
    }

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    fillPath.lineTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final current = points[i];
      final midX = (prev.dx + current.dx) / 2;
      fillPath.cubicTo(midX, prev.dy, midX, current.dy, current.dx, current.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accent.withOpacity(0.24), accent.withOpacity(0.01)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final current = points[i];
      final midX = (prev.dx + current.dx) / 2;
      linePath.cubicTo(midX, prev.dy, midX, current.dy, current.dx, current.dy);
    }

    final linePaint = Paint()
      ..color = accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = Colors.white;
    for (final p in points) {
      canvas.drawCircle(p, 2.4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ForecastChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.accent != accent;
}

class _WeatherScenePainter extends CustomPainter {
  final double animation;
  final int weatherCode;
  final bool isNight;
  final double heading;

  const _WeatherScenePainter({
    required this.animation,
    required this.weatherCode,
    required this.isNight,
    required this.heading,
  });

  bool get _rain =>
      [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].contains(weatherCode);
  bool get _snow => [71, 73, 75, 77, 85, 86].contains(weatherCode);
  bool get _storm => [95, 96, 99].contains(weatherCode);
  bool get _fog => [45, 48].contains(weatherCode);
  bool get _cloudy => weatherCode >= 2 || _rain || _snow || _storm || _fog;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = animation * math.pi * 2;
    final parallax = math.sin(heading * math.pi / 180) * 12;

    // Slnečný/mesačný disk a mäkké atmosférické svetlo.
    final celestial = Offset(
      size.width * 0.78 + parallax,
      78 + math.sin(phase * 0.45) * 3,
    );

    if (isNight) {
      final halo = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFDDE6FF).withOpacity(0.16),
            const Color(0xFF9EB6FF).withOpacity(0.05),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: celestial, radius: 92));
      canvas.drawCircle(celestial, 92, halo);
      canvas.drawCircle(
        celestial,
        22,
        Paint()..color = const Color(0xFFE8EDFF).withOpacity(0.75),
      );

      final stars = Paint()..color = Colors.white.withOpacity(0.42);
      for (int i = 0; i < 28; i++) {
        final x = ((i * 83.0) + animation * 7) % size.width;
        final y = 30 + ((i * 47.0) % 155);
        canvas.drawCircle(Offset(x, y), i % 6 == 0 ? 1.35 : 0.65, stars);
      }
    } else {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF6CB).withOpacity(_cloudy ? 0.15 : 0.34),
            const Color(0xFFFFD67B).withOpacity(0.06),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: celestial, radius: 118));
      canvas.drawCircle(celestial, 118, glow);
      canvas.drawCircle(
        celestial,
        25,
        Paint()..color = const Color(0xFFFFE9A1).withOpacity(_cloudy ? 0.55 : 0.88),
      );
    }

    // Veľmi jemný opar na horizonte.
    final hazeRect = Rect.fromLTWH(0, size.height * 0.44, size.width, size.height * 0.32);
    final haze = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(_fog ? 0.16 : 0.035),
          Colors.transparent,
        ],
      ).createShader(hazeRect);
    canvas.drawRect(hazeRect, haze);

    // Zadná vrstva oblakov – pomalšia, vytvára hĺbku.
    if (_cloudy) {
      final farCloud = Paint()
        ..color = Colors.white.withOpacity(_rain || _storm ? 0.07 : 0.10);
      _drawCloud(
        canvas,
        Offset(size.width * 0.18 + math.sin(phase * 0.45) * 8, 118),
        0.72,
        farCloud,
      );
      _drawCloud(
        canvas,
        Offset(size.width * 0.88 + math.cos(phase * 0.38) * 7, 104),
        0.58,
        farCloud,
      );
    }

    // Predná oblačnosť.
    if (_cloudy) {
      final nearCloud = Paint()
        ..color = (_rain || _storm
                ? const Color(0xFFD7E0E6)
                : Colors.white)
            .withOpacity(_rain || _storm ? 0.12 : 0.16);
      _drawCloud(
        canvas,
        Offset(size.width * 0.63 + math.cos(phase * 0.62) * 12, 154),
        1.10,
        nearCloud,
      );
    }

    // 1. vrstva vzdialených kopcov.
    final farMountain = Paint()
      ..color = (isNight ? const Color(0xFF14213B) : const Color(0xFF335B5A))
          .withOpacity(0.46);
    final farPath = Path()
      ..moveTo(0, size.height * 0.72)
      ..lineTo(size.width * 0.13, size.height * 0.59)
      ..lineTo(size.width * 0.26, size.height * 0.69)
      ..lineTo(size.width * 0.43, size.height * 0.54)
      ..lineTo(size.width * 0.61, size.height * 0.70)
      ..lineTo(size.width * 0.81, size.height * 0.57)
      ..lineTo(size.width, size.height * 0.68)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(farPath, farMountain);

    // 2. vrstva – bližšia a tmavšia.
    final nearMountain = Paint()
      ..color = (isNight ? const Color(0xFF08111F) : const Color(0xFF183D38))
          .withOpacity(0.76);
    final nearPath = Path()
      ..moveTo(0, size.height * 0.81)
      ..quadraticBezierTo(
        size.width * 0.16,
        size.height * 0.67,
        size.width * 0.33,
        size.height * 0.79,
      )
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.64,
        size.width * 0.68,
        size.height * 0.79,
      )
      ..quadraticBezierTo(
        size.width * 0.84,
        size.height * 0.70,
        size.width,
        size.height * 0.78,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(nearPath, nearMountain);

    // Najbližší hrebeň pre výraznejší 2.5D efekt.
    final foreground = Paint()
      ..color = const Color(0xFF06100F).withOpacity(0.84);
    final foregroundPath = Path()
      ..moveTo(0, size.height * 0.88)
      ..quadraticBezierTo(
        size.width * 0.24,
        size.height * 0.79,
        size.width * 0.48,
        size.height * 0.89,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.78,
        size.width,
        size.height * 0.87,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(foregroundPath, foreground);

    if (_rain) {
      final rainPaint = Paint()
        ..color = Colors.white.withOpacity(0.16)
        ..strokeWidth = 1.1;
      for (int i = 0; i < 28; i++) {
        final x = ((i * 43.0) + animation * 150) % size.width;
        final y = 58 + ((i * 31.0 + animation * 220) % 205);
        canvas.drawLine(Offset(x, y), Offset(x - 7, y + 25), rainPaint);
      }
    }

    if (_snow) {
      final snowPaint = Paint()..color = Colors.white.withOpacity(0.72);
      for (int i = 0; i < 26; i++) {
        final x = ((i * 47.0) + animation * 48) % size.width;
        final y = 55 + ((i * 35.0 + animation * 125) % 210);
        canvas.drawCircle(Offset(x, y), i % 4 == 0 ? 2.1 : 1.4, snowPaint);
      }
    }

    if (_fog) {
      final fogPaint = Paint()
        ..color = Colors.white.withOpacity(0.07)
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 4; i++) {
        final y = size.height * 0.55 + i * 18;
        final shift = math.sin(phase * 0.35 + i) * 18;
        canvas.drawLine(
          Offset(-20 + shift, y),
          Offset(size.width + 20 + shift, y),
          fogPaint,
        );
      }
    }

    if (_storm && animation > 0.78 && animation < 0.84) {
      final lightning = Paint()
        ..color = const Color(0xFFFFF59D).withOpacity(0.95)
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke;
      final bolt = Path()
        ..moveTo(size.width * 0.75, 126)
        ..lineTo(size.width * 0.68, 175)
        ..lineTo(size.width * 0.73, 175)
        ..lineTo(size.width * 0.65, 238);
      canvas.drawPath(bolt, lightning);
    }
  }

  void _drawCloud(Canvas canvas, Offset center, double scale, Paint paint) {
    canvas.drawCircle(center, 28 * scale, paint);
    canvas.drawCircle(
      Offset(center.dx + 31 * scale, center.dy + 6 * scale),
      23 * scale,
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx - 27 * scale, center.dy + 9 * scale),
      21 * scale,
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx + 5 * scale, center.dy - 13 * scale),
      20 * scale,
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + 19 * scale),
          width: 98 * scale,
          height: 31 * scale,
        ),
        Radius.circular(21 * scale),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _WeatherScenePainter oldDelegate) => true;
}
