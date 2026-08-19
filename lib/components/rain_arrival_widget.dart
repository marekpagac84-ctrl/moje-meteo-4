import 'package:flutter/material.dart';
import '../models/meteo_data.dart';

class RainArrivalWidget extends StatelessWidget {
  final MeteoApiData? meteoData;
  final bool loading;

  const RainArrivalWidget({
    super.key,
    required this.meteoData,
    required this.loading,
  });

  String _getWindDirectionName(double? degree) {
    if (degree == null) return "neznámeho smeru";
    if (degree >= 337.5 || degree < 22.5) return "severu (N)";
    if (degree >= 22.5 && degree < 67.5) return "severovýchodu / Trenčína (NE)";
    if (degree >= 67.5 && degree < 112.5) return "východu (E)";
    if (degree >= 112.5 && degree < 157.5) return "juhovýchodu (SE)";
    if (degree >= 157.5 && degree < 202.5) return "juhu (S)";
    if (degree >= 202.5 && degree < 247.5) return "juhozápadu (SW)";
    if (degree >= 247.5 && degree < 292.5) return "západu (W)";
    if (degree >= 292.5 && degree < 337.5) return "severozápadu (NW)";
    return "neznámeho smeru";
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );
    }

    if (meteoData == null) {
      return const SizedBox.shrink();
    }

    // Analýza zrážok na najbližších 12 hodín
    int maxProb = 0;
    String arrivalTime = "Žiadny drahší dážď v najbližších hodinách";
    bool willRain = false;

    if (meteoData!.hourlyPrecipitationProb.isNotEmpty) {
      for (int i = 0; i < meteoData!.hourlyPrecipitationProb.length; i++) {
        int prob = meteoData!.hourlyPrecipitationProb[i];
        if (prob > maxProb) {
          maxProb = prob;
        }
        if (prob >= 30 && !willRain) {
          willRain = true;
          final now = DateTime.now().add(Duration(hours: i));
          arrivalTime = "${now.hour.toString().padLeft(2, '0')}:00";
        }
      }
    }

    final windDirName = _getWindDirectionName(meteoData!.windDirection);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: willRain ? Colors.blueAccent.withOpacity(0.5) : Colors.white10,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                willRain ? Icons.umbrella : Icons.wb_sunny,
                color: willRain ? Colors.lightBlueAccent : Colors.amber,
                size: 24,
              ),
              const SizedBox(width: 10),
              const Text(
                "Sledovanie zrážkového frontu",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (willRain) ...[
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                children: [
                  const TextSpan(text: "Dážď sa očakáva od "),
                  TextSpan(
                    text: windDirName,
                    style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: " okolo "),
                  TextSpan(
                    text: arrivalTime,
                    style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: " s pravdepodobnosťou "),
                  TextSpan(
                    text: "$maxProb %",
                    style: TextStyle(
                      color: maxProb > 70 ? Colors.redAccent : Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(text: "."),
                ],
              ),
            ),
          ] else ...[
            Text(
              "V najbližších hodinách sa nepredpokladajú výrazné zrážky. Prúdenie vzduchu smeruje od $windDirName.",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}
