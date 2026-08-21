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
    if (degrees >= 22.5 && degrees < 67.5) return 'zo Severovýchodu (NE)';
    if (degrees >= 67.5 && degrees < 112.5) return 'z Východu (E)';
    if (degrees >= 112.5 && degrees < 157.5) return 'z Juhovýchodu (SE)';
    if (degrees >= 157.5 && degrees < 202.5) return 'z Juhu (S)';
    if (degrees >= 202.5 && degrees < 247.5) return 'z Juhozápadu (SW)';
    if (degrees >= 247.5 && degrees < 292.5) return 'zo Západu (W)';
    if (degrees >= 292.5 && degrees < 337.5) return 'zo Severozápadu (NW)';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    String statusTitle = "Čistá obloha bez zrážok";
    String detailsText = "V najbližších hodinách sa nečaká žiadny dážď.";
    String extraText = "";
    double? windDegrees;
    bool hasRain = false;
    IconData icon = Icons.wb_sunny_rounded;
    Color iconColor = Colors.amber;

    // Logika výpočtu zrážok z meteo dát
    if (meteoData != null && meteoData!.hourlyPrecipitationProbability != null) {
      for (int i = 0; i < meteoData!.hourlyPrecipitationProbability!.length; i++) {
        final prob = meteoData!.hourlyPrecipitationProbability![i];
        final precip = meteoData!.hourlyPrecipitation != null &&
                meteoData!.hourlyPrecipitation!.length > i
            ? meteoData!.hourlyPrecipitation![i]
            : 0.0;

        if (prob > 20 || precip > 0.05) {
          final timeStr = meteoData!.hourlyTimes?[i] ?? '';
          final timeFormatted =
              timeStr.contains('T') ? timeStr.split('T')[1] : timeStr;

          windDegrees = meteoData!.hourlyWindDirection != null &&
                  meteoData!.hourlyWindDirection!.length > i
              ? meteoData!.hourlyWindDirection![i]
              : 0.0;

          hasRain = true;

          // Dynamický text a ikona podľa intenzity
          if (precip >= 10.0) {
            statusTitle = "Pozor, o $timeFormatted h sa blíži prietrž mračien!";
            icon = Icons.thunderstorm_rounded;
            iconColor = Colors.redAccent;
          } else if (precip >= 3.0) {
            statusTitle = "O $timeFormatted h sa očakáva silný lejak!";
            icon = Icons.grain_rounded;
            iconColor = Colors.orangeAccent;
          } else if (precip >= 0.8) {
            statusTitle = "O $timeFormatted h príde bežný dážď.";
            icon = Icons.umbrella_rounded;
            iconColor = Colors.lightBlueAccent;
          } else {
            statusTitle = "O $timeFormatted h sa objaví jemné mrholenie.";
            icon = Icons.water_drop_rounded;
            iconColor = Colors.cyanAccent;
          }

          detailsText =
              "Intenzita: ${precip.toStringAsFixed(1)} mm/h • Pravdepodobnosť: $prob%";
          extraText = "Smer vetra: ${_getDirectionName(windDegrees)}";
          break;
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Horná lišta karty: Nadpis + Tlačidlo Obnoviť
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "PREDPOVEĎ ZRÁŽOK",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blueAccent,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color: Colors.blueAccent,
                      ),
                onPressed: isLoading ? null : onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stredná časť: Ikona a hlavný popis
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasRain && windDegrees != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Transform.rotate(
                    angle: (windDegrees * 3.1415926535897932 / 180),
                    child: Icon(Icons.navigation_rounded, size: 28, color: iconColor),
                  ),
                )
              else
                Icon(icon, size: 38, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detailsText,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    if (extraText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        extraText,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Spodné tlačidlo na otvorenie veľkej mapy
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpenMap,
              icon: const Icon(Icons.map_rounded, size: 18),
              label: const Text("Zobraziť veľkú radarovú mapu"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
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
