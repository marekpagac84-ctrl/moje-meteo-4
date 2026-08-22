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

  String _getDirectionName(double degrees) {
    if (degrees >= 337.5 || degrees < 22.5) return 'zo Severu (N)';
    if (degrees >= 22.5 && degrees < 67.5) {
      return 'zo Severovýchodu (NE)';
    }
    if (degrees >= 67.5 && degrees < 112.5) return 'z Východu (E)';
    if (degrees >= 112.5 && degrees < 157.5) {
      return 'z Juhovýchodu (SE)';
    }
    if (degrees >= 157.5 && degrees < 202.5) return 'z Juhu (S)';
    if (degrees >= 202.5 && degrees < 247.5) {
      return 'z Juhozápadu (SW)';
    }
    if (degrees >= 247.5 && degrees < 292.5) return 'zo Západu (W)';
    if (degrees >= 292.5 && degrees < 337.5) {
      return 'zo Severozápadu (NW)';
    }
    return '';
  }

  // ==========================================================
  // IKONA PODĽA PRAVDEPODOBNOSTI A MNOŽSTVA ZRÁŽOK
  // ==========================================================

  IconData _getWeatherIcon(
    int probability,
    double precipitation,
  ) {
    if (precipitation >= 10) {
      return Icons.thunderstorm_rounded;
    }

    if (precipitation >= 3) {
      return Icons.grain_rounded;
    }

    if (precipitation >= 0.8) {
      return Icons.umbrella_rounded;
    }

    if (probability >= 50) {
      return Icons.cloudy_snowing;
    }

    if (probability >= 20) {
      return Icons.cloud_rounded;
    }

    return Icons.wb_sunny_rounded;
  }

  Color _getWeatherColor(
    int probability,
    double precipitation,
  ) {
    if (precipitation >= 10) {
      return Colors.redAccent;
    }

    if (precipitation >= 3) {
      return Colors.orangeAccent;
    }

    if (precipitation >= 0.8) {
      return Colors.lightBlueAccent;
    }

    if (probability >= 50) {
      return Colors.blueGrey;
    }

    if (probability >= 20) {
      return Colors.white70;
    }

    return Colors.amber;
  }

  // ==========================================================
  // FORMÁTOVANIE ČASU
  // ==========================================================

  String _formatTime(String time) {
    if (time.contains('T')) {
      final parts = time.split('T');

      if (parts.length > 1) {
        final hourMinute = parts[1];

        if (hourMinute.length >= 5) {
          return hourMinute.substring(0, 5);
        }
      }
    }

    return time;
  }

  // ==========================================================
  // TEXT PRE STAV POČASIA
  // ==========================================================

  String _getForecastDescription(
    int probability,
    double precipitation,
  ) {
    if (precipitation >= 10) {
      return 'Silná búrka / prietrž';
    }

    if (precipitation >= 3) {
      return 'Silný dážď';
    }

    if (precipitation >= 0.8) {
      return 'Dážď';
    }

    if (probability >= 50) {
      return 'Možné zrážky';
    }

    if (probability >= 20) {
      return 'Malá šanca zrážok';
    }

    return 'Bez zrážok';
  }

  // ==========================================================
  // HODINOVÁ PREDPOVEĎ
  // ==========================================================

  Widget _buildHourlyForecast() {
    if (meteoData == null ||
        meteoData!.hourlyTimes == null ||
        meteoData!.hourlyPrecipitationProbability == null) {
      return const SizedBox.shrink();
    }

    final times = meteoData!.hourlyTimes!;
    final probabilities =
        meteoData!.hourlyPrecipitationProbability!;
    final precipitations =
        meteoData!.hourlyPrecipitation;

    final int count = [
      times.length,
      probabilities.length,
    ].reduce((a, b) => a < b ? a : b);

    if (count == 0) {
      return const SizedBox.shrink();
    }

    // Zobrazíme maximálne najbližších 8 hodín.
    final int visibleCount =
        count > 8 ? 8 : count;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'PREDPOVEĎ NA NAJBLIŽŠIE HODINY',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),

        const SizedBox(height: 10),

        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visibleCount,
            separatorBuilder: (_, __) =>
                const SizedBox(width: 8),
            itemBuilder: (
              context,
              index,
            ) {
              final int probability =
                  probabilities[index];

              final double precipitation =
                  precipitations != null &&
                          precipitations.length >
                              index
                      ? precipitations[index]
                      : 0.0;

              final IconData icon =
                  _getWeatherIcon(
                probability,
                precipitation,
              );

              final Color iconColor =
                  _getWeatherColor(
                probability,
                precipitation,
              );

              return Container(
                width: 78,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF0F172A),
                  borderRadius:
                      BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white12,
                  ),
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatTime(
                        times[index],
                      ),
                      style:
                          const TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 11,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Icon(
                      icon,
                      size: 23,
                      color: iconColor,
                    ),

                    const SizedBox(height: 5),

                    Text(
                      '$probability %',
                      style:
                          TextStyle(
                        color: iconColor,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      precipitation > 0
                          ? '${precipitation.toStringAsFixed(1)} mm'
                          : '0 mm',
                      style:
                          const TextStyle(
                        color:
                            Colors.white54,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String statusTitle =
        "Čistá obloha bez zrážok";

    String detailsText =
        "V najbližších hodinách sa nečaká žiadny dážď.";

    String extraText = "";

    double? windDegrees;

    bool hasRain = false;

    IconData icon =
        Icons.wb_sunny_rounded;

    Color iconColor =
        Colors.amber;

    // ==========================================================
    // EXISTUJÚCA LOGIKA VÝPOČTU ZRÁŽOK
    // ==========================================================

    if (meteoData != null &&
        meteoData!
                .hourlyPrecipitationProbability !=
            null) {
      for (
        int i = 0;
        i <
            meteoData!
                .hourlyPrecipitationProbability!
                .length;
        i++
      ) {
        final prob =
            meteoData!
                .hourlyPrecipitationProbability![i];

        final precip =
            meteoData!.hourlyPrecipitation !=
                        null &&
                    meteoData!
                            .hourlyPrecipitation!
                            .length >
                        i
                ? meteoData!
                    .hourlyPrecipitation![i]
                : 0.0;

        if (prob > 20 ||
            precip > 0.05) {
          final timeStr =
              meteoData!.hourlyTimes?[i] ??
                  '';

          final timeFormatted =
              timeStr.contains('T')
                  ? timeStr.split('T')[1]
                  : timeStr;

          windDegrees =
              meteoData!
                              .hourlyWindDirection !=
                          null &&
                      meteoData!
                              .hourlyWindDirection!
                              .length >
                          i
                  ? meteoData!
                      .hourlyWindDirection![i]
                  : 0.0;

          hasRain = true;

          // Dynamický text a ikona podľa intenzity
          if (precip >= 10.0) {
            statusTitle =
                "Pozor, o $timeFormatted h sa blíži prietrž mračien!";

            icon =
                Icons.thunderstorm_rounded;

            iconColor =
                Colors.redAccent;
          } else if (precip >= 3.0) {
            statusTitle =
                "O $timeFormatted h sa očakáva silný lejak!";

            icon =
                Icons.grain_rounded;

            iconColor =
                Colors.orangeAccent;
          } else if (precip >= 0.8) {
            statusTitle =
                "O $timeFormatted h príde bežný dážď.";

            icon =
                Icons.umbrella_rounded;

            iconColor =
                Colors.lightBlueAccent;
          } else {
            statusTitle =
                "O $timeFormatted h sa objaví jemné mrholenie.";

            icon =
                Icons.water_drop_rounded;

            iconColor =
                Colors.cyanAccent;
          }

          detailsText =
              "Intenzita: ${precip.toStringAsFixed(1)} mm/h • Pravdepodobnosť: $prob%";

          extraText =
              "Smer vetra: ${_getDirectionName(windDegrees)}";

          break;
        }
      }
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF1E293B),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        mainAxisSize:
            MainAxisSize.min,
        children: [
          // ======================================================
          // HORNÁ LIŠTA
          // ======================================================

          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "PREDPOVEĎ ZRÁŽOK",
                style: TextStyle(
                  color:
                      Colors.white54,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),

              IconButton(
                padding:
                    EdgeInsets.zero,
                constraints:
                    const BoxConstraints(),
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              Colors.blueAccent,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color:
                            Colors.blueAccent,
                      ),
                onPressed:
                    isLoading
                        ? null
                        : onRefresh,
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          // ======================================================
          // HLAVNÁ INFORMÁCIA
          // ======================================================

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              if (hasRain &&
                  windDegrees != null)
                Container(
                  padding:
                      const EdgeInsets.all(
                    10,
                  ),
                  decoration:
                      BoxDecoration(
                    color: iconColor
                        .withOpacity(0.15),
                    shape:
                        BoxShape.circle,
                  ),
                  child:
                      Transform.rotate(
                    angle:
                        (windDegrees *
                            3.1415926535897932 /
                            180),
                    child: Icon(
                      Icons.navigation_rounded,
                      size: 28,
                      color:
                          iconColor,
                    ),
                  ),
                )
              else
                Icon(
                  icon,
                  size: 38,
                  color:
                      iconColor,
                ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      detailsText,
                      style:
                          TextStyle(
                        color: Colors.white
                            .withOpacity(
                          0.8,
                        ),
                        fontSize: 12,
                      ),
                    ),

                    if (extraText
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 2,
                      ),
                      Text(
                        extraText,
                        style:
                            const TextStyle(
                          color:
                              Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          // ======================================================
          // NOVÁ HODINOVÁ PREDPOVEĎ
          // ======================================================

          _buildHourlyForecast(),

          const SizedBox(
            height: 18,
          ),

          // ======================================================
          // MAPA
          // ======================================================

          SizedBox(
            width: double.infinity,
            child:
                ElevatedButton.icon(
              onPressed:
                  onOpenMap,
              icon: const Icon(
                Icons.map_rounded,
                size: 18,
              ),
              label: const Text(
                "Zobraziť veľkú radarovú mapu",
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF2563EB,
                ),
                foregroundColor:
                    Colors.white,
                padding:
                    const EdgeInsets
                        .symmetric(
                  vertical: 10,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
