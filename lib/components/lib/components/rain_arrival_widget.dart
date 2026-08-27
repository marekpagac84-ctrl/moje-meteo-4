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

import 'rain_arrival_original_widget.dart' as original;

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
  State<RainArrivalWidget> createState() =>
      _RainArrivalWidgetState();
}

class _RainArrivalWidgetState
    extends State<RainArrivalWidget>
    with SingleTickerProviderStateMixin {
  final SkyContextService _weatherService =
      SkyContextService();

  final CloudClassifierService _cloudService =
      CloudClassifierService();

  final ImagePicker _picker =
      ImagePicker();

  StreamSubscription<BarometerEvent>? _barometerSubscription;
  StreamSubscription<MagnetometerEvent>?
      _magnetometerSubscription;

  late final AnimationController _animationController;

  SkyContextResult? _weather;

  Position? _position;

  double? _devicePressure;
  double? _altitude;

  double _heading = 0.0;

  bool _loading = true;
  bool _analyzing = false;

  String? _error;

  String? _cloudName;
  String? _cloudCode;

  double? _cloudConfidence;

  DateTime? _lastAnalysis;

  @override
  void initState() {
    super.initState();

    _animationController =
        AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 16,
      ),
    )..repeat();

    _startSensors();
    _loadWeather();
  }

  @override
  void dispose() {
    _animationController.dispose();

    _barometerSubscription?.cancel();
    _magnetometerSubscription?.cancel();

    _cloudService.dispose();

    super.dispose();
  }

  // ============================================================
  // SENZORY
  // ============================================================

  void _startSensors() {
    try {
      _barometerSubscription =
          barometerEventStream().listen(
        (event) {
          if (!mounted) {
            return;
          }

          setState(() {
            _devicePressure =
                event.pressure;

            _calculateAltitude();
          });
        },
        onError: (_) {},
      );
    } catch (_) {}

    try {
      _magnetometerSubscription =
          magnetometerEventStream().listen(
        (event) {
          final double radians =
              math.atan2(
            event.y,
            event.x,
          );

          double degrees =
              radians *
                  180 /
                  math.pi;

          degrees =
              (degrees + 360) %
                  360;

          if (!mounted) {
            return;
          }

          setState(() {
            _heading =
                degrees;
          });
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  // ============================================================
  // GPS
  // ============================================================

  Future<Position> _getPosition() async {
    final bool enabled =
        await Geolocator
            .isLocationServiceEnabled();

    if (!enabled) {
      throw Exception(
        'Zapni polohu / GPS.',
      );
    }

    LocationPermission permission =
        await Geolocator
            .checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
          await Geolocator
              .requestPermission();
    }

    if (permission ==
            LocationPermission.denied ||
        permission ==
            LocationPermission
                .deniedForever) {
      throw Exception(
        'Aplikácia nemá povolenie používať polohu.',
      );
    }

    return Geolocator
        .getCurrentPosition(
      desiredAccuracy:
          LocationAccuracy.high,
    );
  }

  // ============================================================
  // POČASIE
  // ============================================================

  Future<void> _loadWeather() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final Position position =
          await _getPosition();

      final SkyContextResult data =
          await _weatherService.load(
        latitude:
            position.latitude,
        longitude:
            position.longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _position =
            position;

        _weather =
            data;

        _loading =
            false;

        _calculateAltitude();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading =
            false;

        _error =
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                );
      });
    }
  }

  void _calculateAltitude() {
    final weather =
        _weather;

    if (_devicePressure != null &&
        weather != null &&
        weather.seaLevelPressure >
            0) {
      _altitude =
          SkyContextService
              .pressureAltitude(
        pressure:
            _devicePressure!,
        seaLevelPressure:
            weather
                .seaLevelPressure,
      );

      return;
    }

    if (_position != null) {
      _altitude =
          _position!.altitude;
    }
  }

  // ============================================================
  // AI FOTO
  // ============================================================

  Future<void> _analyzeSky() async {
    if (_analyzing) {
      return;
    }

    setState(() {
      _analyzing = true;
      _error = null;
    });

    try {
      /*
       * Uložíme smer PRÁVE v okamihu,
       * keď používateľ ide fotografovať.
       */
      final double photoHeading =
          _heading;

      final XFile? photo =
          await _picker.pickImage(
        source:
            ImageSource.camera,
        imageQuality:
            90,
        maxWidth:
            1920,
      );

      if (photo == null) {
        if (mounted) {
          setState(() {
            _analyzing = false;
          });
        }

        return;
      }

      final Uint8List bytes =
          await photo.readAsBytes();

      final classification =
          await _cloudService.classify(
        bytes,
      );

      /*
       * Po fotografii načítame
       * najčerstvejšie modelové dáta.
       */
      final Position position =
          await _getPosition();

      final SkyContextResult weather =
          await _weatherService.load(
        latitude:
            position.latitude,
        longitude:
            position.longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _heading =
            photoHeading;

        _position =
            position;

        _weather =
            weather;

        _cloudName =
            classification?.name;

        _cloudCode =
            classification?.code;

        _cloudConfidence =
            classification?.confidence;

        _lastAnalysis =
            DateTime.now();

        _analyzing =
            false;

        _calculateAltitude();
      });

      _showAiDetail();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _analyzing =
            false;

        _error =
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                );
      });
    }
  }

  // ============================================================
  // AI LOGIKA
  // ============================================================

  bool get _rainCloud {
    return _cloudCode == 'Cb' ||
        _cloudCode == 'Ns';
  }

  bool get _stormCloud {
    return _cloudCode == 'Cb';
  }

  double get _arrivalDirectionDifference {
    final weather =
        _weather;

    if (weather == null) {
      return 180;
    }

    return SkyContextService
        .circularDifference(
      _heading,
      weather.windDirection,
    );
  }

  String get _aiHeadline {
    final weather =
        _weather;

    if (_analyzing) {
      return 'Pozerám sa na oblohu...';
    }

    if (weather == null) {
      return 'AI analýza oblohy';
    }

    final minutes =
        weather.nextRainMinutes;

    if (weather.stormSignal &&
        minutes != null &&
        minutes <= 120) {
      return 'Búrkový signál sa približuje';
    }

    if (minutes != null &&
        minutes <= 60) {
      return 'Dážď približne '
          '${SkyContextService.formatMinutes(minutes)}';
    }

    if (_stormCloud) {
      return 'Toto už nie je oblak na okrasu';
    }

    if (_rainCloud) {
      return 'Tento oblak stojí za pozornosť';
    }

    if (_cloudName != null) {
      return 'Vidím $_cloudName';
    }

    if (weather.modelsAgreeOnDry) {
      return 'Dáždnik môže zatiaľ oddychovať';
    }

    if (weather.modelsDisagree) {
      return 'Modely sa hádajú. Pozrime sa hore.';
    }

    return 'AI analýza oblohy';
  }

  String get _aiSubtitle {
    final weather =
        _weather;

    if (weather == null) {
      return 'Kamera + ECMWF + Open-Meteo + senzory';
    }

    final minutes =
        weather.nextRainMinutes;

    if (_cloudName == null) {
      if (minutes != null) {
        return 'Najbližší dážď '
            '${SkyContextService.formatMinutes(minutes)} • '
            'odfoť oblohu a preveríme to';
      }

      return 'Jedna fotka • AI oblakov • modely • tlak • smer';
    }

    if (_rainCloud &&
        weather.modelsAgreeOnRain) {
      if (_arrivalDirectionDifference <=
          50) {
        return 'To, čo vidíš, môže súvisieť '
            's prichádzajúcim počasím';
      }

      if (_arrivalDirectionDifference >=
          130) {
        return 'Pozor — hlavné počasie môže '
            'prichádzať spoza teba';
      }

      return 'Zrážkový systém môže prichádzať '
          'skôr zboku';
    }

    if (minutes != null &&
        minutes <= 120) {
      if (_arrivalDirectionDifference >=
          130) {
        return 'To pred tebou nemusí byť problém. '
            'Niečo však môže prísť zozadu.';
      }

      return 'Modely čakajú zrážky. Kamera ich '
          'zatiaľ úplne nepotvrdzuje.';
    }

    if (weather.modelsAgreeOnDry) {
      return 'Obloha aj modely zatiaľ pôsobia pokojne';
    }

    return 'Klikni a pozri si kompletnú analýzu';
  }

  // ============================================================
  // DETAIL AI
  // ============================================================

  void _showAiDetail() {
    showModalBottomSheet(
      context:
          context,
      isScrollControlled:
          true,
      backgroundColor:
          Colors.transparent,
      builder:
          (context) {
        return DraggableScrollableSheet(
          initialChildSize:
              0.84,
          minChildSize:
              0.55,
          maxChildSize:
              0.96,
          builder:
              (
            context,
            controller,
          ) {
            return _AiDetailSheet(
              scrollController:
                  controller,
              weather:
                  _weather,
              cloudName:
                  _cloudName,
              cloudCode:
                  _cloudCode,
              cloudConfidence:
                  _cloudConfidence,
              heading:
                  _heading,
              altitude:
                  _altitude,
              devicePressure:
                  _devicePressure,
              lastAnalysis:
                  _lastAnalysis,
              onAnalyze:
                  _analyzeSky,
              onOpenMap:
                  widget.onOpenMap,
            );
          },
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      children: [
        /*
         * NOVÁ WOW HLAVIČKA.
         */
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            8,
            12,
            0,
          ),
          child:
              _buildWeatherHero(),
        ),

        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            10,
            12,
            2,
          ),
          child:
              _buildAiBanner(),
        ),

        if (_error != null)
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              12,
              6,
              12,
              0,
            ),
            child:
                _errorCard(),
          ),

        /*
         * A TU JE CELÁ TVOJA PÔVODNÁ
         * PRVÁ KARTA.
         *
         * NIČ SME Z NEJ NEVYHODILI.
         */
        Expanded(
          child:
              original.RainArrivalWidget(
            meteoData:
                widget.meteoData,
            isLoading:
                widget.isLoading,
            onRefresh:
                () {
              widget.onRefresh();
              _loadWeather();
            },
            onOpenMap:
                widget.onOpenMap,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _buildWeatherHero() {
    final weather =
        _weather;

    return AnimatedBuilder(
      animation:
          _animationController,
      builder:
          (
        context,
        child,
      ) {
        final double t =
            _animationController.value;

        return GestureDetector(
          onTap:
              _showAiDetail,
          child:
              Container(
            height:
                230,
            width:
                double.infinity,
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                30,
              ),
              gradient:
                  _heroGradient(),
              boxShadow: [
                BoxShadow(
                  color:
                      const Color(
                    0xFF2196F3,
                  ).withOpacity(
                    0.20,
                  ),
                  blurRadius:
                      30,
                  spreadRadius:
                      -4,
                  offset:
                      const Offset(
                    0,
                    16,
                  ),
                ),
                BoxShadow(
                  color:
                      Colors.black
                          .withOpacity(
                    0.30,
                  ),
                  blurRadius:
                      24,
                  offset:
                      const Offset(
                    0,
                    12,
                  ),
                ),
              ],
            ),
            child:
                ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                30,
              ),
              child:
                  Stack(
                children: [
                  Positioned.fill(
                    child:
                        CustomPaint(
                      painter:
                          _WowWeatherPainter(
                        animation:
                            t,
                        rain:
                            weather
                                    ?.rainExpectedNext6Hours ??
                                false,
                        storm:
                            weather
                                    ?.stormSignal ??
                                false,
                        heading:
                            _heading,
                      ),
                    ),
                  ),

                  Positioned(
                    top:
                        17,
                    left:
                        18,
                    right:
                        18,
                    child:
                        Row(
                      children: [
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal:
                                10,
                            vertical:
                                6,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                Colors.white
                                    .withOpacity(
                              0.12,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              30,
                            ),
                            border:
                                Border.all(
                              color:
                                  Colors.white
                                      .withOpacity(
                                0.13,
                              ),
                            ),
                          ),
                          child:
                              const Row(
                            mainAxisSize:
                                MainAxisSize.min,
                            children: [
                              Icon(
                                Icons
                                    .location_on_rounded,
                                color:
                                    Colors.white70,
                                size:
                                    13,
                              ),
                              SizedBox(
                                width:
                                    4,
                              ),
                              Text(
                                'MOJE METEO • LIVE',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.white70,
                                  fontSize:
                                      10,
                                  fontWeight:
                                      FontWeight.w800,
                                  letterSpacing:
                                      0.8,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        GestureDetector(
                          onTap:
                              () async {
                            widget.onRefresh();
                            await _loadWeather();
                          },
                          child:
                              Container(
                            width:
                                36,
                            height:
                                36,
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.white
                                      .withOpacity(
                                0.10,
                              ),
                              shape:
                                  BoxShape.circle,
                            ),
                            child:
                                const Icon(
                              Icons
                                  .refresh_rounded,
                              color:
                                  Colors.white,
                              size:
                                  19,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    left:
                        20,
                    right:
                        20,
                    top:
                        60,
                    child:
                        Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .center,
                      children: [
                        Expanded(
                          child:
                              Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              if (_loading)
                                const SizedBox(
                                  height:
                                      45,
                                  width:
                                      45,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        3,
                                    color:
                                        Colors.white,
                                  ),
                                )
                              else
                                Text(
                                  weather ==
                                          null
                                      ? '—'
                                      : '${weather.temperature.toStringAsFixed(0)}°',
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize:
                                        58,
                                    height:
                                        0.95,
                                    fontWeight:
                                        FontWeight.w300,
                                    letterSpacing:
                                        -3,
                                  ),
                                ),

                              const SizedBox(
                                height:
                                    7,
                              ),

                              Text(
                                _weatherDescription(),
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white,
                                  fontSize:
                                      17,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),

                              const SizedBox(
                                height:
                                    4,
                              ),

                              Text(
                                weather ==
                                        null
                                    ? 'Načítavam atmosféru...'
                                    : 'Pocitovo '
                                        '${weather.apparentTemperature.toStringAsFixed(0)}° • '
                                        '${weather.humidity.toStringAsFixed(0)} % vlhkosť',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.white
                                          .withOpacity(
                                    0.72,
                                  ),
                                  fontSize:
                                      12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          width:
                              10,
                        ),

                        Transform.translate(
                          offset:
                              Offset(
                            math.sin(
                                  t *
                                      math.pi *
                                      2,
                                ) *
                                4,
                            math.cos(
                                  t *
                                      math.pi *
                                      2,
                                ) *
                                2,
                          ),
                          child:
                              _bigWeatherIcon(),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    bottom:
                        15,
                    left:
                        16,
                    right:
                        16,
                    child:
                        Row(
                      children: [
                        Expanded(
                          child:
                              _heroMetric(
                            Icons
                                .water_drop_outlined,
                            weather ==
                                    null
                                ? '—'
                                : '${weather.humidity.toStringAsFixed(0)}%',
                            'Vlhkosť',
                            () {
                              _showAiDetail();
                            },
                          ),
                        ),

                        const SizedBox(
                          width:
                              6,
                        ),

                        Expanded(
                          child:
                              _heroMetric(
                            Icons
                                .air_rounded,
                            weather ==
                                    null
                                ? '—'
                                : '${weather.windSpeed.toStringAsFixed(0)} km/h',
                            'Vietor',
                            _showAiDetail,
                          ),
                        ),

                        const SizedBox(
                          width:
                              6,
                        ),

                        Expanded(
                          child:
                              _heroMetric(
                            Icons
                                .speed_rounded,
                            _devicePressure !=
                                    null
                                ? '${_devicePressure!.toStringAsFixed(0)}'
                                : weather ==
                                        null
                                    ? '—'
                                    : '${weather.surfacePressure.toStringAsFixed(0)}',
                            'hPa',
                            _showAiDetail,
                          ),
                        ),

                        const SizedBox(
                          width:
                              6,
                        ),

                        Expanded(
                          child:
                              _heroMetric(
                            Icons
                                .terrain_rounded,
                            _altitude ==
                                    null
                                ? '—'
                                : '${_altitude!.toStringAsFixed(0)} m',
                            'Výška',
                            _showAiDetail,
                          ),
                        ),
                      ],
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
    final weather =
        _weather;

    if (weather?.stormSignal ==
        true) {
      return const LinearGradient(
        begin:
            Alignment.topLeft,
        end:
            Alignment.bottomRight,
        colors: [
          Color(
            0xFF080B18,
          ),
          Color(
            0xFF24274B,
          ),
          Color(
            0xFF4A345D,
          ),
        ],
      );
    }

    if (weather?.rainExpectedNext6Hours ==
        true) {
      return const LinearGradient(
        begin:
            Alignment.topLeft,
        end:
            Alignment.bottomRight,
        colors: [
          Color(
            0xFF07182E,
          ),
          Color(
            0xFF184B70,
          ),
          Color(
            0xFF386783,
          ),
        ],
      );
    }

    return const LinearGradient(
      begin:
          Alignment.topLeft,
      end:
          Alignment.bottomRight,
      colors: [
        Color(
          0xFF031B37,
        ),
        Color(
          0xFF075C9D,
        ),
        Color(
          0xFF16A4D8,
        ),
      ],
    );
  }

  Widget _bigWeatherIcon() {
    final weather =
        _weather;

    IconData icon;
    List<Color> colors;

    if (weather?.stormSignal ==
        true) {
      icon =
          Icons.thunderstorm_rounded;

      colors = const [
        Color(
          0xFFFFF176,
        ),
        Color(
          0xFFB39DDB,
        ),
      ];
    } else if (weather?.rainExpectedNext6Hours ==
        true) {
      icon =
          Icons.water_drop_rounded;

      colors = const [
        Color(
          0xFFB3E5FC,
        ),
        Color(
          0xFF29B6F6,
        ),
      ];
    } else {
      icon =
          Icons.wb_sunny_rounded;

      colors = const [
        Color(
          0xFFFFF59D,
        ),
        Color(
          0xFFFFB74D,
        ),
      ];
    }

    return Container(
      width:
          84,
      height:
          84,
      decoration:
          BoxDecoration(
        shape:
            BoxShape.circle,
        gradient:
            RadialGradient(
          colors: [
            colors.first
                .withOpacity(
              0.22,
            ),
            Colors.transparent,
          ],
        ),
      ),
      child:
          ShaderMask(
        shaderCallback:
            (bounds) {
          return LinearGradient(
            colors:
                colors,
          ).createShader(
            bounds,
          );
        },
        child:
            Icon(
          icon,
          size:
              64,
          color:
              Colors.white,
        ),
      ),
    );
  }

  String _weatherDescription() {
    final weather =
        _weather;

    if (weather == null) {
      return 'Aktuálne počasie';
    }

    if (weather.stormSignal) {
      return 'Búrková atmosféra';
    }

    if (weather.currentPrecipitation >=
        3) {
      return 'Silnejší dážď';
    }

    if (weather.currentPrecipitation >
        0) {
      return 'Prší';
    }

    if (weather.rainExpectedNext6Hours) {
      return 'Počasie sa môže zmeniť';
    }

    return 'Pokojná atmosféra';
  }

  Widget _heroMetric(
    IconData icon,
    String value,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius:
          BorderRadius.circular(
        15,
      ),
      onTap:
          onTap,
      child:
          Container(
        padding:
            const EdgeInsets.symmetric(
          vertical:
              9,
          horizontal:
              5,
        ),
        decoration:
            BoxDecoration(
          color:
              Colors.white
                  .withOpacity(
            0.09,
          ),
          borderRadius:
              BorderRadius.circular(
            15,
          ),
          border:
              Border.all(
            color:
                Colors.white
                    .withOpacity(
              0.08,
            ),
          ),
        ),
        child:
            Column(
          children: [
            Icon(
              icon,
              color:
                  Colors.white70,
              size:
                  15,
            ),

            const SizedBox(
              height:
                  4,
            ),

            Text(
              value,
              maxLines:
                  1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontWeight:
                    FontWeight.w800,
                fontSize:
                    11,
              ),
            ),

            Text(
              label,
              style:
                  TextStyle(
                color:
                    Colors.white
                        .withOpacity(
                  0.46,
                ),
                fontSize:
                    8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // AI BANNER
  // ============================================================

  Widget _buildAiBanner() {
    final weather =
        _weather;

    Color accent;

    if (weather?.stormSignal ==
        true) {
      accent =
          const Color(
        0xFFBA68C8,
      );
    } else if (weather?.rainExpectedNext6Hours ==
        true) {
      accent =
          const Color(
        0xFFFFB74D,
      );
    } else {
      accent =
          const Color(
        0xFF66E2BE,
      );
    }

    return Material(
      color:
          Colors.transparent,
      child:
          InkWell(
        borderRadius:
            BorderRadius.circular(
          19,
        ),
        onTap:
            _showAiDetail,
        child:
            Ink(
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              19,
            ),
            gradient:
                const LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors: [
                Color(
                  0xFF101927,
                ),
                Color(
                  0xFF111E30,
                ),
              ],
            ),
            border:
                Border.all(
              color:
                  accent.withOpacity(
                0.28,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color:
                    accent.withOpacity(
                  0.08,
                ),
                blurRadius:
                    16,
                offset:
                    const Offset(
                  0,
                  7,
                ),
              ),
            ],
          ),
          child:
              Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal:
                  13,
              vertical:
                  10,
            ),
            child:
                Row(
              children: [
                Container(
                  width:
                      42,
                  height:
                      42,
                  decoration:
                      BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    gradient:
                        LinearGradient(
                      begin:
                          Alignment.topLeft,
                      end:
                          Alignment.bottomRight,
                      colors: [
                        accent
                            .withOpacity(
                          0.28,
                        ),
                        accent
                            .withOpacity(
                          0.08,
                        ),
                      ],
                    ),
                  ),
                  child:
                      Icon(
                    Icons
                        .psychology_alt_rounded,
                    color:
                        accent,
                    size:
                        24,
                  ),
                ),

                const SizedBox(
                  width:
                      11,
                ),

                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'MOJE METEO AI',
                            style:
                                TextStyle(
                              color:
                                  accent,
                              fontSize:
                                  10,
                              fontWeight:
                                  FontWeight.w900,
                              letterSpacing:
                                  0.8,
                            ),
                          ),

                          if (_lastAnalysis !=
                              null) ...[
                            const SizedBox(
                              width:
                                  5,
                            ),
                            Icon(
                              Icons
                                  .check_circle_rounded,
                              size:
                                  12,
                              color:
                                  accent,
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(
                        height:
                            2,
                      ),

                      Text(
                        _aiHeadline,
                        maxLines:
                            1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontWeight:
                              FontWeight.w800,
                          fontSize:
                              13,
                        ),
                      ),

                      const SizedBox(
                        height:
                            2,
                      ),

                      Text(
                        _aiSubtitle,
                        maxLines:
                            1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            TextStyle(
                          color:
                              Colors.white
                                  .withOpacity(
                            0.54,
                          ),
                          fontSize:
                              10,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  width:
                      7,
                ),

                if (_analyzing)
                  const SizedBox(
                    width:
                        22,
                    height:
                        22,
                    child:
                        CircularProgressIndicator(
                      strokeWidth:
                          2,
                    ),
                  )
                else
                  IconButton(
                    tooltip:
                        'Analyzovať oblohu',
                    onPressed:
                        _analyzeSky,
                    icon:
                        const Icon(
                      Icons
                          .camera_alt_rounded,
                    ),
                    color:
                        accent,
                  ),

                const Icon(
                  Icons
                      .chevron_right_rounded,
                  color:
                      Colors.white38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        10,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.redAccent
                .withOpacity(
          0.08,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
      child:
          Text(
        _error!,
        style:
            const TextStyle(
          color:
              Colors.redAccent,
          fontSize:
              11,
        ),
      ),
    );
  }
}

// ============================================================
// WOW WEATHER PAINTER
// ============================================================

class _WowWeatherPainter
    extends CustomPainter {
  final double animation;
  final bool rain;
  final bool storm;
  final double heading;

  const _WowWeatherPainter({
    required this.animation,
    required this.rain,
    required this.storm,
    required this.heading,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final double phase =
        animation *
            math.pi *
            2;

    final double parallax =
        math.sin(
              heading *
                  math.pi /
                  180,
            ) *
            14;

    // ----------------------------------------------------------
    // SVETLO / SLNKO
    // ----------------------------------------------------------

    final Offset sunCenter =
        Offset(
      size.width *
              0.82 +
          parallax,
      58 +
          math.sin(
                phase,
              ) *
              2,
    );

    final Paint sunGlow =
        Paint()
          ..shader =
              RadialGradient(
            colors: [
              Colors.white.withOpacity(
                rain
                    ? 0.04
                    : 0.22,
              ),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center:
                  sunCenter,
              radius:
                  90,
            ),
          );

    canvas.drawCircle(
      sunCenter,
      90,
      sunGlow,
    );

    // ----------------------------------------------------------
    // HVIEZDIČKY / ATMOSFÉRICKÉ ČASTICE
    // ----------------------------------------------------------

    final Paint particle =
        Paint()
          ..color =
              Colors.white.withOpacity(
            0.10,
          );

    for (int i = 0;
        i < 16;
        i++) {
      final double x =
          ((i * 73.0) +
                  animation *
                      18) %
              size.width;

      final double y =
          30 +
              ((i * 39.0) %
                  130);

      canvas.drawCircle(
        Offset(
          x,
          y,
        ),
        i % 3 == 0
            ? 1.3
            : 0.7,
        particle,
      );
    }

    // ----------------------------------------------------------
    // OBLaky
    // ----------------------------------------------------------

    final Paint backCloud =
        Paint()
          ..color =
              Colors.white.withOpacity(
            rain
                ? 0.055
                : 0.075,
          );

    final Paint frontCloud =
        Paint()
          ..color =
              Colors.white.withOpacity(
            rain
                ? 0.085
                : 0.11,
          );

    _cloud(
      canvas,
      Offset(
        size.width *
                0.18 +
            math.sin(
                  phase,
                ) *
                9,
        76,
      ),
      0.72,
      backCloud,
    );

    _cloud(
      canvas,
      Offset(
        size.width *
                0.70 +
            math.cos(
                  phase *
                      0.7,
                ) *
                11,
        115,
      ),
      1.0,
      frontCloud,
    );

    // ----------------------------------------------------------
    // HORIZONT / 3D TERÉN
    // ----------------------------------------------------------

    final Paint mountain1 =
        Paint()
          ..color =
              const Color(
                0xFF071522,
              ).withOpacity(
                0.24,
              );

    final Path horizon1 =
        Path()
          ..moveTo(
            0,
            size.height *
                0.77,
          )
          ..lineTo(
            size.width *
                0.18,
            size.height *
                0.60,
          )
          ..lineTo(
            size.width *
                0.34,
            size.height *
                0.72,
          )
          ..lineTo(
            size.width *
                0.52,
            size.height *
                0.56,
          )
          ..lineTo(
            size.width *
                0.73,
            size.height *
                0.73,
          )
          ..lineTo(
            size.width,
            size.height *
                0.62,
          )
          ..lineTo(
            size.width,
            size.height,
          )
          ..lineTo(
            0,
            size.height,
          )
          ..close();

    canvas.drawPath(
      horizon1,
      mountain1,
    );

    // ----------------------------------------------------------
    // DÁŽĎ
    // ----------------------------------------------------------

    if (rain) {
      final Paint rainPaint =
          Paint()
            ..color =
                Colors.white.withOpacity(
              0.11,
            )
            ..strokeWidth =
                1;

      for (int i = 0;
          i < 20;
          i++) {
        final double x =
            ((i * 41.0) +
                    animation *
                        120) %
                size.width;

        final double y =
            45 +
                ((i * 29.0 +
                        animation *
                            160) %
                    120);

        canvas.drawLine(
          Offset(
            x,
            y,
          ),
          Offset(
            x - 6,
            y + 20,
          ),
          rainPaint,
        );
      }
    }

    // ----------------------------------------------------------
    // BLESK
    // ----------------------------------------------------------

    if (storm &&
        animation >
            0.79 &&
        animation <
            0.84) {
      final Paint lightning =
          Paint()
            ..color =
                const Color(
                  0xFFFFF59D,
                ).withOpacity(
              0.85,
            )
            ..strokeWidth =
                2.5
            ..style =
                PaintingStyle.stroke;

      final Path bolt =
          Path()
            ..moveTo(
              size.width *
                  0.78,
              85,
            )
            ..lineTo(
              size.width *
                  0.72,
              122,
            )
            ..lineTo(
              size.width *
                  0.77,
              122,
            )
            ..lineTo(
              size.width *
                  0.70,
              173,
            );

      canvas.drawPath(
        bolt,
        lightning,
      );
    }
  }

  void _cloud(
    Canvas canvas,
    Offset center,
    double scale,
    Paint paint,
  ) {
    canvas.drawCircle(
      center,
      26 * scale,
      paint,
    );

    canvas.drawCircle(
      Offset(
        center.dx +
            28 * scale,
        center.dy +
            5 * scale,
      ),
      21 * scale,
      paint,
    );

    canvas.drawCircle(
      Offset(
        center.dx -
            25 * scale,
        center.dy +
            8 * scale,
      ),
      19 * scale,
      paint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center:
              Offset(
            center.dx,
            center.dy +
                18 * scale,
          ),
          width:
              90 * scale,
          height:
              28 * scale,
        ),
        Radius.circular(
          20 * scale,
        ),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _WowWeatherPainter
        oldDelegate,
  ) {
    return true;
  }
}

// ============================================================
// AI DETAIL SHEET
// ============================================================

class _AiDetailSheet
    extends StatelessWidget {
  final ScrollController scrollController;

  final SkyContextResult? weather;

  final String? cloudName;
  final String? cloudCode;

  final double? cloudConfidence;

  final double heading;
  final double? altitude;
  final double? devicePressure;

  final DateTime? lastAnalysis;

  final VoidCallback onAnalyze;
  final VoidCallback onOpenMap;

  const _AiDetailSheet({
    required this.scrollController,
    required this.weather,
    required this.cloudName,
    required this.cloudCode,
    required this.cloudConfidence,
    required this.heading,
    required this.altitude,
    required this.devicePressure,
    required this.lastAnalysis,
    required this.onAnalyze,
    required this.onOpenMap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      decoration:
          const BoxDecoration(
        color:
            Color(
          0xFF09111D,
        ),
        borderRadius:
            BorderRadius.vertical(
          top:
              Radius.circular(
            30,
          ),
        ),
      ),
      child:
          ListView(
        controller:
            scrollController,
        padding:
            const EdgeInsets.fromLTRB(
          18,
          10,
          18,
          36,
        ),
        children: [
          Center(
            child:
                Container(
              width:
                  42,
              height:
                  4,
              margin:
                  const EdgeInsets.only(
                bottom:
                    18,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.white24,
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
            ),
          ),

          const Row(
            children: [
              Icon(
                Icons
                    .psychology_alt_rounded,
                color:
                    Color(
                  0xFF77E6D1,
                ),
                size:
                    29,
              ),
              SizedBox(
                width:
                    10,
              ),
              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI ANALÝZA OBLOHY',
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize:
                            20,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Kamera + modely + senzory',
                      style:
                          TextStyle(
                        color:
                            Colors.white54,
                        fontSize:
                            12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                20,
          ),

          _section(
            '👁️ ČO VIDÍM',
            [
              _line(
                'AI oblak',
                cloudName ==
                        null
                    ? 'Zatiaľ neanalyzované'
                    : '$cloudName (${cloudCode ?? '?'})',
              ),

              _line(
                'Istota AI',
                cloudConfidence ==
                        null
                    ? '—'
                    : '${(cloudConfidence! * 100).toStringAsFixed(0)} %',
              ),

              _line(
                'Pozeráš',
                '${SkyContextService.longDirectionName(heading)} '
                    '(${heading.toStringAsFixed(0)}°)',
              ),
            ],
          ),

          _section(
            '🌧️ ČO SA OČAKÁVA',
            [
              _line(
                'Najbližší dážď',
                weather
                            ?.nextRainMinutes ==
                        null
                    ? 'Bez jasného signálu'
                    : SkyContextService
                        .formatMinutes(
                        weather!
                            .nextRainMinutes!,
                      ),
              ),

              _line(
                'Čas',
                weather
                            ?.nextRainTime ==
                        null
                    ? '—'
                    : SkyContextService
                        .formatClock(
                        weather!
                            .nextRainTime!,
                      ),
              ),

              _line(
                'Pravdepodobnosť',
                weather
                            ?.nextRainProbability ==
                        null
                    ? '—'
                    : '${weather!.nextRainProbability} %',
              ),

              _line(
                'Intenzita',
                weather ==
                        null
                    ? '—'
                    : weather!
                        .precipitationDescription,
              ),
            ],
          ),

          _section(
            '🧠 MODELY',
            [
              _line(
                'Open-Meteo',
                weather ==
                        null
                    ? '—'
                    : weather!
                            .rainExpectedNext6Hours
                        ? 'Očakáva zrážky'
                        : 'Bez výrazného zrážkového signálu',
              ),

              _line(
                'ECMWF IFS',
                weather ==
                        null
                    ? '—'
                    : weather!
                            .ecmwfRainExpected
                        ? 'Očakáva zrážky'
                        : 'Bez výrazného zrážkového signálu',
              ),

              _line(
                'Zhoda',
                weather ==
                        null
                    ? '—'
                    : weather!
                            .modelsAgreeOnRain
                        ? 'Veľmi dobrá – oba čakajú zrážky'
                        : weather!
                                .modelsAgreeOnDry
                            ? 'Oba podporujú suchší scenár'
                            : 'Modely sa rozchádzajú',
              ),
            ],
          ),

          _section(
            '🌍 OKOLO TEBA',
            [
              _line(
                'Teplota',
                weather ==
                        null
                    ? '—'
                    : '${weather!.temperature.toStringAsFixed(1)} °C',
              ),

              _line(
                'Pocitovo',
                weather ==
                        null
                    ? '—'
                    : '${weather!.apparentTemperature.toStringAsFixed(1)} °C',
              ),

              _line(
                'Vlhkosť',
                weather ==
                        null
                    ? '—'
                    : '${weather!.humidity.toStringAsFixed(0)} %',
              ),

              _line(
                'Tlak',
                devicePressure !=
                        null
                    ? '${devicePressure!.toStringAsFixed(1)} hPa'
                    : weather ==
                            null
                        ? '—'
                        : '${weather!.surfacePressure.toStringAsFixed(1)} hPa',
              ),

              _line(
                'Výška',
                altitude ==
                        null
                    ? '—'
                    : '${altitude!.toStringAsFixed(0)} m',
              ),

              _line(
                'Vietor',
                weather ==
                        null
                    ? '—'
                    : '${weather!.windSpeed.toStringAsFixed(1)} km/h '
                        'z ${SkyContextService.directionName(weather!.windDirection)}',
              ),
            ],
          ),

          const SizedBox(
            height:
                6,
          ),

          Row(
            children: [
              Expanded(
                child:
                    ElevatedButton.icon(
                  onPressed:
                      () {
                    Navigator.of(
                      context,
                    ).pop();

                    onAnalyze();
                  },
                  icon:
                      const Icon(
                    Icons
                        .camera_alt_rounded,
                  ),
                  label:
                      const Text(
                    'ANALYZOVAŤ',
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    minimumSize:
                        const Size(
                      0,
                      50,
                    ),
                    backgroundColor:
                        const Color(
                      0xFF77E6D1,
                    ),
                    foregroundColor:
                        const Color(
                      0xFF06121B,
                    ),
                    textStyle:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w900,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                width:
                    10,
              ),

              Expanded(
                child:
                    OutlinedButton.icon(
                  onPressed:
                      () {
                    Navigator.of(
                      context,
                    ).pop();

                    onOpenMap();
                  },
                  icon:
                      const Icon(
                    Icons
                        .radar_rounded,
                  ),
                  label:
                      const Text(
                    'RADAR',
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    minimumSize:
                        const Size(
                      0,
                      50,
                    ),
                    foregroundColor:
                        Colors.white,
                    side:
                        const BorderSide(
                      color:
                          Colors.white24,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _section(
    String title,
    List<Widget> children,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom:
            12,
      ),
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFF111C2B,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color:
              Colors.white
                  .withOpacity(
            0.06,
          ),
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Text(
            title,
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontWeight:
                  FontWeight.w900,
              fontSize:
                  13,
            ),
          ),

          const SizedBox(
            height:
                9,
          ),

          ...children,
        ],
      ),
    );
  }

  static Widget _line(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical:
            5,
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child:
                Text(
              label,
              style:
                  const TextStyle(
                color:
                    Colors.white54,
                fontSize:
                    12,
              ),
            ),
          ),

          const SizedBox(
            width:
                10,
          ),

          Flexible(
            child:
                Text(
              value,
              textAlign:
                  TextAlign.right,
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize:
                    12,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
