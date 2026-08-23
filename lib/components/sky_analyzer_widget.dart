import 'package:flutter/material.dart';

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

class _SkyAnalyzerWidgetState
    extends State<SkyAnalyzerWidget> {
  final WeatherIntelligenceService _service =
      WeatherIntelligenceService();

  WeatherIntelligenceResult? _result;

  bool _loading = false;

  Future<void> _analyze() async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    final result =
        await _service.analyze(
      lat: widget.lat,
      lng: widget.lng,
      pressure:
          widget.barometer.currentPressure,
      pressureChangeRate:
          widget.barometer.pressureChangeRate,
      heading: widget.heading,
      tiltX: widget.tiltX,
      tiltY: widget.tiltY,
    );

    if (!mounted) return;

    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color:
                  const Color(0xFF1E293B),
              borderRadius:
                  BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white12,
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  '🔎 LOKÁLNA ANALÝZA POČASIA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Aplikácia spojí údaje z telefónu '
                  's online meteorologickými dátami '
                  'a pokúsi sa odhadnúť situáciu '
                  'priamo na tvojej polohe.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 16),

                _dataRow(
                  '📍 Poloha',
                  '${widget.lat.toStringAsFixed(4)}, '
                      '${widget.lng.toStringAsFixed(4)}',
                ),

                _dataRow(
                  '🧭 Smer telefónu',
                  '${widget.heading.toStringAsFixed(0)}°',
                ),

                _dataRow(
                  '📐 Náklon X',
                  '${widget.tiltX.toStringAsFixed(1)}°',
                ),

                _dataRow(
                  '📐 Náklon Y',
                  '${widget.tiltY.toStringAsFixed(1)}°',
                ),

                _dataRow(
                  '🌡️ Tlak',
                  widget.barometer.currentPressure > 0
                      ? '${widget.barometer.currentPressure.toStringAsFixed(1)} hPa'
                      : 'N/A',
                ),

                _dataRow(
                  '📉 Zmena tlaku',
                  '${widget.barometer.pressureChangeRate.toStringAsFixed(3)} hPa',
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _loading ? null : _analyze,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.radar_rounded,
                          ),
                    label: Text(
                      _loading
                          ? 'VYHODNOCUJEM...'
                          : 'VYHODNOTIŤ SITUÁCIU',
                    ),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF2563EB),
                      foregroundColor:
                          Colors.white,
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 13,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_result != null) ...[
            const SizedBox(height: 12),
            _buildResult(_result!),
          ],
        ],
      ),
    );
  }

  Widget _buildResult(
    WeatherIntelligenceResult result,
  ) {
    Color accent;

    if (result.stormNearby) {
      accent = Colors.redAccent;
    } else if (result.rainLikelySoon) {
      accent = Colors.lightBlueAccent;
    } else {
      accent = Colors.amber;
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            const Color(0xFF1E293B),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              accent.withOpacity(0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                result.stormNearby
                    ? Icons.thunderstorm_rounded
                    : result.rainLikelySoon
                        ? Icons.water_drop_rounded
                        : Icons.wb_sunny_rounded,
                color: accent,
                size: 34,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
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

          Text(
            result.confidenceText,
            style: TextStyle(
              color: accent,
              fontWeight:
                  FontWeight.bold,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 7),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: result.confidence,
              minHeight: 7,
              backgroundColor:
                  Colors.white12,
              valueColor:
                  AlwaysStoppedAnimation<Color>(
                accent,
              ),
            ),
          ),

          const SizedBox(height: 18),

          if (result.rainProbability != null)
            _dataRow(
              '🌧️ Pravdepodobnosť zrážok',
              '${result.rainProbability} %',
            ),

          if (result.precipitation != null)
            _dataRow(
              '💧 Aktuálne zrážky',
              '${result.precipitation!.toStringAsFixed(1)} mm',
            ),

          if (result.windSpeed != null)
            _dataRow(
              '💨 Vietor',
              '${result.windSpeed!.toStringAsFixed(1)} m/s',
            ),

          if (result.windDirection != null)
            _dataRow(
              '🧭 Smer vetra',
              '${result.windDirection!.toStringAsFixed(0)}°',
            ),

          if (result.evidence.isNotEmpty) ...[
            const Divider(
              color: Colors.white12,
              height: 28,
            ),

            const Text(
              'ČO K TOMU VIEDLO',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight:
                    FontWeight.bold,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 8),

            for (final item
                in result.evidence)
              Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 6,
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        color: accent,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style:
                            const TextStyle(
                          color:
                              Colors.white70,
                          fontSize: 12,
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

  Widget _dataRow(
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
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign:
                  TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
