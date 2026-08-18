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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Senzory zariadenia',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white54),
                onPressed: onResetSensors,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('Tlak', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(
                    '${barometer.currentPressure.toStringAsFixed(1)} hPa',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                children: [
                  const Text('Pohyb', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Icon(
                    barometer.isMovingVertically ? Icons.directions_run : Icons.accessibility_new,
                    color: barometer.isMovingVertically ? Colors.greenAccent : Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
