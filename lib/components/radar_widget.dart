import 'package:flutter/material.dart';
import '../models/meteo_data.dart';

class RadarWidget extends StatelessWidget {
  final MeteoApiData? meteoData;
  final bool loading;
  final VoidCallback onRefresh;

  const RadarWidget({
    super.key,
    required this.meteoData,
    required this.loading,
    required this.onRefresh,
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Prehľad zrážok',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white54),
                onPressed: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const CircularProgressIndicator()
          else if (meteoData != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Teplota', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text(
                      '${meteoData!.currentTemp.toStringAsFixed(1)} °C',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('Tlak vzduchu', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text(
                      '${meteoData!.currentPressure.toStringAsFixed(1)} hPa',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            )
          else
            const Text('Žiadne dáta', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
