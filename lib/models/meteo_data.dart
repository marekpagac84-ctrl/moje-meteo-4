// ============================================================
// PRESSURE POINT
// ============================================================

class PressurePoint {
  final DateTime timestamp;
  final double pressure;

  PressurePoint({
    required this.timestamp,
    required this.pressure,
  });
}

// ============================================================
// BAROMETER STATE
// ============================================================

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
      currentPressure:
          currentPressure ?? this.currentPressure,
      pressureChangeRate:
          pressureChangeRate ?? this.pressureChangeRate,
      isMovingVertically:
          isMovingVertically ?? this.isMovingVertically,
      pressureHistory:
          pressureHistory ?? this.pressureHistory,
      estimatedAltitude:
          estimatedAltitude ?? this.estimatedAltitude,
      basePressure:
          basePressure ?? this.basePressure,
    );
  }
}

// ============================================================
// METEO API DATA
// ============================================================

class MeteoApiData {
  // ==========================================================
  // AKTUÁLNE
  // ==========================================================

  final double currentTemperature;
  final double currentWindSpeed;
  final double currentWindDirection;
  final double currentPressure;
  final int currentWeatherCode;

  // ==========================================================
  // HODINOVÁ PREDPOVEĎ
  // ==========================================================

  final List<String>? hourlyTimes;
  final List<double>? hourlyTemperature;
  final List<int>? hourlyWeatherCode;

  final List<int>? hourlyPrecipitationProbability;
  final List<double>? hourlyPrecipitation;

  final List<double>? hourlyWindDirection;
  final List<double>? hourlyWindSpeed;

  final List<double>? hourlyHumidity;
  final List<double>? hourlyPressure;

  // ==========================================================
  // DENNÁ PREDPOVEĎ
  // ==========================================================

  final List<String>? dailyTimes;
  final List<double>? dailyTemperatureMax;
  final List<double>? dailyTemperatureMin;
  final List<int>? dailyWeatherCode;
  final List<String>? dailySunrise;
  final List<String>? dailySunset;

  // ==========================================================
  // ODVOZENÉ INFORMÁCIE
  // ==========================================================

  final int? rainArrivalMinutes;

  MeteoApiData({
    required this.currentTemperature,
    required this.currentWindSpeed,
    required this.currentWindDirection,
    required this.currentPressure,
    required this.currentWeatherCode,

    this.hourlyTimes,
    this.hourlyTemperature,
    this.hourlyWeatherCode,

    this.hourlyPrecipitationProbability,
    this.hourlyPrecipitation,

    this.hourlyWindDirection,
    this.hourlyWindSpeed,

    this.hourlyHumidity,
    this.hourlyPressure,

    this.dailyTimes,
    this.dailyTemperatureMax,
    this.dailyTemperatureMin,
    this.dailyWeatherCode,
    this.dailySunrise,
    this.dailySunset,

    this.rainArrivalMinutes,
  });

  // ==========================================================
  // AKTUÁLNY INDEX V HODINOVEJ PREDPOVEDI
  //
  // Open-Meteo vracia hodinové údaje od začiatku
  // predpovedného radu. Preto nesmieme automaticky
  // zobrazovať index 0.
  // ==========================================================

  int get currentHourlyIndex {
    if (hourlyTimes == null ||
        hourlyTimes!.isEmpty) {
      return 0;
    }

    final now = DateTime.now();

    for (int i = 0; i < hourlyTimes!.length; i++) {
      final parsed =
          DateTime.tryParse(hourlyTimes![i]);

      if (parsed == null) {
        continue;
      }

      if (!parsed.isBefore(now)) {
        return i;
      }
    }

    return hourlyTimes!.length - 1;
  }

  // ==========================================================
  // NASLEDUJÚCE HODINY
  //
  // Pomocná funkcia pre RainArrivalWidget.
  // ==========================================================

  int getForecastIndex(int hoursFromNow) {
    final start = currentHourlyIndex;

    final index =
        start + hoursFromNow;

    final maxLength =
        hourlyTimes?.length ?? 0;

    if (maxLength == 0) {
      return 0;
    }

    if (index >= maxLength) {
      return maxLength - 1;
    }

    return index;
  }

  // ==========================================================
  // FORMÁTOVANIE ČASU
  // ==========================================================

