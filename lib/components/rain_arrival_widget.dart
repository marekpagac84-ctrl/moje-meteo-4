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
  // POČASIE PODĽA WMO KÓDU
  // ==========================================================

  IconData _weatherIcon(int code) {
    if (code == 0) {
      return Icons.wb_sunny_rounded;
    }

    if (code <= 3) {
      return Icons.cloud_rounded;
    }

    if (code == 45 || code == 48) {
      return Icons.foggy;
    }

    if (code >= 51 && code <= 67) {
      return Icons.water_drop_rounded;
    }

    if (code >= 71 && code <= 77) {
      return Icons.ac_unit_rounded;
    }

    if (code >= 80 && code <= 82) {
      return Icons.umbrella_rounded;
    }

    if (code >= 95) {
      return Icons.thunderstorm_rounded;
    }

    return Icons.cloud_rounded;
  }

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

  String _directionName(double degrees) {
    if (degrees >= 337.5 || degrees < 22.5) {
      return 'S';
    }

    if (degrees < 67.5) return 'SV';
    if (degrees < 112.5) return 'V';
    if (degrees < 157.5) return 'JV';
    if (degrees < 202.5) return 'J';
    if (degrees < 247.5) return 'JZ';
    if (degrees < 292.5) return 'Z';

    return 'SZ';
  }

  String _time(String value) {
    if (value.contains('T')) {
      final part = value.split('T').last;

      if (part.length >= 5) {
        return part.substring(0, 5);
      }
    }

    return value;
  }

  String _dayName(String value, int index) {
    if (index == 0) return 'Dnes';
    if (index == 1) return 'Zajtra';

    try {
      final date =
          DateTime.parse(value);

      const names = [
        'Po',
        'Ut',
        'St',
        'Št',
        'Pi',
        'So',
        'Ne',
      ];

      return names[date.weekday - 1];
    } catch (_) {
      return '';
    }
  }

  // ==========================================================
  // HORNÝ AKTUÁLNY STAV
  // ==========================================================

  Widget _buildCurrentWeather() {
    final data = meteoData!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        18,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A8A),
            Color(0xFF172554),
            Color(0xFF0F172A),
          ],
        ),
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white12,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'Moje aktuálne počasie',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Obnoviť počasie',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                onPressed:
                    isLoading ? null : onRefresh,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.center,
            children: [
              Icon(
                _weatherIcon(
                  data.currentWeatherCode,
                ),
                color: Colors.white,
                size: 72,
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.currentTemperature.round()}°',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        height: 0.95,
                        fontWeight: FontWeight.w300,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      _weatherText(
                        data.currentWeatherCode,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _miniInfo(
                  Icons.air_rounded,
                  '${data.currentWindSpeed.toStringAsFixed(1)} m/s',
                  _directionName(
                    data.currentWindDirection,
                  ),
                ),
              ),
              Expanded(
                child: _miniInfo(
                  Icons.water_drop_outlined,
                  data.hourlyHumidity != null &&
                          data.hourlyHumidity!.isNotEmpty
                      ? '${data.hourlyHumidity!.first.round()} %'
                      : '—',
                  'vlhkosť',
                ),
              ),
              Expanded(
                child: _miniInfo(
                  Icons.speed_rounded,
                  data.currentPressure > 0
                      ? '${data.currentPressure.round()}'
                      : '—',
                  'hPa',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(
    IconData icon,
    String value,
    String label,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white60,
          size: 19,
        ),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================================
  // NAJBLIŽŠIE HODINY
  // ==========================================================

  Widget _buildHourly() {
    final times = meteoData!.hourlyTimes;
    final temps = meteoData!.hourlyTemperature;
    final probs =
        meteoData!.hourlyPrecipitationProbability;
    final codes =
        meteoData!.hourlyPrecipitation;

    if (times == null ||
        temps == null ||
        probs == null ||
        times.isEmpty) {
      return const SizedBox.shrink();
    }

    final count = [
      times.length,
      temps.length,
      probs.length,
    ].reduce(
      (a, b) => a < b ? a : b,
    );

    final visible =
        count > 8 ? 8 : count;

    return _section(
      title: 'NAJBLIŽŠIE HODINY',
      child: SizedBox(
        height: 130,
        child: ListView.separated(
          scrollDirection:
              Axis.horizontal,
          itemCount: visible,
          separatorBuilder: (_, __) =>
              const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final precipitation =
                codes != null &&
                        codes.length > index
                    ? codes[index]
                    : 0.0;

            final probability =
                probs[index];

            final icon =
                _weatherIconFromRain(
              probability,
              precipitation,
            );

            return Container(
              width: 76,
              padding:
                  const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 5,
              ),
              decoration: BoxDecoration(
                color:
                    const Color(0xFF111C31),
                borderRadius:
                    BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white10,
                ),
              ),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(
                    _time(times[index]),
                    style:
                        const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Icon(
                    icon,
                    color:
                        probability >= 50
                            ? Colors.lightBlueAccent
                            : Colors.amber,
                    size: 25,
                  ),

                  const SizedBox(height: 6),

                  Text(
                    '${temps[index].round()}°',
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    '$probability %',
                    style:
                        const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _weatherIconFromRain(
    int probability,
    double precipitation,
  ) {
    if (precipitation >= 10) {
      return Icons.thunderstorm_rounded;
    }

    if (precipitation >= 0.5 ||
        probability >= 60) {
      return Icons.water_drop_rounded;
    }

    if (probability >= 30) {
      return Icons.cloud_rounded;
    }

    return Icons.wb_sunny_rounded;
  }

  // ==========================================================
  // DNES
  // ==========================================================

  Widget _buildToday() {
    final data = meteoData!;

    if (data.dailyTimes == null ||
        data.dailyTimes!.isEmpty ||
        data.dailyTemperatureMax == null ||
        data.dailyTemperatureMin == null) {
      return const SizedBox.shrink();
    }

    final max =
        data.dailyTemperatureMax!.first;
    final min =
        data.dailyTemperatureMin!.first;

    final code =
        data.dailyWeatherCode != null &&
                data.dailyWeatherCode!.isNotEmpty
            ? data.dailyWeatherCode!.first
            : data.currentWeatherCode;

    final sunrise =
        data.dailySunrise != null &&
                data.dailySunrise!.isNotEmpty
            ? _time(data.dailySunrise!.first)
            : '—';

    final sunset =
        data.dailySunset != null &&
                data.dailySunset!.isNotEmpty
            ? _time(data.dailySunset!.first)
            : '—';

    return _section(
      title: 'DNES',
      child: Container(
        padding:
            const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              const Color(0xFF111C31),
          borderRadius:
              BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              _weatherIcon(code),
              color: Colors.amber,
              size: 46,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    _weatherText(code),
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Maximum ${max.round()}°  •  Minimum ${min.round()}°',
                    style:
                        const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  '☀️ $sunrise',
                  style:
                      const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '🌙 $sunset',
                  style:
                      const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // ĎALŠIE DNI
  // ==========================================================

  Widget _buildDays() {
    final data = meteoData!;

    if (data.dailyTimes == null ||
        data.dailyTemperatureMax == null ||
        data.dailyTemperatureMin == null ||
        data.dailyWeatherCode == null) {
      return const SizedBox.shrink();
    }

    final count = [
      data.dailyTimes!.length,
      data.dailyTemperatureMax!.length,
      data.dailyTemperatureMin!.length,
      data.dailyWeatherCode!.length,
    ].reduce(
      (a, b) => a < b ? a : b,
    );

    final visible =
        count > 5 ? 5 : count;

    return _section(
      title: 'ĎALŠIE DNI',
      child: Column(
        children: List.generate(
          visible,
          (index) {
            final code =
                data.dailyWeatherCode![index];

            return Container(
              margin:
                  const EdgeInsets.only(
                bottom: 7,
              ),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color:
                    const Color(0xFF111C31),
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 55,
                    child: Text(
                      _dayName(
                        data.dailyTimes![index],
                        index,
                      ),
                      style:
                          const TextStyle(
                        color: Colors.white70,
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  Icon(
                    _weatherIcon(code),
                    color:
                        code >= 51
                            ? Colors.lightBlueAccent
                            : Colors.amber,
                    size: 22,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      _weatherText(code),
                      style:
                          const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  Text(
                    '${data.dailyTemperatureMax![index].round()}°',
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(width: 8),

                  Text(
                    '${data.dailyTemperatureMin![index].round()}°',
                    style:
                        const TextStyle(
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================================
  // NAJBLIŽŠÍ DÁŽĎ
  // ==========================================================

  Widget _buildRainAlert() {
    final data = meteoData!;

    final probs =
        data.hourlyPrecipitationProbability;

    final times = data.hourlyTimes;

    if (probs == null ||
        times == null ||
        probs.isEmpty) {
      return const SizedBox.shrink();
    }

    int? index;

    for (int i = 0; i < probs.length; i++) {
      if (probs[i] >= 40) {
        index = i;
        break;
      }
    }

    if (index == null) {
      return Container(
        padding:
            const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color:
              const Color(0xFF102A22),
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color: Colors.greenAccent
                .withOpacity(0.15),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Colors.greenAccent,
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Najbližšie hodiny vyzerajú pokojne. Výraznejšie zrážky sa momentálne neočakávajú.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding:
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color:
            const Color(0xFF10283A),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.lightBlueAccent
              .withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.water_drop_rounded,
            color: Colors.lightBlueAccent,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Najvyššia pravdepodobnosť zrážok je zatiaľ okolo ${_time(times[index])} (${probs[index]} %).',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SEKCIA
  // ==========================================================

  Widget _section({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 9),
        child,
      ],
    );
  }

  // ==========================================================
  // WINDY BANNER
  // ==========================================================

  Widget _buildWindyBanner() {
    return InkWell(
      borderRadius:
          BorderRadius.circular(20),
      onTap: onOpenMap,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0F4C81),
              Color(0xFF12355B),
            ],
          ),
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius:
                    BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.air_rounded,
                color: Colors.white,
                size: 27,
              ),
            ),

            const SizedBox(width: 14),

            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'MAPA POČASIA',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight:
                          FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Radar, vietor a zrážky',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 17,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    if (isLoading && meteoData == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.blueAccent,
        ),
      );
    }

    if (meteoData == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Colors.white38,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Počasie sa nepodarilo načítať.',
              style: TextStyle(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed:
                  isLoading ? null : onRefresh,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Skúsiť znova',
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics:
          const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildCurrentWeather(),

          const SizedBox(height: 18),

          _buildRainAlert(),

          const SizedBox(height: 20),

          _buildToday(),

          const SizedBox(height: 20),

          _buildHourly(),

          const SizedBox(height: 20),

          _buildDays(),

          const SizedBox(height: 20),

          _buildWindyBanner(),

          const SizedBox(height: 10),

          if (isLoading)
            const LinearProgressIndicator(
              minHeight: 2,
              color: Colors.blueAccent,
            ),
        ],
      ),
    );
  }
}
