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
    final bool isStormWarning = barometer.pressureChangeRate < -1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.slate.withOpacity(0.3)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LOCAL BAROMETER / SENSOR',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 1.0,
                ),
              ),
              Row(
                children: const [
                  Icon(Icons.speed, color: Colors.cyanAccent, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'ONLINE',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          Center(
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0F172A),
                border: Border.all(
                  color: isStormWarning ? Colors.redAccent : Colors.cyanAccent.withOpacity(0.4),
                  width: 6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isStormWarning ? Colors.red.withOpacity(0.3) : Colors.cyan.withOpacity(0.2),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    barometer.currentPressure.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    'hPa',
                    style: TextStyle(
                      color: isStormWarning ? Colors.redAccent : Colors.cyanAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('TREND', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  Text(
                    '${barometer.pressureChangeRate > 0 ? '+' : ''}${barometer.pressureChangeRate.toStringAsFixed(1)} hPa/h',
                    style: TextStyle(
                      color: isStormWarning ? Colors.redAccent : Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  const Text('STATUS', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  Text(
                    isStormWarning ? '⚠️ STORM DROP' : 'Calibrated',
                    style: TextStyle(
                      color: isStormWarning ? Colors.redAccent : Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.slate.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter výšky:',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: barometer.isMovingVertically
                        ? Colors.amber.withOpacity(0.2)
                        : Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: barometer.isMovingVertically ? Colors.amber : Colors.green,
                    ),
                  ),
                  child: Text(
                    barometer.isMovingVertically ? 'Pohyb (Filter ON)' : 'Stacionárny',
                    style: TextStyle(
                      color: barometer.isMovingVertically ? Colors.amber : Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.2),
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onSimulateDrop,
                  icon: const Icon(Icons.flash_on, size: 14),
                  label: const Text('-2.5 hPa', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.withOpacity(0.2),
                    foregroundColor: Colors.amberAccent,
                    side: const BorderSide(color: Colors.amber),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onSimulateMotion,
                  icon: const Icon(Icons.height, size: 14),
                  label: const Text('Pohyb', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  side: BorderSide(color: Colors.slate.withOpacity(0.4)),
                ),
                onPressed: onResetSensors,
                icon: const Icon(Icons.refresh, color: Colors.cyanAccent, size: 16),
                tooltip: 'Reset',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
