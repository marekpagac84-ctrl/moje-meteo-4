import 'package:flutter/material.dart';
import '../models/meteo_data.dart';

class HeaderBar extends StatelessWidget {
  final String currentLocationName;
  final Function(LocationPreset) onSelectPreset;
  final VoidCallback onUseGps;
  final bool showRadarOverlay;
  final VoidCallback onToggleRadar;

  static const List<LocationPreset> presets = [
    LocationPreset(name: 'Nové Mesto nad Váhom', lat: 48.7576, lng: 17.8309),
    LocationPreset(name: 'Bratislava', lat: 48.1486, lng: 17.1077),
    LocationPreset(name: 'Žilina', lat: 49.2231, lng: 18.7394),
    LocationPreset(name: 'Košice', lat: 48.7164, lng: 21.2611),
  ];

  const HeaderBar({
    super.key,
    required this.currentLocationName,
    required this.onSelectPreset,
    required this.onUseGps,
    required this.showRadarOverlay,
    required this.onToggleRadar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              PopupMenuButton<LocationPreset>(
                icon: const Icon(Icons.arrow_drop_down_circle, color: Colors.blueAccent),
                onSelected: onSelectPreset,
                itemBuilder: (context) {
                  return presets.map((preset) {
                    return PopupMenuItem<LocationPreset>(
                      value: preset,
                      child: Text(preset.name),
                    );
                  }).toList();
                },
              ),
              const SizedBox(width: 8),
              Text(
                currentLocationName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.my_location, color: Colors.blueAccent),
                onPressed: onUseGps,
                tooltip: "Moja GPS poloha",
              ),
              IconButton(
                icon: Icon(
                  showRadarOverlay ? Icons.radar : Icons.radar_outlined,
                  color: showRadarOverlay ? Colors.greenAccent : Colors.grey,
                ),
                onPressed: onToggleRadar,
                tooltip: "Radarový overlay",
              ),
            ],
          ),
        ],
      ),
    );
  }
}
