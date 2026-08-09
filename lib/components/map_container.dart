import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/meteo_data.dart';

class MapContainer extends StatelessWidget {
  final LatLng userLocation;
  final List<CommunityMarker> communityMarkers;
  final bool showRadarOverlay;

  const MapContainer({
    super.key,
    required this.userLocation,
    required this.communityMarkers,
    required this.showRadarOverlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: userLocation,
                initialZoom: 11.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.meteoapp',
                ),
                if (showRadarOverlay)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: userLocation,
                        radius: 8000,
                        useRadiusInMeter: true,
                        color: Colors.blue.withOpacity(0.25),
                        borderColor: Colors.cyanAccent.withOpacity(0.6),
                        borderStrokeWidth: 2,
                      ),
                      CircleMarker(
                        point: LatLng(userLocation.latitude + 0.015, userLocation.longitude - 0.02),
                        radius: 5000,
                        useRadiusInMeter: true,
                        color: Colors.red.withOpacity(0.35),
                        borderColor: Colors.redAccent,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userLocation,
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.cyan.withOpacity(0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.cyanAccent, width: 2),
                        ),
                        child: const Icon(Icons.my_location, color: Colors.cyanAccent, size: 24),
                      ),
                    ),
                    ...communityMarkers.map((m) {
                      return Marker(
                        point: LatLng(m.latitude, m.longitude),
                        width: 70,
                        height: 60,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade900,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.redAccent),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.flash_on, color: Colors.amber, size: 12),
                                  Text(
                                    '${m.pressureDrop} hPa',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.location_on, color: Colors.redAccent, size: 22),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueGrey.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.cyanAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('Tvoja poloha', style: TextStyle(color: Colors.white, fontSize: 10)),
                    const SizedBox(width: 12),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('Pokles tlaku', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
