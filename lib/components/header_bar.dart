import 'package:flutter/material.dart';
import '../models/meteo_data.dart';
import '../services/meteo_service.dart';

class HeaderBar extends StatelessWidget implements PreferredSizeWidget {
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
  Size get preferredSize => const Size.fromHeight(65);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.red, blurRadius: 8, spreadRadius: 1),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'LIVE STORM RADAR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.0,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.slate.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  DropdownButton<String>(
                    value: MeteoService.presetLocations.any((p) => p.name == currentLocationName)
                        ? currentLocationName
                        : MeteoService.presetLocations.first.name,
                    dropdownColor: const Color(0xFF0F172A),
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent, size: 18),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                    onChanged: (val) {
                      if (val != null) {
                        final found = MeteoService.presetLocations.firstWhere((p) => p.name == val);
                        onSelectPreset(found);
                      }
                    },
                    items: MeteoService.presetLocations.map((p) {
                      return DropdownMenuItem<String>(
                        value: p.name,
                        child: Text(p.name),
                      );
                    }).toList(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.cyanAccent, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onUseGps,
                    tooltip: 'Použiť GPS',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onToggleRadar,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: showRadarOverlay ? Colors.cyan.withOpacity(0.2) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: showRadarOverlay ? Colors.cyanAccent : Colors.slate.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.layers,
                      size: 14,
                      color: showRadarOverlay ? Colors.cyanAccent : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'RADAR',
                      style: TextStyle(
                        color: showRadarOverlay ? Colors.cyanAccent : Colors.grey,
                        fontSize: 10,
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
