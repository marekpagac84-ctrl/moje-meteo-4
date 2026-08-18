import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapContainer extends StatelessWidget {
  final LatLng userLocation;
  final bool showRadarOverlay;
  final double timeOffsetHours;
  final List<int> radarTimestamps;
  final Function(LatLng) onLocationSelected;

  const MapContainer({
    super.key,
    required this.userLocation,
    required this.showRadarOverlay,
    required this.timeOffsetHours,
    required this.radarTimestamps,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    int timestamp = 0;
    if (radarTimestamps.isNotEmpty) {
      int index = timeOffsetHours.round();
      if (index >= radarTimestamps.length) {
        index = radarTimestamps.length - 1;
      }
      timestamp = radarTimestamps[index];
    }

    return SizedBox(
      height: 380,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: userLocation,
                initialZoom: 9.5,
                maxZoom: 12.0,
                minZoom: 3.0,
                onTap: (tapPosition, point) {
                  onLocationSelected(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'sk.meteoapp.app',
                ),
                if (showRadarOverlay && timestamp > 0)
                  Opacity(
                    opacity: 0.75,
                    child: TileLayer(
                      key: ValueKey(timestamp),
                      urlTemplate:
                          'https://tilecache.rainviewer.com/v2/radar/$timestamp/256/{z}/{x}/{y}/2/1_1.png',
                      userAgentPackageName: 'sk.meteoapp.app',
                    ),
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userLocation,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.redAccent,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      showRadarOverlay ? Icons.thunderstorm : Icons.map,
                      color:
                          showRadarOverlay ? Colors.cyanAccent : Colors.white54,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      showRadarOverlay ? 'Radar & Zrážky' : 'Mapa',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
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
