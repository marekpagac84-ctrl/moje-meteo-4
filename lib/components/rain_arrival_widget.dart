import 'package:flutter/material.dart';
import '../models/meteo_data.dart';

class RainArrivalWidget extends StatelessWidget {
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

  // ==========================================================
  // WEATHER ICON
  // ==========================================================

  IconData _weatherIcon(int code) {
    if (code == 0) {
      return Icons.wb_sunny_rounded;
    }

    if (code == 1 || code == 2) {
      // partly_cloudy_day_rounded vo Flutter 3.19.6 nie je.
      return Icons.cloud_queue_rounded;
    }

    if (code == 3) {
      return Icons.cloud_rounded;
    }

    if (code >= 45 && code <= 48) {
      return Icons.foggy;
    }

    if (code >= 51 && code <= 57) {
      return Icons.water_drop_rounded;
    }

    if (code >= 61 && code <= 67) {
      return Icons.water_drop_rounded;
    }

    if (code >= 71 && code <= 77) {
      return Icons.ac_unit_rounded;
    }

    if (code >= 80 && code <= 82) {
      return Icons.grain_rounded;
    }

    if (code >= 95) {
      return Icons.thunderstorm_rounded;
    }

    return Icons.cloud_rounded;
  }

  // ==========================================================
  // WEATHER TEXT
  // ==========================================================

  String _weatherText(int code) {
    if (code == 0) return 'Jasno';
    if (code == 1) return 'Prevažne jasno';
    if (code == 2) return 'Polooblačno';
    if (code == 3) return 'Oblačno';

    if (code == 45 || code == 48) {
      return 'Hmla';
    }

    if (code >= 51 && code <= 55) {
      return 'Mrholenie';
    }

    if (code >= 56 && code <= 57) {
      return 'Mrznúce mrholenie';
    }

    if (code >= 61 && code <= 65) {
      return 'Dážď';
    }

    if (code >= 66 && code <= 67) {
      return 'Mrznúci dážď';
    }

    if (code >= 71 && code <= 77) {
      return 'Sneženie';
    }

    if (code >= 80 && code <= 82) {
      return 'Prehánky';
    }

    if (code == 95) {
      return 'Búrka';
    }

    if (code >= 96) {
      return 'Búrka s krúpami';
    }

    return 'Neznáme počasie';
  }

  // ==========================================================
  // DEŇ
  // ==========================================================

  String _dayName(String date) {
    final parsed = DateTime.tryParse(date);

    if (parsed == null) {
      return date;
    }

    const names = [
      'Po',
      'Ut',
      'St',
      'Št',
      'Pi',
      'So',
      'Ne',
    ];

    return names[parsed.weekday - 1];
  }

  // ==========================================================
  // ČAS
  // ==========================================================

  String _formatTime(String value) {
    if (value.contains('T')) {
      final parts = value.split('T');

      if (parts.length > 1 &&
          parts[1].length >= 5) {
        return parts[1].substring(0, 5);
      }
    }

    return value;
  }

  // ==========================================================
  // HLAVNÁ KARTA
  // ==========================================================

