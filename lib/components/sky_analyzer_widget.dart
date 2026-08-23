import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/meteo_data.dart';
import '../services/weather_intelligence_service.dart';

class SkyAnalyzerWidget extends StatefulWidget {
  final double lat;
  final double lng;
  final double heading;
  final double tiltX;
  final double tiltY;

  final BarometerState barometer;
  final MeteoApiData? meteoData;

  const SkyAnalyzerWidget({
    super.key,
    required this.lat,
    required this.lng,
    required this.heading,
    required this.tiltX,
    required this.tiltY,
    required this.barometer,
    required this.meteoData,
  });

  @override
  State<SkyAnalyzerWidget> createState() =>
      _SkyAnalyzerWidgetState();
}

class _SkyAnalyzerWidgetState extends State<SkyAnalyzerWidget> {
  final WeatherIntelligenceService _service =
      WeatherIntelligenceService();

  final ImagePicker _picker = ImagePicker();

  WeatherIntelligenceResult? _result;

  Uint8List? _imageBytes;

  bool _loading = false;
  bool _takingPhoto = false;

  // ==========================================================
  // FOTO
  // ==========================================================

  Future<void> _takePhoto() async {
    if (_takingPhoto || _loading) return;

    setState(() {
      _takingPhoto = true;
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (photo == null) {
        if (mounted) {
          setState(() {
            _takingPhoto = false;
          });
        }
        return;
      }

      final Uint8List bytes = await photo.readAsBytes();

      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
        _takingPhoto = false;
        _result = null;
      });
    } catch (e) {
      debugPrint('Camera error: $e');

      if (!mounted) return;

      setState(() {
        _takingPhoto = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kameru sa nepodarilo spustiť.',
          ),
        ),
      );
    }
  }

  // ==========================================================
  // ANALÝZA
  // ==========================================================

  Future<void> _analyze() async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    final WeatherIntelligenceResult result =
        await _service.analyze(
      lat: widget.lat,
      lng: widget.lng,
      pressure: widget.barometer.currentPressure,
      pressureChangeRate:
          widget.barometer.pressureChangeRate,
      heading: widget.heading,
      tiltX: widget.tiltX,
      tiltY: widget.tiltY,
      imageBytes: _imageBytes,
      meteoData: widget.meteoData,
    );

    if (!mounted) return;

    setState(() {
      _result = result;
      _loading = false;
    });
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildHeader(),

          const SizedBox(height: 14),

          _buildCameraBanner(),

          const SizedBox(height: 14),

          _buildSensorSummary(),

          const SizedBox(height: 14),

          _buildAnalyzeButton(),

          if (_result != null) ...[
            const SizedBox(height: 16),
            _buildResult(_result!),
          ],

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ==========================================================
  // HLAVIČKA
  // ==========================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        18,
        18,
        18,
        16,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF172554),
            Color(0xFF1E3A8A),
            Color(0xFF1E293B),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.blueAccent.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.lightBlueAccent,
              size: 27,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'SKY INTELLIGENCE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Lokálna analýza počasia',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bolt_rounded,
                  color: Colors.amberAccent,
                  size: 15,
                ),
                SizedBox(width: 4),
                Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // KAMERA – HERO BANNER
  // ==========================================================

  Widget _buildCameraBanner() {
    return GestureDetector(
      onTap:
          _takingPhoto || _loading
              ? null
              : _takePhoto,
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 250),
        width: double.infinity,
        height: 210,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color:
                _imageBytes != null
                    ? Colors.lightBlueAccent
                        .withOpacity(0.45)
                    : Colors.white12,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child:
            _imageBytes == null
                ? _buildCameraPlaceholder()
                : _buildPhotoPreview(),
      ),
    );
  }

  // ==========================================================
  // KAMERA – PLACEHOLDER
  // ==========================================================

  Widget _buildCameraPlaceholder() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F2747),
                Color(0xFF075985),
                Color(0xFF164E63),
              ],
            ),
          ),
        ),

        Positioned(
          right: -25,
          top: -35,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),

        Positioned(
          left: -45,
          bottom: -55,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.lightBlueAccent
                  .withOpacity(0.07),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(17),
                ),
                child: _takingPhoto
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color:
                              Colors.lightBlueAccent,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
              ),

              const SizedBox(height: 14),

              const Text(
                'ZACHYŤ OBLOHU',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                _takingPhoto
                    ? 'Spúšťam kameru...'
                    : 'Namier telefón na oblohu a odfoť aktuálnu situáciu.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 14),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'ODFOTIŤ OBLOHU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // KAMERA – FOTO
  // ==========================================================

  Widget _buildPhotoPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(
          _imageBytes!,
          fit: BoxFit.cover,
        ),

        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.05),
                Colors.black.withOpacity(0.55),
              ],
            ),
          ),
        ),

        Positioned(
          left: 16,
          bottom: 16,
          child: Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.lightGreenAccent,
                  size: 17,
                ),
                SizedBox(width: 6),
                Text(
                  'OBLOHA ZACHYTENÁ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          right: 14,
          bottom: 14,
          child: Material(
            color: Colors.black.withOpacity(0.55),
            borderRadius:
                BorderRadius.circular(20),
            child: InkWell(
              onTap:
                  _takingPhoto || _loading
                      ? null
                      : _takePhoto,
              borderRadius:
                  BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'ZMENIŤ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // SENZORY – KOMPAKTNÝ PANEL
  // ==========================================================

  Widget _buildSensorSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        14,
        14,
        14,
        12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sensors_rounded,
                color: Colors.lightBlueAccent,
                size: 19,
              ),
              const SizedBox(width: 7),
              const Text(
                'DÁTA PRE ANALÝZU',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.greenAccent
                      .withOpacity(0.8),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _miniSensor(
                  Icons.explore_rounded,
                  'SMER',
                  '${widget.heading.toStringAsFixed(0)}°',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniSensor(
                  Icons.speed_rounded,
                  'TLAK',
                  widget.barometer.currentPressure >
                          0
                      ? '${widget.barometer.currentPressure.toStringAsFixed(1)}'
                      : 'N/A',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniSensor(
                  Icons.trending_down_rounded,
                  'ZMENА',
                  '${widget.barometer.pressureChangeRate.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _miniSensor(
                  Icons.swap_vert_rounded,
                  'NÁKLON X',
                  '${widget.tiltX.toStringAsFixed(1)}°',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniSensor(
                  Icons.screen_rotation_rounded,
                  'NÁKLON Y',
                  '${widget.tiltY.toStringAsFixed(1)}°',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniSensor(
                  Icons.location_on_rounded,
                  'GPS',
                  '${widget.lat.toStringAsFixed(2)}°',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniSensor(
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white54,
            size: 17,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // HLAVNÉ TLAČIDLO
  // ==========================================================

  Widget _buildAnalyzeButton() {
    final bool enabled =
        !_loading && _imageBytes != null;

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed:
            enabled ? _analyze : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              const Color(0xFF2563EB),
          disabledBackgroundColor:
              Colors.white10,
          foregroundColor: Colors.white,
          disabledForegroundColor:
              Colors.white30,
          elevation: enabled ? 5 : 0,
          shadowColor:
              Colors.blueAccent.withOpacity(0.35),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(17),
          ),
        ),
        child: _loading
            ? const Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 21,
                    height: 21,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 11),
                  Text(
                    'ANALYZUJEM OBLOHU...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    enabled
                        ? Icons.auto_awesome_rounded
                        : Icons.camera_alt_outlined,
                    size: 21,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    enabled
                        ? 'VYHODNOTIŤ SITUÁCIU'
                        : 'NAJPRV ODFOŤ OBLOHU',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ==========================================================
  // VÝSLEDOK
  // ==========================================================

  Widget _buildResult(
    WeatherIntelligenceResult result,
  ) {
    Color accent;
    IconData icon;

    if (result.stormNearby) {
      accent = Colors.redAccent;
      icon = Icons.thunderstorm_rounded;
    } else if (result.rainLikelySoon) {
      accent = Colors.lightBlueAccent;
      icon = Icons.water_drop_rounded;
    } else {
      accent = Colors.amberAccent;
      icon = Icons.wb_sunny_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withOpacity(0.40),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 27,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VÝSLEDOK ANALÝZY',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      result.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      result.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: Text(
                  result.confidenceText,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),

              Text(
                '${(result.confidence * 100).toStringAsFixed(0)} %',
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: result.confidence,
              minHeight: 7,
              backgroundColor: Colors.white10,
              valueColor:
                  AlwaysStoppedAnimation<Color>(
                accent,
              ),
            ),
          ),

          const SizedBox(height: 18),

          if (result.rainProbability != null)
            _resultRow(
              '🌧️',
              'Pravdepodobnosť zrážok',
              '${result.rainProbability} %',
              accent,
            ),

          if (result.precipitation != null)
            _resultRow(
              '💧',
              'Zrážky',
              '${result.precipitation!.toStringAsFixed(1)} mm',
              accent,
            ),

          if (result.windSpeed != null)
            _resultRow(
              '💨',
              'Vietor',
              '${result.windSpeed!.toStringAsFixed(1)} m/s',
              accent,
            ),

          if (result.windDirection != null)
            _resultRow(
              '🧭',
              'Smer vetra',
              '${result.windDirection!.toStringAsFixed(0)}°',
              accent,
            ),

          if (result.skyBluePercent != null)
            _resultRow(
              '🔵',
              'Modrá obloha',
              '${result.skyBluePercent!.toStringAsFixed(0)} %',
              accent,
            ),

          if (result.cloudinessEstimate != null)
            _resultRow(
              '☁️',
              'Odhad oblačnosti',
              '${result.cloudinessEstimate!.toStringAsFixed(0)} %',
              accent,
            ),

          if (result.evidence.isNotEmpty) ...[
            const Divider(
              color: Colors.white10,
              height: 30,
            ),

            const Text(
              'PREČO SI TO MYSLÍM',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 10),

            for (final item in result.evidence)
              Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 8,
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin:
                          const EdgeInsets.only(
                        top: 5,
                        right: 8,
                      ),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ==========================================================
  // RIADOK VÝSLEDKU
  // ==========================================================

  Widget _resultRow(
    String emoji,
    String name,
    String value,
    Color accent,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 27,
            child: Text(
              emoji,
              style:
                  const TextStyle(fontSize: 14),
            ),
          ),

          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ),

          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
