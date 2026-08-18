import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapContainer extends StatelessWidget {
  final LatLng userLocation;
  final bool showRadarOverlay;
  final Function(LatLng) onLocationSelected;
  final String? currentTilePath;

  const MapContainer({
    super.key,
    required this.userLocation,
    required this.showRadarOverlay,
    required this.onLocationSelected,
    this.currentTilePath,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 380,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: userLocation,
                initialZoom: 7.0,
                maxZoom: 10.0, // Zamedzí chybe "Zoom not supported" od RainViewer
                minZoom: 3.0,
                onTap: (tapPosition, point) {
                  onLocationSelected(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.meteo_app',
                ),
                if (showRadarOverlay && currentTilePath != null)
                  TileLayer(
                    urlTemplate: 'https://tilecache.rainviewer.com$currentTilePath/256/{z}/{x}/{y}/2/1_1.png',
                    userAgentPackageName: 'com.example.meteo_app',
                    tileBuilder: (context, child, tile) => Opacity(opacity: 0.65, child: child),
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
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      showRadarOverlay ? Icons.cloud_sync : Icons.cloud_off,
                      color: showRadarOverlay ? Colors.lightBlueAccent : Colors.white54,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      showRadarOverlay ? 'Radar aktívny' : 'Radar vypnutý',
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
