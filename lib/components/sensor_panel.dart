import 'package:flutter/material.dart';
import '../models/meteo_data.dart';

class SensorPanel extends StatelessWidget {
  final BarometerState barometer;
  final VoidCallback onSimulateDrop;
  final VoidCallback onSimulateMotion;
  final VoidCallback onResetSensors;

  const SensorPanel({
    super.key,
    required this.barometer,
    required this.onSimulateDrop,
    required this.onSimulateMotion,
    required this.onResetSensors,
  });

  // Určenie stavu varovania podľa zmeny tlaku za hodinu
  Map<String, dynamic> _getPressureStatus(double changeRate) {
    if (changeRate <= -2.0) {
      return {
        'title': 'Výstraha pred búrkou!',
        'desc': 'Prudký pokles tlaku ($changeRate hPa). Blíži sa búrka alebo silný front.',
        'color': Colors.redAccent,
        'icon': Icons.warning_amber_rounded,
      };
    } else if (changeRate <= -0.8) {
      return {
        'title': 'Mierna zmena počasia',
        'desc': 'Tlak klesá. Zvýšené riziko migrény u meteosenzitívnych ľudí.',
        'color': Colors.orangeAccent,
        'icon': Icons.trending_down,
      };
    } else if (changeRate >= 0.8) {
      return {
        'title': 'Zlepšovanie počasia',
        'desc': 'Tlak stúpa, očakáva sa jasnejšia obloha.',
        'color': Colors.greenAccent,
        'icon': Icons.trending_up,
      };
    } else {
      return {
        'title': 'Stabilný tlak',
        'desc': 'Atmosférický tlak je bez výrazných výkyvov.',
        'color': Colors.blueAccent,
        'icon': Icons.remove,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _getPressureStatus(barometer.pressureChangeRate);

    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(status['icon'] as IconData, color: status['color'] as Color, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      status['title'] as String,
                      style: TextStyle(
                        color: status['color'] as Color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (barometer.isMovingVertically)
                  Chip(
                    avatar: const Icon(Icons.height, size: 16, color: Colors.amber),
                    label: const Text('Detegovaný pohyb', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.amber.withOpacity(0.2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              status['desc'] as String,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const Divider(height: 24, color: Colors.white12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric(
                  'Aktuálny tlak',
                  '${barometer.currentPressure.toStringAsFixed(1)} hPa',
                  Icons.speed,
                ),
                _buildMetric(
                  'Trend',
                  '${barometer.pressureChangeRate > 0 ? "+" : ""}${barometer.pressureChangeRate.toStringAsFixed(1)} hPa/h',
                  Icons.show_chart,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white38),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }
}
