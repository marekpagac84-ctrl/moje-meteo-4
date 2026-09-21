package com.example.moje_meteo

import android.content.Context

data class WidgetWeatherData(
    val lat: Double = 48.7576,
    val lng: Double = 17.8309,
    val locationName: String = "Nové Mesto nad Váhom",
    val temperature: Double? = null,
    val apparentTemperature: Double? = null,
    val weatherCode: Int? = null,
    val cloudCover: Int? = null,
    val precipProbability: Int? = null,
    val nextRainMinutes: Int? = null,
    val rainTotalMm: Double? = null,
    val radarDetected: Boolean = false,
    val radarDistanceKm: Double? = null,
    val radarSpeedKmh: Double? = null,
    val radarBearingDeg: Double? = null,
    val radarMovementBearingDeg: Double? = null,
    val radarEtaMinutes: Int? = null,
    val radarConfidence: Double = 0.0,
    val rainingAtUser: Boolean = false,
    val radarApproaching: Boolean = false,
    val radarPathIntersects: Boolean = false,
    val radarStatus: String = "Radar zatiaľ nemá dáta.",
    val updatedAt: String? = null
)

object WeatherWidgetStore {
    private const val PREF = "moje_meteo_widget"
    private fun prefs(c: Context) = c.getSharedPreferences(PREF, Context.MODE_PRIVATE)

    fun saveLocation(c: Context, lat: Double, lng: Double, name: String) {
        prefs(c).edit().putLong("lat", java.lang.Double.doubleToRawLongBits(lat))
            .putLong("lng", java.lang.Double.doubleToRawLongBits(lng)).putString("name", name).apply()
    }

    fun save(c: Context, d: WidgetWeatherData) {
        val e = prefs(c).edit()
        e.putLong("lat", java.lang.Double.doubleToRawLongBits(d.lat))
        e.putLong("lng", java.lang.Double.doubleToRawLongBits(d.lng))
        e.putString("name", d.locationName)
        putDouble(e, "temp", d.temperature); putDouble(e, "apparent", d.apparentTemperature)
        if (d.weatherCode == null) e.remove("weather_code") else e.putInt("weather_code", d.weatherCode)
        if (d.cloudCover == null) e.remove("cloud_cover") else e.putInt("cloud_cover", d.cloudCover)
        if (d.precipProbability == null) e.remove("prob") else e.putInt("prob", d.precipProbability)
        if (d.nextRainMinutes == null) e.remove("next") else e.putInt("next", d.nextRainMinutes)
        putDouble(e, "total", d.rainTotalMm); e.putBoolean("radar", d.radarDetected)
        putDouble(e, "distance", d.radarDistanceKm); putDouble(e, "speed", d.radarSpeedKmh); putDouble(e, "bearing", d.radarBearingDeg)
        putDouble(e, "movement_bearing", d.radarMovementBearingDeg)
        if (d.radarEtaMinutes == null) e.remove("eta") else e.putInt("eta", d.radarEtaMinutes)
        e.putLong("confidence", java.lang.Double.doubleToRawLongBits(d.radarConfidence))
        e.putBoolean("raining_at_user", d.rainingAtUser)
        e.putBoolean("approaching", d.radarApproaching)
        e.putBoolean("intersects", d.radarPathIntersects)
        e.putString("radar_status", d.radarStatus)
        e.putString("updated", d.updatedAt).apply()
    }

    fun read(c: Context): WidgetWeatherData {
        val p = prefs(c)
        return WidgetWeatherData(
            lat = java.lang.Double.longBitsToDouble(p.getLong("lat", java.lang.Double.doubleToRawLongBits(48.7576))),
            lng = java.lang.Double.longBitsToDouble(p.getLong("lng", java.lang.Double.doubleToRawLongBits(17.8309))),
            locationName = p.getString("name", "Nové Mesto nad Váhom") ?: "Nové Mesto nad Váhom",
            temperature = getDouble(p, "temp"), apparentTemperature = getDouble(p, "apparent"),
            weatherCode = if (p.contains("weather_code")) p.getInt("weather_code", 0) else null,
            cloudCover = if (p.contains("cloud_cover")) p.getInt("cloud_cover", 0) else null,
            precipProbability = if (p.contains("prob")) p.getInt("prob", 0) else null,
            nextRainMinutes = if (p.contains("next")) p.getInt("next", 0) else null,
            rainTotalMm = getDouble(p, "total"), radarDetected = p.getBoolean("radar", false),
            radarDistanceKm = getDouble(p, "distance"), radarSpeedKmh = getDouble(p, "speed"), radarBearingDeg = getDouble(p, "bearing"),
            radarMovementBearingDeg = getDouble(p, "movement_bearing"),
            radarEtaMinutes = if (p.contains("eta")) p.getInt("eta", 0) else null,
            radarConfidence = java.lang.Double.longBitsToDouble(p.getLong("confidence", java.lang.Double.doubleToRawLongBits(0.0))),
            rainingAtUser = p.getBoolean("raining_at_user", false),
            radarApproaching = p.getBoolean("approaching", false),
            radarPathIntersects = p.getBoolean("intersects", false),
            radarStatus = p.getString("radar_status", "Radar zatiaľ nemá dáta.") ?: "Radar zatiaľ nemá dáta.",
            updatedAt = p.getString("updated", null)
        )
    }

    private fun putDouble(e: android.content.SharedPreferences.Editor, key: String, value: Double?) {
        if (value == null) e.remove(key) else e.putLong(key, java.lang.Double.doubleToRawLongBits(value))
    }
    private fun getDouble(p: android.content.SharedPreferences, key: String): Double? =
        if (!p.contains(key)) null else java.lang.Double.longBitsToDouble(p.getLong(key, 0L))
}
