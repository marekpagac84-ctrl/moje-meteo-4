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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.cloud_sync, color: Colors.amberAccent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OFFICIAL SATELLITE & RADAR',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        meteoData?.statusMessage ?? "Nápis zrážok...",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  side: BorderSide(color: Colors.slate.withOpacity(0.3)),
                ),
                onPressed: loading ? null : onRefresh,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                      )
                    : const Icon(Icons.refresh, color: Colors.cyanAccent, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              _buildStatCard(
                icon: Icons.air,
                iconColor: Colors.amberAccent,
                label: 'VIETOR',
                value: '${meteoData?.windSpeed.toStringAsFixed(1) ?? "12.0"}',
                unit: 'km/h',
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                icon: Icons.water_drop,
                iconColor: Colors.blueAccent,
                label: 'ZRÁŽKY',
                value: '${meteoData?.precipitation.toStringAsFixed(1) ?? "0.0"}',
                unit: 'mm',
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                icon: Icons.thermostat,
                iconColor: Colors.cyanAccent,
                label: 'TEPLOTA',
                value: '${meteoData?.temperature.toStringAsFixed(1) ?? "18.0"}',
                unit: '°C',
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.radar, color: Colors.cyanAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OPEN-METEO SATELLITE FEED',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        meteoData?.isRain == true
                            ? 'Zrážkové pásmo v dosahu'
                            : 'Bez zrážok v okruhu 50 km',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (meteoData?.lastUpdated != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'SYNC: ${meteoData!.lastUpdated}',
                style: const TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.slate.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 12),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 9, fontFamily: 'monospace'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: iconColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              unit,
              style: const TextStyle(color: Colors.grey, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}
