package com.example.moje_meteo

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
                    else -> result.notImplemented()
                }
            }
    }
}