  String formattedHourlyTime(int index) {
    if (hourlyTimes == null ||
        index < 0 ||
        index >= hourlyTimes!.length) {
      return '--:--';
    }

    final date =
        DateTime.tryParse(
      hourlyTimes![index],
    );

    if (date == null) {
      return '--:--';
    }

    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  // ==========================================================
  // HODINOVÁ TEPLOTA
  // ==========================================================

  double? temperatureAt(int index) {
    if (hourlyTemperature == null ||
        index < 0 ||
        index >= hourlyTemperature!.length) {
      return null;
    }

    return hourlyTemperature![index];
  }

  // ==========================================================
  // WEATHER CODE
  // ==========================================================

  int? weatherCodeAt(int index) {
    if (hourlyWeatherCode == null ||
        index < 0 ||
        index >= hourlyWeatherCode!.length) {
      return null;
    }

    return hourlyWeatherCode![index];
  }

  // ==========================================================
  // PRAVDEPODOBNOSŤ ZRÁŽOK
  // ==========================================================

  int? precipitationProbabilityAt(
    int index,
  ) {
    if (hourlyPrecipitationProbability ==
            null ||
        index < 0 ||
        index >=
            hourlyPrecipitationProbability!
                .length) {
      return null;
    }

    return hourlyPrecipitationProbability![
        index];
  }

  // ==========================================================
  // MNOŽSTVO ZRÁŽOK
  // ==========================================================

  double? precipitationAt(int index) {
    if (hourlyPrecipitation == null ||
        index < 0 ||
        index >=
            hourlyPrecipitation!.length) {
      return null;
    }

    return hourlyPrecipitation![index];
  }

  // ==========================================================
  // VIETOR
  // ==========================================================

  double? windSpeedAt(int index) {
    if (hourlyWindSpeed == null ||
        index < 0 ||
        index >= hourlyWindSpeed!.length) {
      return null;
    }

    return hourlyWindSpeed![index];
  }

  double? windDirectionAt(int index) {
    if (hourlyWindDirection == null ||
        index < 0 ||
        index >=
            hourlyWindDirection!.length) {
      return null;
    }

    return hourlyWindDirection![index];
  }

  // ==========================================================
  // VLHKOSŤ
  // ==========================================================

  double? humidityAt(int index) {
    if (hourlyHumidity == null ||
        index < 0 ||
        index >= hourlyHumidity!.length) {
      return null;
    }

    return hourlyHumidity![index];
  }

  // ==========================================================
  // TLAK
  // ==========================================================

  double? pressureAt(int index) {
    if (hourlyPressure == null ||
        index < 0 ||
        index >= hourlyPressure!.length) {
      return null;
    }

    return hourlyPressure![index];
  }

  // ==========================================================
  // NASLEDUJÚCA HODINA
  // ==========================================================

  String get nextHourLabel {
    final index =
        getForecastIndex(1);

    return formattedHourlyTime(index);
  }

  // ==========================================================
  // PRÍCHOD ZRÁŽOK
  // ==========================================================

  int? _calculateRainArrivalMinutes(
    List<String>? times,
    List<int>? probabilities,
  ) {
    if (times == null ||
        probabilities == null ||
        times.isEmpty ||
        probabilities.isEmpty) {
      return null;
    }

    final now = DateTime.now();

    final count = [
      times.length,
      probabilities.length,
    ].reduce(
      (a, b) => a < b ? a : b,
    );

    for (int i = 0; i < count; i++) {
      final probability =
          probabilities[i];

      final parsed =
          DateTime.tryParse(times[i]);

      if (parsed == null) {
        continue;
      }

      // Ignorujeme minulé hodiny.
      if (parsed.isBefore(now)) {
        continue;
      }

      // 30 % je zatiaľ konzervatívny
      // prah pre "možný dážď".
      if (probability >= 30) {
        final difference =
            parsed.difference(now);

        return difference.inMinutes < 0
            ? 0
            : difference.inMinutes;
      }
    }

    return null;
  }

  // ==========================================================
  // FROM JSON
  // ==========================================================

  factory MeteoApiData.fromJson(
    Map<String, dynamic> json,
  ) {
    // ========================================================
    // CURRENT
    // ========================================================

    double currentTemperature = 0.0;
    double currentWindSpeed = 0.0;
    double currentWindDirection = 0.0;
    double currentPressure = 0.0;
    int currentWeatherCode = 0;

    // ========================================================
    // HOURLY
    // ========================================================

    List<String>? hourlyTimes;
    List<double>? hourlyTemperature;
    List<int>? hourlyWeatherCode;

    List<int>?
        hourlyPrecipitationProbability;

    List<double>? hourlyPrecipitation;

    List<double>? hourlyWindDirection;
    List<double>? hourlyWindSpeed;

    List<double>? hourlyHumidity;
    List<double>? hourlyPressure;

    // ========================================================
    // DAILY
    // ========================================================

    List<String>? dailyTimes;
    List<double>? dailyTemperatureMax;
    List<double>? dailyTemperatureMin;
    List<int>? dailyWeatherCode;
    List<String>? dailySunrise;
    List<String>? dailySunset;

    // ========================================================
    // CURRENT
    // ========================================================

    final current =
        json['current'];

    if (current is Map) {
      currentTemperature =
          (current['temperature_2m']
                      as num?)
                  ?.toDouble() ??
              0.0;

      currentWindSpeed =
          (current['wind_speed_10m']
                      as num?)
                  ?.toDouble() ??
              0.0;

      currentWindDirection =
          (current['wind_direction_10m']
                      as num?)
                  ?.toDouble() ??
              0.0;

      currentPressure =
          (current['surface_pressure']
                      as num?)
                  ?.toDouble() ??
              0.0;

      currentWeatherCode =
          (current['weather_code']
                      as num?)
                  ?.toInt() ??
              0;
    }

    // ========================================================
    // HOURLY
    // ========================================================

    final hourly =
        json['hourly'];

    if (hourly is Map) {
      // ------------------------------------------------------
      // TIME
      // ------------------------------------------------------

      if (hourly['time'] is List) {
        hourlyTimes =
            (hourly['time'] as List)
                .map(
                  (e) => e.toString(),
                )
                .toList();
      }

      // ------------------------------------------------------
      // TEMPERATURE
      // ------------------------------------------------------

      if (hourly['temperature_2m']
          is List) {
        hourlyTemperature =
            (hourly['temperature_2m']
                    as List)
                .whereType<num>()
                .map(
                  (e) => e.toDouble(),
                )
                .toList();
      }

      // ------------------------------------------------------
      // WEATHER CODE
      // ------------------------------------------------------

      if (hourly['weather_code']
          is List) {
        hourlyWeatherCode =
            (hourly['weather_code']
                    as List)
                .whereType<num>()
                .map(
                  (e) => e.toInt(),
                )
                .toList();
      }

      // ------------------------------------------------------
      // PRECIPITATION PROBABILITY
      // ------------------------------------------------------

      if (hourly[
              'precipitation_probability']
          is List) {
        hourlyPrecipitationProbability =
            (hourly[
                    'precipitation_probability']
                as List)
                .whereType<num>()
                .map(
                  (e) => e.toInt(),
                )
                .toList();
      }

      // ------------------------------------------------------
      // PRECIPITATION
      // ------------------------------------------------------

      if (hourly['precipitation']
          is List) {
        hourlyPrecipitation =
            (hourly['precipitation']
                    as List)
                .whereType<num>()
                .map(
                  (e) => e.toDouble(),
                )
                .toList();
      }

      // ------------------------------------------------------
      // WIND DIRECTION
      // ------------------------------------------------------

      if (hourly[
              'wind_direction_10m']
          is List) {
        hourlyWindDirection =
            (hourly[
                    'wind_direction_10m']
                as List)
                .whereType<num>()
                .map(
                  (e) => e.toDouble(),
                )
                .toList();
      }

      // ------------------------------------------------------
      // WIND SPEED
      // ------------------------------------------------------

      if (hourly[
              'wind_speed_10m']
          is List) {
        hourlyWindSpeed =
            (hourly[
                    'wind_speed_10m']
                as List)
                .whereType<num>()
                .map(
                  (e) => e.toDouble(),
                )
                .toList();
      }

      // ------------------------------------------------------
      // HUMIDITY
      // ------------------------------------------------------

      if (hourly[
              'relative_humidity_2m']
          is List) {
        hourlyHumidity =
            (hourly[
                    'relative_humidity_2m']
                as List)
                .whereType<num>()
                .map(
                  (e) => e.toDouble(),
                )
                .toList();
      }

      // ------------------------------------------------------
      // PRESSURE
      // ------------------------------------------------------

      if (hourly[
              'surface_pressure']
          is List) {
        hourlyPressure =
            (hourly[
                    'surface_pressure']
                as List)
                .whereType<num>()
                .map(
                  (e) => e.toDouble(),
                )
                .toList();
      }
    }

    // ========================================================
    // DAILY
    // ========================================================

    final daily =
        json['daily'];

    if (daily is Map) {
      // ------------------------------------------------------
      // TIME
      // ------------------------------------------------------

      if (daily['time'] is List) {
        dailyTimes =
            (daily['time'] as List)
                .map(
                  (e) => e.toString(),
                )
                .toList();
      }

      // ------------------------------------------------------
      // MAX
      // ------------------------------------------------------

      if (daily[
              'temperature_2m_max']
          is List) {
        dailyTemperatureMax =
            (daily[
                    'temperature_2m_max']
                as List)
                .whereType<num>()
                .map(
                  (e) => e.toDouble(),
                )
                .toList();
      }

      // ------------------------------------------------------
      // MIN
      // ------------------------------------------------------

      if (daily[
              'temperature_2m_min']
          is List) {
        dailyTemperatureMin =
            (daily[
                    'temperature_2m_min']
                as List)
                .whereType<num>()
                .map(
                  (e) => e.toDouble(),
                )
                .toList();
      }

      // ------------------------------------------------------
      // WEATHER CODE
      // ------------------------------------------------------

      if (daily['weather_code']
          is List) {
        dailyWeatherCode =
            (daily['weather_code'] as List)
                .whereType<num>()
                .map(
                  (e) => e.toInt(),
                )
                .toList();
      }

      // ------------------------------------------------------
      // SUNRISE
      // ------------------------------------------------------

      if (daily['sunrise']
          is List) {
        dailySunrise =
            (daily['sunrise'] as List)
                .map(
                  (e) => e.toString(),
                )
                .toList();
      }

      // ------------------------------------------------------
      // SUNSET
      // ------------------------------------------------------

      if (daily['sunset']
          is List) {
        dailySunset =
            (daily['sunset'] as List)
                .map(
                  (e) => e.toString(),
                )
                .toList();
      }
    }

    // ========================================================
    // RAIN ARRIVAL
    // ========================================================

    final rainArrivalMinutes =
        MeteoApiData._calculateRainArrivalStatic(
      hourlyTimes,
      hourlyPrecipitationProbability,
    );

    // ========================================================
    // RETURN
    // ========================================================

    return MeteoApiData(
      currentTemperature:
          currentTemperature,
      currentWindSpeed:
          currentWindSpeed,
      currentWindDirection:
          currentWindDirection,
      currentPressure:
          currentPressure,
      currentWeatherCode:
          currentWeatherCode,

      hourlyTimes:
          hourlyTimes,
      hourlyTemperature:
          hourlyTemperature,
      hourlyWeatherCode:
          hourlyWeatherCode,

      hourlyPrecipitationProbability:
          hourlyPrecipitationProbability,
      hourlyPrecipitation:
          hourlyPrecipitation,

      hourlyWindDirection:
          hourlyWindDirection,
      hourlyWindSpeed:
          hourlyWindSpeed,

      hourlyHumidity:
          hourlyHumidity,
      hourlyPressure:
          hourlyPressure,

      dailyTimes:
          dailyTimes,
      dailyTemperatureMax:
          dailyTemperatureMax,
      dailyTemperatureMin:
          dailyTemperatureMin,
      dailyWeatherCode:
          dailyWeatherCode,
      dailySunrise:
          dailySunrise,
      dailySunset:
          dailySunset,

      rainArrivalMinutes:
          rainArrivalMinutes,
    );
  }

  // ==========================================================
  // STATIC RAIN ARRIVAL
  // ==========================================================

  static int?
      _calculateRainArrivalStatic(
    List<String>? times,
    List<int>? probabilities,
  ) {
    if (times == null ||
        probabilities == null ||
        times.isEmpty ||
        probabilities.isEmpty) {
      return null;
    }

    final now = DateTime.now();

    final count = [
      times.length,
      probabilities.length,
    ].reduce(
      (a, b) => a < b ? a : b,
    );

    for (int i = 0; i < count; i++) {
      final parsed =
          DateTime.tryParse(times[i]);

      if (parsed == null) {
        continue;
      }

      if (parsed.isBefore(now)) {
        continue;
      }

      if (probabilities[i] >= 30) {
        final difference =
            parsed.difference(now);

        return difference.inMinutes < 0
            ? 0
            : difference.inMinutes;
      }
    }

    return null;
  }
}

// ============================================================
// LOCATION PRESET
// ============================================================

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
