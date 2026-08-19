class MeteoApiData {
  final double currentTemp;
  final double currentPressure;
  final double windSpeed;
  final double? windDirection;
  final List<int> hourlyPrecipitationProb;

  MeteoApiData({
    required this.currentTemp,
    required this.currentPressure,
    required this.windSpeed,
    this.windDirection,
    required this.hourlyPrecipitationProb,
  });

  factory MeteoApiData.fromJson(Map<String, dynamic> json) {
    // Načítanie hodinových pravdepodobností zrážok
    List<int> probList = [];
    if (json.containsKey('hourly') && json['hourly'].containsKey('precipitation_probability')) {
      final rawList = json['hourly']['precipitation_probability'] as List<dynamic>;
      probList = rawList.map((e) => (e as num).toInt()).toList();
    }

    // Načítanie smeru vetra
    double? windDir;
    if (json.containsKey('hourly') && json['hourly'].containsKey('winddirection_10m')) {
      final rawDir = json['hourly']['winddirection_10m'] as List<dynamic>;
      if (rawDir.isNotEmpty) {
        windDir = (rawDir.first as num).toDouble();
      }
    } else if (json.containsKey('current_weather') && json['current_weather'].containsKey('winddirection')) {
      windDir = (json['current_weather']['winddirection'] as num).toDouble();
    }

    final currentWeather = json['current_weather'] ?? {};

    return MeteoApiData(
      currentTemp: (currentWeather['temperature'] as num?)?.toDouble() ?? 0.0,
      currentPressure: (currentWeather['pressure'] as num?)?.toDouble() ?? 1013.25,
      windSpeed: (currentWeather['windspeed'] as num?)?.toDouble() ?? 0.0,
      windDirection: windDir,
      hourlyPrecipitationProb: probList,
    );
  }
}

class PressurePoint {
  final DateTime timestamp;
  final double pressure;

  PressurePoint({
    required this.timestamp,
    required this.pressure,
  });
}

class BarometerState {
  final double currentPressure;
  final double pressureChangeRate;
  final bool isMovingVertically;
  final List<PressurePoint> pressureHistory;
  final double estimatedAltitude;
  final double basePressure;

  BarometerState({
    required this.currentPressure,
    required this.pressureChangeRate,
    required this.isMovingVertically,
    required this.pressureHistory,
    required this.estimatedAltitude,
    required this.basePressure,
  });

  BarometerState copyWith({
    double? currentPressure,
    double? pressureChangeRate,
    bool? isMovingVertically,
    List<PressurePoint>? pressureHistory,
    double? estimatedAltitude,
    double? basePressure,
  }) {
    return BarometerState(
      currentPressure: currentPressure ?? this.currentPressure,
      pressureChangeRate: pressureChangeRate ?? this.pressureChangeRate,
      isMovingVertically: isMovingVertically ?? this.isMovingVertically,
      pressureHistory: pressureHistory ?? this.pressureHistory,
      estimatedAltitude: estimatedAltitude ?? this.estimatedAltitude,
      basePressure: basePressure ?? this.basePressure,
    );
  }
}
