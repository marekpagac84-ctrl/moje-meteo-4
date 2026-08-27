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

class RainArrivalWidget
    extends StatefulWidget {
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
  State<RainArrivalWidget>
      createState() =>
          _RainArrivalWidgetState();
}

class _RainArrivalWidgetState
    extends State<RainArrivalWidget> {
  final SkyContextService
      _contextService =
      SkyContextService();

  final CloudClassifierService
      _cloudClassifier =
      CloudClassifierService();

  final ImagePicker _picker =
      ImagePicker();

  StreamSubscription<BarometerEvent>?
      _barometerSub;

  StreamSubscription<MagnetometerEvent>?
      _magnetometerSub;

  SkyContextResult? _context;

  Position? _position;

  double? _devicePressure;

  double _heading = 0.0;

  double? _altitude;

  bool _loadingWeather = true;
  bool _analyzing = false;

  String? _error;

  String? _cloudName;
  String? _cloudCode;
  double? _cloudConfidence;

  Uint8List? _lastImage;

  DateTime? _lastAnalysis;

  @override
  void initState() {
    super.initState();

    _startSensors();
    _loadContext();
  }

  @override
  void dispose() {
    _barometerSub?.cancel();
    _magnetometerSub?.cancel();

    _cloudClassifier.dispose();

    super.dispose();
  }

  void _startSensors() {
    try {
      _barometerSub =
          barometerEventStream().listen(
        (event) {
          if (!mounted) {
            return;
          }

          setState(() {
            _devicePressure =
                event.pressure;

            _recalculateAltitude();
          });
        },
        onError: (_) {},
      );
    } catch (_) {}

    try {
      _magnetometerSub =
          magnetometerEventStream()
              .listen(
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

  Future<Position?>
      _getPosition() async {
    bool serviceEnabled =
        await Geolocator
            .isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Zapni GPS / polohu.',
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
        'Aplikácia nemá povolenie k polohe.',
      );
    }

    return Geolocator
        .getCurrentPosition(
      desiredAccuracy:
          LocationAccuracy.high,
    );
  }

  Future<void> _loadContext() async {
    if (mounted) {
      setState(() {
        _loadingWeather = true;
        _error = null;
      });
    }

    try {
      final position =
          await _getPosition();

      if (position == null) {
        throw Exception(
          'Polohu sa nepodarilo zistiť.',
        );
      }

      final result =
          await _contextService.load(
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

        _context =
            result;

        _loadingWeather =
            false;

        _recalculateAltitude();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                );

        _loadingWeather =
            false;
      });
    }
  }

  void _recalculateAltitude() {
    final context =
        _context;

    if (_devicePressure != null &&
        context != null &&
        context.seaLevelPressure >
            0) {
      _altitude =
          SkyContextService
              .pressureAltitude(
        pressure:
            _devicePressure!,
        seaLevelPressure:
            context
                .seaLevelPressure,
      );

      return;
    }

    if (_position != null) {
      _altitude =
          _position!.altitude;
    }
  }

  Future<void> _analyzeSky()
      async {
    if (_analyzing) {
      return;
    }

    setState(() {
      _analyzing = true;
      _error = null;
    });

    try {
      /*
       * JEDNA FOTO.
       *
       * Smer si zapamätáme tesne
       * pred otvorením kamery.
       */
      final double photoHeading =
          _heading;

      final XFile? photo =
          await _picker.pickImage(
        source:
            ImageSource.camera,
        imageQuality: 88,
        maxWidth: 1800,
      );

      if (photo == null) {
        if (mounted) {
          setState(() {
            _analyzing = false;
          });
        }

        return;
      }

      final bytes =
          await photo.readAsBytes();

      final cloud =
          await _cloudClassifier
              .classify(
        bytes,
      );

      /*
       * Po fotke obnovíme modely,
       * aby sa AI porovnávala s čo
       * najčerstvejšími dátami.
       */
      final position =
          await _getPosition();

      SkyContextResult? context =
          _context;

      if (position != null) {
        context =
            await _contextService.load(
          latitude:
              position.latitude,
          longitude:
              position.longitude,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _position =
            position ??
                _position;

        _context =
            context;

        _heading =
            photoHeading;

        _lastImage =
            bytes;

        _lastAnalysis =
            DateTime.now();

        _cloudName =
            cloud?.name;

        _cloudCode =
            cloud?.code;

        _cloudConfidence =
            cloud?.confidence;

        _analyzing = false;

        _recalculateAltitude();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                );

        _analyzing =
            false;
      });
    }
  }

  bool get _isRainCloud {
    return _cloudCode == 'Cb' ||
        _cloudCode == 'Ns';
  }

  bool get _isConvective {
    return _cloudCode == 'Cb';
  }

  double get _incomingDifference {
    final context =
        _context;

    if (context == null) {
      return 180.0;
    }

    /*
     * windDirection znamená smer,
     * ODKIAĽ vietor prichádza.
     *
     * Používame ho ako pomocný modelový
     * odhad sektora, odkiaľ k nám môže
     * prichádzať systém.
     *
     * Toto NIE JE radarová trajektória.
     */
    return SkyContextService
        .circularDifference(
      _heading,
      context.windDirection,
    );
  }

  String get _viewRelation {
    final difference =
        _incomingDifference;

    if (difference <= 45) {
      return 'POZERÁŠ SA PRIBLIŽNE SMEROM, ODKIAĽ PRICHÁDZA POČASIE';
    }

    if (difference >= 135) {
      return 'TO, ČO SA BLÍŽI, JE PRAVDEPODOBNE ZA TEBOU';
    }

    return 'BLÍŽIACI SA SYSTÉM JE SKÔR MIMO TVOJHO PRIAMEHO POHĽADU';
  }

  String get _mainHeadline {
    final context =
        _context;

    if (context == null) {
      return 'AI ANALÝZA OBLOHY';
    }

    if (context.stormSignal &&
        context.nextRainMinutes !=
            null &&
        context.nextRainMinutes! <
            120) {
      return '⛈️ NIEČO SILNEJŠIE SA BLÍŽI';
    }

    if (context.nextRainMinutes !=
            null &&
        context.nextRainMinutes! <=
            60) {
      if (_incomingDifference >=
          135) {
        return '🌧️ POZOR, DÁŽĎ MÔŽE PRÍSŤ ZA TEBOU';
      }

      return '🌧️ DÁŽĎ SA BLÍŽI';
    }

    if (_isConvective) {
      return '☁️ TENTO OBLAK STOJÍ ZA POZORNOSŤ';
    }

    if (_cloudName != null) {
      return '👁️ VIDÍM ${_cloudName!.toUpperCase()}';
    }

    return '🤖 AI ANALÝZA OBLOHY';
  }

  String get _humanSummary {
    final context =
        _context;

    if (context == null) {
      return 'Namier kameru na oblohu. '
          'Porovnám to, čo vidíš, '
          's modelmi, vetrom, tlakom '
          'a tvojou polohou.';
    }

    final int? minutes =
        context.nextRainMinutes;

    if (_cloudName == null) {
      if (minutes == null) {
        return 'Modely zatiaľ nevidia '
            'výrazný dážď v blízkom '
            'časovom horizonte. '
            'Odfotím oblohu a skontrolujeme, '
            'či si atmosféra predsa len '
            'niečo nechystá.';
      }

      return 'Najbližší modelový signál '
          'zrážok je '
          '${SkyContextService.formatMinutes(minutes)}. '
          'Odfotím oblohu a skontrolujeme, '
          'či sa tomu zhoduje aj to, čo vidíš.';
    }

    if (_isRainCloud &&
        context.modelsAgreeOnRain) {
      if (_incomingDifference <= 45) {
        return 'To, čo vidíš, môže súvisieť '
            's počasím, ktoré prichádza k tvojej '
            'polohe. Kamera aj modely dávajú '
            'zrážkový signál.';
      }

      if (_incomingDifference >= 135) {
        return 'Oblak pred tebou je zaujímavý, '
            'ale modelovaný príchod počasia je '
            'z opačného sektora. Takže pozor: '
            'to podstatné môže byť práve za tebou.';
      }

      return 'Kamera vidí zrážkovo významný '
          'oblak, no modelovaný príchod počasia '
          'je skôr zboku. Nemusí ísť o ten istý systém.';
    }

    if (_isRainCloud &&
        !context.rainExpectedNext6Hours &&
        !context.ecmwfRainExpected) {
      return 'Vyzerá to hrozivo, ale modely '
          'zatiaľ nepotvrdzujú, že tento oblak '
          'zasiahne tvoju polohu. '
          'Možno veľa kriku pre nič.';
    }

    if (!_isRainCloud &&
        minutes != null &&
        minutes <= 120) {
      if (_incomingDifference >= 135) {
        return 'To, čo práve fotíš, zrejme nie je '
            'hlavný zrážkový systém. '
            'Modely však očakávajú dážď '
            '${SkyContextService.formatMinutes(minutes)} '
            'a smer príchodu je skôr za tebou.';
      }

      return 'Oblak pred tebou nemusí byť '
          'hlavný vinník. Modely však očakávajú '
          'dážď ${SkyContextService.formatMinutes(minutes)}.';
    }

    if (context.modelsAgreeOnDry) {
      return 'Kamera zatiaľ nevidí nič, '
          'čo by spolu s modelmi pôsobilo '
          'ako bezprostredná hrozba. '
          'Atmosféra má zatiaľ relatívne pokojný deň.';
    }

    if (context.modelsDisagree) {
      return 'Modely sa nevedia úplne dohodnúť. '
          'Presne v takomto prípade má kamera '
          'a lokálny tlak najväčší zmysel.';
    }

    return 'Obloha, modely a lokálne údaje '
        'sú vyhodnotené spolu. '
        'Momentálne tu nie je jednoznačný '
        'signál bezprostredného dažďa.';
  }

  String get _rainTimingText {
    final context =
        _context;

    if (context == null) {
      return '—';
    }

    if (context.nextRainMinutes ==
        null) {
      return 'Najbližších ~18 h bez jasného signálu';
    }

    return SkyContextService
        .formatMinutes(
      context.nextRainMinutes!,
    );
  }

  String get _rainClockText {
    final time =
        _context?.nextRainTime;

    if (time == null) {
      return '';
    }

    return 'okolo ${SkyContextService.formatClock(time)}';
  }

  String get _modelAgreementText {
    final context =
        _context;

    if (context == null) {
      return '—';
    }

    if (context.modelsAgreeOnRain) {
      return 'Open-Meteo + ECMWF: zhodujú sa na zrážkach';
    }

    if (context.modelsAgreeOnDry) {
      return 'Open-Meteo + ECMWF: zhodujú sa na suchšom scenári';
    }

    return 'Open-Meteo + ECMWF: rozchádzajú sa';
  }

  String get _cloudDisplay {
    if (_cloudName == null) {
      return 'Zatiaľ neodfotené';
    }

    final confidence =
        _cloudConfidence;

    if (confidence == null) {
      return _cloudName!;
    }

    return '${_cloudName!} '
        '(${_cloudCode ?? '?'}) • '
        '${(confidence * 100).toStringAsFixed(0)} %';
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        widget.onRefresh();
        await _loadContext();
      },
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          14,
          10,
          14,
          24,
        ),
        child: Column(
          children: [
            _buildHeroBanner(),

            const SizedBox(
              height: 14,
            ),

            if (_error != null)
              _buildError(),

            if (_loadingWeather)
              const Padding(
                padding:
                    EdgeInsets.all(
                  20,
                ),
                child:
                    CircularProgressIndicator(),
              )
            else ...[
              _buildRainCard(),

              const SizedBox(
                height: 12,
              ),

              _buildVisionCard(),

              const SizedBox(
                height: 12,
              ),

              _buildAtmosphereCard(),

              const SizedBox(
                height: 12,
              ),

              _buildModelCard(),

              const SizedBox(
                height: 12,
              ),

              _buildButtons(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    final context =
        _context;

    final bool rainy =
        context?.rainExpectedNext6Hours ??
            false;

    final double parallax =
        math.sin(
              _heading *
                  math.pi /
                  180,
            ) *
            14;

    return Container(
      width:
          double.infinity,
      constraints:
          const BoxConstraints(
        minHeight: 260,
      ),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          30,
        ),
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: rainy
              ? const [
                  Color(
                    0xFF111827,
                  ),
                  Color(
                    0xFF163A5F,
                  ),
                  Color(
                    0xFF355C7D,
                  ),
                ]
              : const [
                  Color(
                    0xFF071C36,
                  ),
                  Color(
                    0xFF0E4D78,
                  ),
                  Color(
                    0xFF2F80A8,
                  ),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withOpacity(
              0.28,
            ),
            blurRadius:
                24,
            offset:
                const Offset(
              0,
              14,
            ),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(
          30,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child:
                  CustomPaint(
                painter:
                    _AtmospherePainter(
                  rainy:
                      rainy,
                  storm:
                      context
                              ?.stormSignal ??
                          false,
                  parallax:
                      parallax,
                ),
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
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
                            0.13,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            99,
                          ),
                          border:
                              Border.all(
                            color:
                                Colors.white
                                    .withOpacity(
                              0.16,
                            ),
                          ),
                        ),
                        child:
                            const Text(
                          'MOJE METEO • AI',
                          style:
                              TextStyle(
                            color:
                                Colors.white70,
                            fontSize:
                                11,
                            fontWeight:
                                FontWeight.w700,
                            letterSpacing:
                                1.1,
                          ),
                        ),
                      ),

                      const Spacer(),

                      if (_lastAnalysis !=
                          null)
                        const Icon(
                          Icons
                              .check_circle,
                          color:
                              Color(
                            0xFF7EF7C9,
                          ),
                          size:
                              19,
                        ),
                    ],
                  ),

                  const SizedBox(
                    height: 28,
                  ),

                  Text(
                    _mainHeadline,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontWeight:
                          FontWeight.w900,
                      fontSize:
                          23,
                      height:
                          1.08,
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  Text(
                    _humanSummary,
                    style:
                        TextStyle(
                      color:
                          Colors.white
                              .withOpacity(
                        0.86,
                      ),
                      fontSize:
                          14,
                      height:
                          1.4,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child:
                            _heroStat(
                          'DÁŽĎ',
                          _rainTimingText,
                          Icons
                              .water_drop_outlined,
                        ),
                      ),

                      const SizedBox(
                        width: 9,
                      ),

                      Expanded(
                        child:
                            _heroStat(
                          'POHĽAD',
                          '${SkyContextService.directionName(_heading)} • ${_heading.toStringAsFixed(0)}°',
                          Icons
                              .explore_outlined,
                        ),
                      ),

                      const SizedBox(
                        width: 9,
                      ),

                      Expanded(
                        child:
                            _heroStat(
                          'VÝŠKA',
                          _altitude ==
                                  null
                              ? '—'
                              : '${_altitude!.toStringAsFixed(0)} m',
                          Icons
                              .terrain_outlined,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  SizedBox(
                    width:
                        double.infinity,
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          _analyzing
                              ? null
                              : _analyzeSky,
                      icon:
                          _analyzing
                              ? const SizedBox(
                                  width:
                                      18,
                                  height:
                                      18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                  ),
                                )
                              : const Icon(
                                  Icons
                                      .camera_alt_rounded,
                                ),
                      label:
                          Text(
                        _analyzing
                            ? 'Analyzujem oblohu...'
                            : 'AI ANALÝZA OBLOHY',
                      ),
                      style:
                          ElevatedButton.styleFrom(
                        minimumSize:
                            const Size(
                          double.infinity,
                          52,
                        ),
                        backgroundColor:
                            Colors.white,
                        foregroundColor:
                            const Color(
                          0xFF08223C,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            18,
                          ),
                        ),
                        textStyle:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
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

  Widget _heroStat(
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            10,
        vertical:
            11,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white
                .withOpacity(
          0.10,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border:
            Border.all(
          color:
              Colors.white
                  .withOpacity(
            0.11,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Icon(
            icon,
            color:
                Colors.white70,
            size:
                16,
          ),

          const SizedBox(
            height:
                7,
          ),

          Text(
            title,
            style:
                const TextStyle(
              color:
                  Colors.white54,
              fontSize:
                  9,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height:
                3,
          ),

          Text(
            value,
            maxLines:
                2,
            overflow:
                TextOverflow
                    .ellipsis,
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontSize:
                  12,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRainCard() {
    final context =
        _context;

    if (context == null) {
      return const SizedBox
          .shrink();
    }

    final probability =
        context.nextRainProbability ??
            context.currentRainProbability;

    return _glassCard(
      icon:
          Icons.umbrella_rounded,
      title:
          'Najbližší dážď',
      subtitle:
          context.nextRainMinutes ==
                  null
              ? 'Modely zatiaľ nevidia jasný nástup zrážok.'
              : '${_rainTimingText}${_rainClockText.isEmpty ? '' : ' • $_rainClockText'}',
      child:
          Column(
        children: [
          _dataRow(
            'Pravdepodobnosť',
            '$probability %',
          ),

          _dataRow(
            'Očakávanie',
            context
                .precipitationDescription,
          ),

          _dataRow(
            'Množstvo',
            context.nextRainAmount ==
                    null
                ? '—'
                : '${context.nextRainAmount!.toStringAsFixed(1)} mm/h',
          ),

          if (context.stormSignal)
            _warningStrip(
              'Búrkový alebo výraznejší '
              'zrážkový signál. Toto už '
              'nie je počasie len na okrasu.',
            ),
        ],
      ),
    );
  }

  Widget _buildVisionCard() {
    final context =
        _context;

    return _glassCard(
      icon:
          Icons.visibility_rounded,
      title:
          'Čo vidíš',
      subtitle:
          _cloudDisplay,
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .stretch,
        children: [
          _dataRow(
            'Smer kamery',
            '${SkyContextService.longDirectionName(_heading)} '
                '(${_heading.toStringAsFixed(0)}°)',
          ),

          if (context != null)
            _dataRow(
              'Sektor príchodu',
              '${SkyContextService.longDirectionName(context.windDirection)} '
                  '(${context.windDirection.toStringAsFixed(0)}°)',
            ),

          if (context != null &&
              context.nextRainMinutes !=
                  null)
            _warningStrip(
              _viewRelation,
              subtle:
                  true,
            ),

          if (_cloudName == null)
            Padding(
              padding:
                  const EdgeInsets.only(
                top:
                    8,
              ),
              child:
                  Text(
                'Jedna fotografia stačí. '
                'AI určí typ oblaku a '
                'porovná ho so smerom, '
                'modelmi a tým, čo sa '
                'očakáva na tvojej polohe.',
                style:
                    TextStyle(
                  color:
                      Colors.white
                          .withOpacity(
                    0.66,
                  ),
                  fontSize:
                      13,
                  height:
                      1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAtmosphereCard() {
    final context =
        _context;

    if (context == null) {
      return const SizedBox
          .shrink();
    }

    final double pressure =
        _devicePressure ??
            context.surfacePressure;

    return _glassCard(
      icon:
          Icons.air_rounded,
      title:
          'Atmosféra okolo teba',
      subtitle:
          'Lokálne údaje a výškomer',
      child:
          Column(
        children: [
          _dataRow(
            'Teplota',
            '${context.temperature.toStringAsFixed(1)} °C',
          ),

          _dataRow(
            'Pocitovo',
            '${context.apparentTemperature.toStringAsFixed(1)} °C',
          ),

          _dataRow(
            'Vlhkosť',
            '${context.humidity.toStringAsFixed(0)} %',
          ),

          _dataRow(
            'Tlak',
            '${pressure.toStringAsFixed(1)} hPa',
          ),

          _dataRow(
            'Nadmorská výška',
            _altitude == null
                ? '—'
                : '${_altitude!.toStringAsFixed(0)} m',
          ),

          _dataRow(
            'Vietor',
            '${context.windSpeed.toStringAsFixed(1)} km/h '
                'z ${SkyContextService.directionName(context.windDirection)}',
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard() {
    final context =
        _context;

    if (context == null) {
      return const SizedBox
          .shrink();
    }

    return _glassCard(
      icon:
          Icons.psychology_alt_rounded,
      title:
          'Čo si myslia modely',
      subtitle:
          _modelAgreementText,
      child:
          Column(
        children: [
          _dataRow(
            'Open-Meteo',
            context.rainExpectedNext6Hours
                ? 'zrážkový signál'
                : 'bez výrazného signálu',
          ),

          _dataRow(
            'ECMWF IFS',
            context.ecmwfRainExpected
                ? 'zrážkový signál'
                : 'bez výrazného signálu',
          ),

          _dataRow(
            'ECMWF max. 6 h',
            context.ecmwfMaxRain6h ==
                    null
                ? '—'
                : '${context.ecmwfMaxRain6h!.toStringAsFixed(1)} mm/h',
          ),

          if (context.modelsDisagree)
            _warningStrip(
              'Modely sa nezhodujú. '
              'Práve tu je fotografia oblohy '
              'a lokálne meranie najcennejšie.',
              subtle:
                  true,
            ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child:
              OutlinedButton.icon(
            onPressed:
                () async {
              widget.onRefresh();
              await _loadContext();
            },
            icon:
                const Icon(
              Icons.refresh_rounded,
            ),
            label:
                const Text(
              'Obnoviť',
            ),
          ),
        ),

        const SizedBox(
          width:
              10,
        ),

        Expanded(
          child:
              FilledButton.icon(
            onPressed:
                widget.onOpenMap,
            icon:
                const Icon(
              Icons.radar_rounded,
            ),
            label:
                const Text(
              'Radar / mapa',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      width:
          double.infinity,
      margin:
          const EdgeInsets.only(
        bottom:
            12,
      ),
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.red
                .withOpacity(
          0.10,
        ),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              Colors.redAccent
                  .withOpacity(
            0.25,
          ),
        ),
      ),
      child: Text(
        _error!,
        style:
            const TextStyle(
          color:
              Colors.redAccent,
        ),
      ),
    );
  }

  Widget _glassCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        17,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFF0E1726,
        ),
        borderRadius:
            BorderRadius.circular(
          24,
        ),
        border:
            Border.all(
          color:
              Colors.white
                  .withOpacity(
            0.07,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withOpacity(
              0.16,
            ),
            blurRadius:
                18,
            offset:
                const Offset(
              0,
              8,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Row(
            children: [
              Container(
                width:
                    42,
                height:
                    42,
                decoration:
                    BoxDecoration(
                  color:
                      Colors.white
                          .withOpacity(
                    0.07,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child:
                    Icon(
                  icon,
                  color:
                      const Color(
                    0xFF86D8FF,
                  ),
                ),
              ),

              const SizedBox(
                width:
                    12,
              ),

              Expanded(
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
                        fontSize:
                            16,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height:
                          2,
                    ),

                    Text(
                      subtitle,
                      style:
                          TextStyle(
                        color:
                            Colors.white
                                .withOpacity(
                          0.56,
                        ),
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
                14,
          ),

          child,
        ],
      ),
    );
  }

  Widget _dataRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical:
            6,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Expanded(
            child:
                Text(
              label,
              style:
                  TextStyle(
                color:
                    Colors.white
                        .withOpacity(
                  0.56,
                ),
                fontSize:
                    13,
              ),
            ),
          ),

          const SizedBox(
            width:
                12,
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
                    13,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningStrip(
    String text, {
    bool subtle = false,
  }) {
    return Container(
      width:
          double.infinity,
      margin:
          const EdgeInsets.only(
        top:
            10,
      ),
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color: subtle
            ? Colors.white
                .withOpacity(
                0.05,
              )
            : const Color(
                0xFFFFB74D,
              ).withOpacity(
                0.12,
              ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border:
            Border.all(
          color: subtle
              ? Colors.white
                  .withOpacity(
                  0.06,
                )
              : const Color(
                  0xFFFFB74D,
                ).withOpacity(
                  0.22,
                ),
        ),
      ),
      child: Text(
        text,
        style:
            TextStyle(
          color: subtle
              ? Colors.white70
              : const Color(
                  0xFFFFD08A,
                ),
          fontSize:
              12,
          fontWeight:
              FontWeight.w700,
          height:
              1.35,
        ),
      ),
    );
  }
}

class _AtmospherePainter
    extends CustomPainter {
  final bool rainy;
  final bool storm;
  final double parallax;

  const _AtmospherePainter({
    required this.rainy,
    required this.storm,
    required this.parallax,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final Paint glow =
        Paint()
          ..shader =
              RadialGradient(
            colors: [
              Colors.white.withOpacity(
                rainy
                    ? 0.05
                    : 0.18,
              ),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center:
                  Offset(
                size.width *
                        0.82 +
                    parallax,
                size.height *
                    0.10,
              ),
              radius:
                  120,
            ),
          );

    canvas.drawCircle(
      Offset(
        size.width * 0.82 +
            parallax,
        size.height * 0.10,
      ),
      120,
      glow,
    );

    final Paint cloud =
        Paint()
          ..color =
              Colors.white.withOpacity(
            rainy
                ? 0.055
                : 0.09,
          );

    _drawCloud(
      canvas,
      Offset(
        size.width * 0.72 +
            parallax,
        96,
      ),
      1.25,
      cloud,
    );

    _drawCloud(
      canvas,
      Offset(
        size.width * 0.18 -
            parallax * 0.5,
        168,
      ),
      0.72,
      cloud,
    );

    if (rainy) {
      final Paint rainPaint =
          Paint()
            ..color =
                Colors.white
                    .withOpacity(
              0.08,
            )
            ..strokeWidth =
                1.2;

      for (int i = 0;
          i < 13;
          i++) {
        final x =
            (size.width /
                    13) *
                i;

        canvas.drawLine(
          Offset(
            x,
            size.height *
                0.60,
          ),
          Offset(
            x - 7,
            size.height *
                    0.60 +
                30,
          ),
          rainPaint,
        );
      }
    }

    if (storm) {
      final Paint lightning =
          Paint()
            ..color =
                const Color(
                  0xFFFFE082,
                ).withOpacity(
              0.24,
            )
            ..style =
                PaintingStyle.stroke
            ..strokeWidth =
                2;

      final Path path =
          Path()
            ..moveTo(
              size.width * 0.82,
              92,
            )
            ..lineTo(
              size.width * 0.76,
              128,
            )
            ..lineTo(
              size.width * 0.81,
              128,
            )
            ..lineTo(
              size.width * 0.75,
              177,
            );

      canvas.drawPath(
        path,
        lightning,
      );
    }
  }

  void _drawCloud(
    Canvas canvas,
    Offset center,
    double scale,
    Paint paint,
  ) {
    canvas.drawCircle(
      Offset(
        center.dx,
        center.dy,
      ),
      34 * scale,
      paint,
    );

    canvas.drawCircle(
      Offset(
        center.dx +
            33 * scale,
        center.dy +
            5 * scale,
      ),
      26 * scale,
      paint,
    );

    canvas.drawCircle(
      Offset(
        center.dx -
            30 * scale,
        center.dy +
            10 * scale,
      ),
      23 * scale,
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
              110 * scale,
          height:
              36 * scale,
        ),
        Radius.circular(
          18 * scale,
        ),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _AtmospherePainter
        oldDelegate,
  ) {
    return oldDelegate.rainy !=
            rainy ||
        oldDelegate.storm !=
            storm ||
        oldDelegate.parallax !=
            parallax;
  }
}
