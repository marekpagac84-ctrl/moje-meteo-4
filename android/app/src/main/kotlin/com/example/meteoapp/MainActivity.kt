package com.example.moje_meteo

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val channelName = "moje_meteo/widget"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WeatherWidgetScheduler.schedule(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateLocation" -> {
                        val lat = call.argument<Double>("lat")
                        val lng = call.argument<Double>("lng")
                        val name = call.argument<String>("name") ?: "Moja poloha"
                        if (lat != null && lng != null) {
                            WeatherWidgetStore.saveLocation(this, lat, lng, name)
                            WeatherWidgetScheduler.runNow(this)
                            WeatherWidgetProvider.updateAll(this, refreshing = true)
                            result.success(true)
                        } else {
                            result.error("BAD_LOCATION", "Missing latitude or longitude", null)
                        }
                    }
                    "refreshWidget" -> {
                        WeatherWidgetScheduler.runNow(this)
                        WeatherWidgetProvider.updateAll(this, refreshing = true)
                        result.success(true)
                    }
                    "updateWeatherSnapshot" -> {
                        val old = WeatherWidgetStore.read(this)
                        val code = call.argument<Int>("weatherCode")
                        WeatherWidgetStore.save(this, old.copy(
                            lat = call.argument<Double>("lat") ?: old.lat,
                            lng = call.argument<Double>("lng") ?: old.lng,
                            locationName = call.argument<String>("name") ?: old.locationName,
                            temperature = call.argument<Double>("temperature"),
                            apparentTemperature = call.argument<Double>("apparentTemperature"),
                            weatherCode = code,
                            cloudCover = call.argument<Int>("cloudCover"),
                            precipProbability = call.argument<Int>("precipProbability"),
                            rainTotalMm = call.argument<Double>("rainTotalMm"),
                            // Stav "prsi u teba" meni az radarovy snapshot.
                            rainingAtUser = old.rainingAtUser,
                            updatedAt = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
                        ))
                        WeatherWidgetProvider.updateAll(this, refreshing = false)
                        result.success(true)
                    }
                    "updateRadarSnapshot" -> {
                        val old = WeatherWidgetStore.read(this)
                        WeatherWidgetStore.save(this, old.copy(
                            lat = call.argument<Double>("lat") ?: old.lat,
                            lng = call.argument<Double>("lng") ?: old.lng,
                            radarDetected = call.argument<Boolean>("detected") ?: false,
                            radarDistanceKm = call.argument<Double>("distanceKm"),
                            radarSpeedKmh = call.argument<Double>("speedKmh"),
                            radarBearingDeg = call.argument<Double>("bearingDeg"),
                            radarPlaceName = call.argument<String>("placeName"),
                            radarMovementBearingDeg = call.argument<Double>("movementBearingDeg"),
                            radarEtaMinutes = call.argument<Int>("etaMinutes"),
                            radarConfidence = call.argument<Double>("confidence") ?: 0.0,
                            rainingAtUser = call.argument<Boolean>("rainingAtUser") ?: old.rainingAtUser,
                            radarApproaching = call.argument<Boolean>("approaching") ?: false,
                            radarPathIntersects = call.argument<Boolean>("pathIntersects") ?: false,
                            radarStatus = call.argument<String>("status") ?: "Radar zatiaľ nemá dáta.",
                            updatedAt = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
                        ))
                        WeatherWidgetProvider.updateAll(this, refreshing = false)
                        result.success(true)
                    }
                    "resolveRadarPlace" -> {
                        val lat = call.argument<Double>("lat")
                        val lng = call.argument<Double>("lng")
                        val bearing = call.argument<Double>("bearing")
                        val distance = call.argument<Double>("distance")
                        if (lat == null || lng == null || bearing == null) {
                            result.success(null)
                        } else {
                            Thread {
                                val place = PlaceDirectionResolver.resolve(
                                    applicationContext, lat, lng, bearing, distance
                                )
                                runOnUiThread { result.success(place) }
                            }.start()
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
