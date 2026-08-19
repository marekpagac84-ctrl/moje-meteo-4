import '../models/meteo_data.dart';

class MeteoService {
  static const List<PresetLocation> presetLocations = [
    PresetLocation(name: 'Nové Mesto nad Váhom', lat: 48.7576, lng: 17.8309),
    PresetLocation(name: 'Bratislava', lat: 48.1486, lng: 17.1077),
    PresetLocation(name: 'Trenčín', lat: 48.8945, lng: 18.0400),
    PresetLocation(name: 'Žilina', lat: 49.2231, lng: 18.7394),
    PresetLocation(name: 'Košice', lat: 48.7164, lng: 21.2611),
    PresetLocation(name: 'Banská Bystrica', lat: 48.7363, lng: 19.1460),
  ];

  static List<CommunityMarker> getSimpleCommunityMarkers(double userLat, double userLng) {
    return [
      CommunityMarker(title: 'Búrkový mrak v diaľke', lat: userLat + 0.02, lng: userLng + 0.02),
      CommunityMarker(title: 'Silný vietor', lat: userLat - 0.01, lng: userLng - 0.01),
    ];
  }
}
