import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
    return SizedBox(
      height: 350,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: userLocation,
            initialZoom: 6.0,
            onTap: (tapPosition, point) {
              onLocationSelected(point);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            ),
            if (showRadarOverlay)
              TileLayer(
                urlTemplate: 'https://tilecache.rainviewer.com/v2/radar/now/256/{z}/{x}/{y}/2/1_1.png',
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
      ),
    );
  }
}
