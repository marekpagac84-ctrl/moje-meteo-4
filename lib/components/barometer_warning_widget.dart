import 'package:flutter/material.dart';
import '../models/meteo_data.dart';

class BarometerWarningWidget extends StatelessWidget {
  final BarometerState barometer;

  const BarometerWarningWidget({
    super.key,
    required this.barometer,
  });

  @override
  Widget build(BuildContext context) {
    final history = barometer.pressureHistory;
    
    double pressureDrop = 0.0;
    if (history.length >= 2) {
      pressureDrop = history.first.pressure - history.last.pressure;
    }

    final bool isCriticalDrop = pressureDrop >= 1.5;
    final bool isWarningDrop = pressureDrop >= 0.8 && pressureDrop < 1.5;

    if (!isCriticalDrop && !isWarningDrop) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            const Icon(Icons.sensors, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Barometer aktívny: Tlak je stabilný (${barometer.currentPressure.toStringAsFixed(1)} hPa)",
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final Color statusColor = isCriticalDrop ? Colors.redAccent : Colors.orangeAccent;
    final String titleText = isCriticalDrop
        ? "VAROVANIE: Náhly pokles tlaku!"
        : "UPOZORNENIE: Tlak klesá";
    
    final String descText = isCriticalDrop
        ? "Lokalizovaný pokles o ${pressureDrop.toStringAsFixed(1)} hPa. V tvojom bezprostrednom okolí je vysoká pravdepodobnosť búrky alebo nárazového vetra!"
        : "Zachytený pokles o ${pressureDrop.toStringAsFixed(1)} hPa. Atmosféra sa začína destabilizovať.";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCriticalDrop ? Icons.warning_amber_rounded : Icons.info_outline,
            color: statusColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descText,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
