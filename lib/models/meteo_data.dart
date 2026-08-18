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
