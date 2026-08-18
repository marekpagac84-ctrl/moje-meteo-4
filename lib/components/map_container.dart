import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapContainer extends StatelessWidget {
  final LatLng userLocation;
  final bool showRadarOverlay;
  final Function(LatLng) onLocationSelected;
  final double cloudCoverPercent;

  const MapContainer({
    super.key,
    required this.userLocation,
    required this.showRadarOverlay,
    required this.onLocationSelected,
    this.cloudCoverPercent = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final double cloudOpacity = (cloudCoverPercent / 100.0) * 0.55;

    return SizedBox(
      height: 350,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: userLocation,
                initialZoom: 7.0,
                onTap: (tapPosition, point) {
                  onLocationSelected(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.meteo_app',
                ),
                if (showRadarOverlay)
                  TileLayer(
                    urlTemplate: 'https://tilecache.rainviewer.com/v2/radar/now/256/{z}/{x}/{y}/2/1_1.png',
                    userAgentPackageName: 'com.example.meteo_app',
                    tileBuilder: (context, child, tile) => Opacity(opacity: 0.6, child: child),
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userLocation,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 36),
                    ),
                  ],
                ),
              ],
            ),
            
            // Plynulá vrstva oblačnosti
            if (cloudCoverPercent > 0)
              IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  color: Colors.blueGrey.withOpacity(cloudOpacity),
                ),
              ),

            // Ukazovateľ aktuálnej oblačnosti na mape
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Oblačnosť: ${cloudCoverPercent.round()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
