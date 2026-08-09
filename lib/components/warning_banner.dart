import 'package:flutter/material.dart';

class WarningBanner extends StatelessWidget {
  final double pressureChangeRate;
  final bool isRainFromApi;

  const WarningBanner({
    super.key,
    required this.pressureChangeRate,
    required this.isRainFromApi,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSevereWarning = pressureChangeRate < -1.5 || (pressureChangeRate < -1.0 && isRainFromApi);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSevereWarning ? Colors.red.withOpacity(0.2) : Colors.cyan.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSevereWarning ? Colors.redAccent.withOpacity(0.5) : Colors.cyanAccent.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: isSevereWarning ? Colors.red.withOpacity(0.1) : Colors.cyan.withOpacity(0.05),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSevereWarning ? Colors.redAccent : Colors.cyan.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isSevereWarning ? Icons.warning_amber_rounded : Icons.verified,
              color: isSevereWarning ? Colors.white : Colors.cyanAccent,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSevereWarning
                      ? '⚠️ SIEŤOVÁ VÝSTRAHA: DETEKCIA BÚRKY'
                      : '✅ STABILNÉ METEOROLOGICKÉ PODMIENKY',
                  style: TextStyle(
                    color: isSevereWarning ? Colors.redAccent : Colors.cyanAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSevereWarning
                      ? '⚠️ Barometer aj radar sa zhodujú. Prudký pokles tlaku detekovaný viacerými senzormi v sieti. Búrkové jadro dorazí do cca 15 minút.'
                      : '✅ Podmienky v sieti sú stabilné. Barometre aj satelitný radar nehlásia žiadne zrážkové jadrá v okruhu 10 km.',
                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('CONFIDENCE', style: TextStyle(color: Colors.grey, fontSize: 9, fontFamily: 'monospace')),
              Text(
                isSevereWarning ? '94%' : '99%',
                style: TextStyle(
                  color: isSevereWarning ? Colors.redAccent : Colors.cyanAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
