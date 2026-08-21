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
  final List<String>? hourlyTimes;
  final List<int>? hourlyPrecipitationProbability;
  final List<double>? hourlyPrecipitation;
  final List<double>? hourlyWindDirection;

  MeteoApiData({
    required this.currentPressure,
    this.rainArrivalMinutes,
    this.hourlyTimes,
    this.hourlyPrecipitationProbability,
    this.hourlyPrecipitation,
    this.hourlyWindDirection,
  });

  factory MeteoApiData.fromJson(Map<String, dynamic> json) {
    double pressure = 0.0;
    int? rainArrival;
    List<String>? times;
    List<int>? probs;
    List<double>? precips;
    List<double>? windDirs;

    if (json.containsKey('hourly')) {
      final hourly = json['hourly'];

      if (hourly['surface_pressure'] != null && (hourly['surface_pressure'] as List).isNotEmpty) {
        pressure = (hourly['surface_pressure'][0] as num).toDouble();
      }

      if (hourly['time'] != null) {
        times = (hourly['time'] as List).cast<String>();
      }

      if (hourly['precipitation_probability'] != null) {
        probs = (hourly['precipitation_probability'] as List).cast<int>();

        for (int i = 0; i < probs.length; i++) {
          if (probs[i] > 30) {
            rainArrival = i * 60;
            break;
          }
        }
      }

      if (hourly['precipitation'] != null) {
        precips = (hourly['precipitation'] as List).map((e) => (e as num).toDouble()).toList();
      }

      if (hourly['wind_direction_10m'] != null) {
        windDirs = (hourly['wind_direction_10m'] as List).map((e) => (e as num).toDouble()).toList();
      }
    }

    return MeteoApiData(
      currentPressure: pressure,
      rainArrivalMinutes: rainArrival,
      hourlyTimes: times,
      hourlyPrecipitationProbability: probs,
      hourlyPrecipitation: precips,
      hourlyWindDirection: windDirs,
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
