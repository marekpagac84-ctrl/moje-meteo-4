class BarometerState {
  final double currentPressure;
  final double pressureChangeRate;
  final bool isMovingVertically;
  final List<double> pressureHistory;

  BarometerState({
    required this.currentPressure,
    required this.pressureChangeRate,
    required this.isMovingVertically,
    required this.pressureHistory,
  });

  BarometerState copyWith({
    double? currentPressure,
    double? pressureChangeRate,
    bool? isMovingVertically,
    List<double>? pressureHistory,
  }) {
    return BarometerState(
      currentPressure: currentPressure ?? this.currentPressure,
      pressureChangeRate: pressureChangeRate ?? this.pressureChangeRate,
      isMovingVertically: isMovingVertically ?? this.isMovingVertically,
      pressureHistory: pressureHistory ?? List.from(this.pressureHistory),
    );
  }
}

class MeteoApiData {
  final double temperature;
  final double precipitation;
  final double windSpeed;
  final int weatherCode;
  final bool isRain;
  final String lastUpdated;
  final String statusMessage;

  MeteoApiData({
    required this.temperature,
    required this.precipitation,
    required this.windSpeed,
    required this.weatherCode,
    required this.isRain,
    required this.lastUpdated,
    required this.statusMessage,
  });
}

class PresetLocation {
  final String name;
  final double lat;
  final double lng;

  const PresetLocation({
    required this.name,
    required this.lat,
    required this.lng,
  });
}

class CommunityMarker {
  final String id;
  final double latitude;
  final double longitude;
  final double pressureDrop;
  final String timestamp;
  final String label;

  CommunityMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.pressureDrop,
    required this.timestamp,
    required this.label,
  });
}
