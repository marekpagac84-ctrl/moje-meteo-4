import 'package:flutter/material.dart';
import '../models/meteo_data.dart';
import '../services/meteo_service.dart';

class HeaderBar extends StatelessWidget {
  final String currentLocationName;
  final ValueChanged<PresetLocation> onSelectPreset;
  final VoidCallback onUseGps;
  final bool showRadarOverlay;
  final VoidCallback onToggleRadar;

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E293B),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.redAccent),
              const SizedBox(width: 6),
              DropdownButton<PresetLocation>(
                dropdownColor: const Color(0xFF1E293B),
                underline: const SizedBox(),
                value: MeteoService.presetLocations.any((p) => p.name == currentLocationName)
                    ? MeteoService.presetLocations.firstWhere((p) => p.name == currentLocationName)
                    : null,
                hint: Text(
                  currentLocationName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                items: MeteoService.presetLocations.map((p) {
                  return DropdownMenuItem<PresetLocation>(
                    value: p,
                    child: Text(p.name, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) onSelectPreset(val);
                },
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.my_location, color: Colors.blueAccent),
                onPressed: onUseGps,
                tooltip: 'Použiť GPS',
              ),
              IconButton(
                icon: Icon(
                  showRadarOverlay ? Icons.layers : Icons.layers_clear,
                  color: Colors.amber,
                ),
                onPressed: onToggleRadar,
                tooltip: 'Prepnúť radar',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
