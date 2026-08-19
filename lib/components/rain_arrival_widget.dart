import 'package:flutter/material.dart';
import '../models/meteo_data.dart';

class RainArrivalWidget extends StatelessWidget {
  final MeteoApiData? meteoData;
  final bool isLoading;

  const RainArrivalWidget({
    super.key,
    required this.meteoData,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      );
    }

    String rainInfo = "Bez zrážok v najbližších hodinách";
    IconData icon = Icons.wb_sunny;
    Color iconColor = Colors.amber;

    if (meteoData != null && meteoData!.rainArrivalMinutes != null) {
      final mins = meteoData!.rainArrivalMinutes!;
      if (mins == 0) {
        rainInfo = "Práve prší alebo začína pršať!";
        icon = Icons.umbrella;
        iconColor = Colors.lightBlue;
      } else if (mins > 0) {
        final hours = mins ~/ 60;
        final remMins = mins % 60;
        if (hours > 0) {
          rainInfo = "Dážď sa očakáva o cca $hours h $remMins min";
        } else {
          rainInfo = "Dážď sa očakáva o cca $remMins minút";
        }
        icon = Icons.cloud_rain;
        iconColor = Colors.lightBlueAccent;
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
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Predpoveď zrážok",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  rainInfo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
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
}
