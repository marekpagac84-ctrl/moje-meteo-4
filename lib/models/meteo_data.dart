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

  factory MeteoApiData.fromJson(Map<String, dynamic> json) {
    final current = json['current_weather'] ?? {};
    final code = (current['weathercode'] as num?)?.toInt() ?? 0;
    final temp = (current['temperature'] as num?)?.toDouble() ?? 0.0;
    final wind = (current['windspeed'] as num?)?.toDouble() ?? 0.0;

    final rainVal = (json['hourly']?['precipitation']?[0] as num?)?.toDouble() ?? 0.0;

    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    return MeteoApiData(
      temperature: temp,
      precipitation: rainVal,
      windSpeed: wind,
      weatherCode: code,
      isRain: rainVal > 0 || [51, 53, 55, 61, 63, 65, 80, 81, 82].contains(code),
      lastUpdated: timeStr,
      statusMessage: _getWeatherDescription(code),
    );
  }

  static String _getWeatherDescription(int code) {
    switch (code) {
      case 0:
        return 'Jasno';
      case 1:
      case 2:
      case 3:
        return 'Čiastočne oblačno';
      case 45:
      case 48:
        return 'Hmla';
      case 51:
      case 53:
      case 55:
        return 'Mrholenie';
      case 61:
      case 63:
      case 65:
        return 'Dážď';
      case 71:
      case 73:
      case 75:
        return 'Sneženie';
      case 80:
      case 81:
      case 82:
        return 'Prehánky';
      case 95:
      case 96:
      case 99:
        return 'Búrka';
      default:
        return 'Neznáme počasie';
    }
  }
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
