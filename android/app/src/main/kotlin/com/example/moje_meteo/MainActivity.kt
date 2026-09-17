package com.example.moje_meteo

import android.Manifest
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val channelName = "moje_meteo/widget"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WidgetScheduler.schedule(this)
        if (Build.VERSION.SDK_INT >= 33 && ActivityCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 2201)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateLocation" -> {
                    val lat = call.argument<Double>("lat")
                    val lng = call.argument<Double>("lng")
                    val name = call.argument<String>("name") ?: "Moja poloha"
                    if (lat != null && lng != null) {
                        getSharedPreferences("moje_meteo_widget", MODE_PRIVATE).edit()
                            .putLong("lat_bits", java.lang.Double.doubleToRawLongBits(lat))
                            .putLong("lng_bits", java.lang.Double.doubleToRawLongBits(lng))
                            .putString("location_name", name)
                            .apply()
                        WidgetScheduler.runNow(this)
                        val manager = AppWidgetManager.getInstance(this)
                        val ids = manager.getAppWidgetIds(ComponentName(this, MojeMeteoWidgetProvider::class.java))
                        MojeMeteoWidgetProvider().onUpdate(this, manager, ids)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}

object WidgetScheduler {
    private const val WORK = "moje_meteo_weather_watch"
    fun schedule(context: android.content.Context) {
        val req = PeriodicWorkRequestBuilder<WeatherWatchWorker>(15, TimeUnit.MINUTES).build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(WORK, ExistingPeriodicWorkPolicy.UPDATE, req)
    }
    fun runNow(context: android.content.Context) {
        WorkManager.getInstance(context).enqueue(androidx.work.OneTimeWorkRequestBuilder<WeatherWatchWorker>().build())
    }
}
