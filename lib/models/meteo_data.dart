import 'package:flutter/material.dart';

class MeteoApiData {
  final double currentTemp;
  final double currentPressure;
  final List<double> hourlyClouds;
  final List<double> hourlyPrecipProb;
  final List<int> hourlyWeatherCodes;

  MeteoApiData({
    required this.currentTemp,
    required this.currentPressure,
    required this.hourlyClouds,
    required this.hourlyPrecipProb,
    required this.hourlyWeatherCodes,
  });

  factory MeteoApiData.fromJson(Map<String, dynamic> json) {
    final current = json['current_weather'] ?? {};
    final hourly = json['hourly'] ?? {};

    List<double> clouds = [];
    if (hourly.containsKey('cloud_cover')) {
      clouds = (hourly['cloud_cover'] as List).map((e) => (e as num).toDouble()).toList();
    }

    List<double> precip = [];
    if (hourly.containsKey('precipitation_probability')) {
      precip = (hourly['precipitation_probability'] as List).map((e) => (e as num).toDouble()).toList();
    }

    List<int> codes = [];
    if (hourly.containsKey('weathercode')) {
      codes = (hourly['weathercode'] as List).map((e) => (e as num).toInt()).toList();
    }

    return MeteoApiData(
      currentTemp: (current['temperature'] as num?)?.toDouble() ?? 0.0,
      currentPressure: (current['pressure'] as num?)?.toDouble() ?? 1013.25,
      hourlyClouds: clouds,
      hourlyPrecipProb: precip,
      hourlyWeatherCodes: codes,
    );
  }
}

class BarometerState {
  final double currentPressure;
  final double pressureChangeRate;
  final bool isMovingVertically;
  final List<double> pressureHistory;
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
    List<double>? pressureHistory,
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
  final String title;
  final double lat;
  final double lng;

  CommunityMarker({
    required this.title,
    required this.lat,
    required this.lng,
  });
}
