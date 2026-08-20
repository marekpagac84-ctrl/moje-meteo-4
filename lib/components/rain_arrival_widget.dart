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

  String _formatRainTime(int totalMinutes) {
    if (totalMinutes == 0) {
      return "Práve prší alebo začína pršať!";
    }

    final hours = totalMinutes ~/ 60;
    final remMins = totalMinutes % 60;

    String hoursText = '';
    if (hours > 0) {
      if (hours == 1) {
        hoursText = "1 hod";
      } else if (hours >= 2 && hours <= 4) {
        hoursText = "$hours hodiny";
      } else {
        hoursText = "$hours hodín";
      }
    }

    String minsText = '';
    if (remMins > 0 || hours == 0) {
      if (remMins == 1) {
        minsText = "1 minútu";
      } else if (remMins >= 2 && remMins <= 4) {
        minsText = "$remMins minúty";
      } else {
        minsText = "$remMins minút";
      }
    }

    final timeString = [
      if (hoursText.isNotEmpty) hoursText,
      if (minsText.isNotEmpty) minsText,
    ].join(' ');

    return "Dážď sa očakáva o cca $timeString";
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        width: double.infinity,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Colors.blueAccent,
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }

    String rainInfo = "Bez zrážok v najbližších hodinách";
    IconData icon = Icons.wb_sunny;
    Color iconColor = Colors.amber;

    if (meteoData?.rainArrivalMinutes != null) {
      final mins = meteoData!.rainArrivalMinutes!;
      rainInfo = _formatRainTime(mins);

      if (mins == 0) {
        icon = Icons.umbrella;
        iconColor = Colors.lightBlue;
      } else if (mins > 0) {
        icon = Icons.grain;
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
