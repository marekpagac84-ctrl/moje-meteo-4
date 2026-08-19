import 'package:flutter/material.dart';

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

class MeteoApiData {
  final double currentPressure;
  final int? rainArrivalMinutes;

  MeteoApiData({
    required this.currentPressure,
    this.rainArrivalMinutes,
  });

  factory MeteoApiData.fromJson(Map<String, dynamic> json) {
    double pressure = 0.0;
    int? rainArrival;

    if (json.containsKey('hourly')) {
      final hourly = json['hourly'];
      if (hourly['surface_pressure'] != null && (hourly['surface_pressure'] as List).isNotEmpty) {
        pressure = (hourly['surface_pressure'][0] as num).toDouble();
      }

      if (hourly['precipitation_probability'] != null) {
        final List probs = hourly['precipitation_probability'];
        for (int i = 0; i < probs.length; i++) {
          if ((probs[i] as num) > 30) {
            rainArrival = i * 60;
            break;
          }
        }
      }
    }

    return MeteoApiData(
      currentPressure: pressure,
      rainArrivalMinutes: rainArrival,
    );
  }
}

class LocationPreset {
  final String name;
  final double lat;
  final double lng;

  const LocationPreset({
    required this.name,
    required this.lat,
    required this.lng,
  });
}