  Widget _buildMainWeather() {
    if (meteoData == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1E3A8A),
              Color(0xFF1E293B),
            ],
          ),
          borderRadius:
              BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 46,
              color: Colors.white54,
            ),
            const SizedBox(height: 12),
            Text(
              isLoading
                  ? 'Načítavam počasie...'
                  : 'Počasie nie je dostupné',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Čakám na meteorologické dáta.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final data = meteoData!;

    final temperature =
        data.currentTemperature;

    final weatherCode =
        data.currentWeatherCode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2563EB),
            Color(0xFF1E3A8A),
            Color(0xFF1E293B),
          ],
        ),
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'AKTUÁLNE POČASIE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              IconButton(
                onPressed:
                    isLoading
                        ? null
                        : onRefresh,
                tooltip:
                    'Obnoviť počasie',
                icon: isLoading
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons
                            .refresh_rounded,
                        color:
                            Colors.white,
                        size: 22,
                      ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Icon(
                _weatherIcon(
                  weatherCode,
                ),
                color: Colors.white,
                size: 64,
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          temperature
                              .toStringAsFixed(
                            0,
                          ),
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontSize: 58,
                            height: 0.95,
                            fontWeight:
                                FontWeight.w300,
                          ),
                        ),
                        const Padding(
                          padding:
                              EdgeInsets.only(
                            top: 4,
                          ),
                          child: Text(
                            '°C',
                            style:
                                TextStyle(
                              color:
                                  Colors.white70,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      _weatherText(
                        weatherCode,
                      ),
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            padding:
                const EdgeInsets.symmetric(
              vertical: 13,
            ),
            decoration: BoxDecoration(
              color: Colors.white
                  .withOpacity(0.10),
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _infoItem(
                    Icons.air_rounded,
                    'Vietor',
                    '${data.currentWindSpeed.toStringAsFixed(1)} km/h',
                  ),
                ),

                _verticalDivider(),

                Expanded(
                  child: _infoItem(
                    Icons.explore_rounded,
                    'Smer',
                    '${data.currentWindDirection.toStringAsFixed(0)}°',
                  ),
                ),

                _verticalDivider(),

                Expanded(
                  child: _infoItem(
                    Icons.speed_rounded,
                    'Tlak',
                    '${data.currentPressure.toStringAsFixed(0)} hPa',
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
  // INFO
  // ==========================================================

  Widget _infoItem(
    IconData icon,
    String label,
    String value,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 19,
          color: Colors.white70,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight:
                FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 35,
      width: 1,
      color: Colors.white12,
    );
  }

  // ==========================================================
  // DNES
  // ==========================================================

  Widget _buildToday() {
    final data = meteoData!;

    if (data.dailyTimes == null ||
        data.dailyTimes!.isEmpty ||
        data.dailyTemperatureMax == null ||
        data.dailyTemperatureMax!.isEmpty ||
        data.dailyTemperatureMin == null ||
        data.dailyTemperatureMin!.isEmpty ||
        data.dailyWeatherCode == null ||
        data.dailyWeatherCode!.isEmpty) {
      return const SizedBox.shrink();
    }

    final max =
        data.dailyTemperatureMax!.first;

    final min =
        data.dailyTemperatureMin!.first;

    final code =
        data.dailyWeatherCode!.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            const Color(0xFF1E293B),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _weatherIcon(code),
            color: Colors.amberAccent,
            size: 34,
          ),

          const SizedBox(width: 13),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'DNES',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Denná predpoveď',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Text(
            '${max.toStringAsFixed(0)}°',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(width: 8),

          Text(
            '${min.toStringAsFixed(0)}°',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // HOURLY
  // ==========================================================

  Widget _buildHourly() {
    final data = meteoData!;

    if (data.hourlyTimes == null ||
        data.hourlyTemperature == null ||
        data.hourlyWeatherCode == null) {
      return const SizedBox.shrink();
    }

    final count = [
      data.hourlyTimes!.length,
      data.hourlyTemperature!.length,
      data.hourlyWeatherCode!.length,
    ].reduce(
      (a, b) => a < b ? a : b,
    );

    if (count == 0) {
      return const SizedBox.shrink();
    }

    final visible =
        count > 8 ? 8 : count;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
            'NAJBLIŽŠIE HODINY',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight:
                  FontWeight.bold,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 105,
            child:
                ListView.separated(
              scrollDirection:
                  Axis.horizontal,
              itemCount: visible,
              separatorBuilder:
                  (_, __) =>
                      const SizedBox(
                width: 8,
              ),
              itemBuilder:
                  (context, index) {
                final probability =
                    data.hourlyPrecipitationProbability !=
                                null &&
                            data
                                    .hourlyPrecipitationProbability!
                                    .length >
                                index
                        ? data
                            .hourlyPrecipitationProbability![index]
                        : 0;

                final code =
                    data.hourlyWeatherCode![index];

                final precipitation =
                    data.hourlyPrecipitation !=
                                null &&
                            data.hourlyPrecipitation!
                                    .length >
                                index
                        ? data.hourlyPrecipitation![index]
                        : 0.0;

                return Container(
                  width: 72,
                  padding:
                      const EdgeInsets.all(
                    7,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFF0F172A,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    children: [
                      Text(
                        _formatTime(
                          data.hourlyTimes![
                              index],
                        ),
                        style:
                            const TextStyle(
                          color:
                              Colors.white60,
                          fontSize: 10,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Icon(
                        _weatherIcon(code),
                        color:
                            Colors.white,
                        size: 22,
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        '${data.hourlyTemperature![index].toStringAsFixed(0)}°',
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 13,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      if (probability > 20)
                        Text(
                          '$probability%',
                          style:
                              const TextStyle(
                            color: Colors
                                .lightBlueAccent,
                            fontSize: 9,
                          ),
                        ),

                      if (precipitation >
                          0.0)
                        Text(
                          '${precipitation.toStringAsFixed(1)} mm',
                          style:
                              const TextStyle(
                            color:
                                Colors.white54,
                            fontSize: 8,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // MAPA
  // ==========================================================

  Widget _buildWindyBanner() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenMap,
        borderRadius:
            BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.all(16),
          decoration:
              BoxDecoration(
            gradient:
                const LinearGradient(
              colors: [
                Color(0xFF0F4C81),
                Color(0xFF172554),
              ],
            ),
            borderRadius:
                BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white12,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.all(
                  10,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withOpacity(0.10),
                  shape:
                      BoxShape.circle,
                ),
                child: const Icon(
                  Icons.public_rounded,
                  color:
                      Colors.white,
                  size: 25,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'RADAR A VIETOR',
                      style: TextStyle(
                        color:
                            Colors.white,
                        fontSize: 13,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Pozrieť aktuálnu situáciu na mape',
                      style: TextStyle(
                        color:
                            Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,
                color:
                    Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics:
          const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildMainWeather(),

          const SizedBox(height: 12),

          if (meteoData != null)
            _buildToday(),

          const SizedBox(height: 12),

          if (meteoData != null)
            _buildHourly(),

          const SizedBox(height: 12),

          _buildWindyBanner(),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
