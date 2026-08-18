import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class MapContainer extends StatelessWidget {
  final LatLng userLocation;
  final bool showRadarOverlay;
  final Function(LatLng) onLocationSelected;

  const MapContainer({
    super.key,
    required this.userLocation,
    required this.showRadarOverlay,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final String staticMapUrl =
        'https://staticmap.openstreetmap.de/staticmap.php?center=${userLocation.latitude},${userLocation.longitude}&zoom=10&size=600x380&maptype=mapnik&markers=${userLocation.latitude},${userLocation.longitude},red-pushpin';

    return SizedBox(
      height: 380,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Image.network(
              staticMapUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFF1E293B),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map, color: Colors.white54, size: 48),
                        SizedBox(height: 8),
                        Text('Mapa sa načítava...', style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, color: Colors.redAccent, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Poloha',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
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
