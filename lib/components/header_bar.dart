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
    PresetLocation? selectedPreset;
    try {
      selectedPreset = MeteoService.presetLocations.firstWhere(
        (p) => p.name == currentLocationName,
      );
    } catch (_) {
      selectedPreset = null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1E293B),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<PresetLocation>(
              value: selectedPreset,
              hint: Text(
                currentLocationName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              dropdownColor: const Color(0xFF1E293B),
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent),
              items: MeteoService.presetLocations.map((PresetLocation p) {
                return DropdownMenuItem<PresetLocation>(
                  value: p,
                  child: Text(p.name, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (PresetLocation? newLoc) {
                if (newLoc != null) {
                  onSelectPreset(newLoc);
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.cyanAccent),
            onPressed: onUseGps,
            tooltip: 'Použiť GPS polohu',
          ),
          IconButton(
            icon: Icon(
              showRadarOverlay ? Icons.radar : Icons.radar_outlined,
              color: showRadarOverlay ? Colors.lightBlueAccent : Colors.white38,
            ),
            onPressed: onToggleRadar,
            tooltip: 'Prepnúť radarový prekryv',
          ),
        ],
      ),
    );
  }
}
