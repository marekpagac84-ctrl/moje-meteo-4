package com.example.moje_meteo

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit
import kotlin.math.*

class WeatherWidgetWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        return try {
            val old = WeatherWidgetStore.read(applicationContext)
            val weather = fetchWeather(old.lat, old.lng)
            val radar = fetchRadar(old.lat, old.lng)
            val radarPlace = if (radar.detected && !radar.rainingAtUser) {
                PlaceDirectionResolver.resolve(
                    applicationContext,
                    old.lat,
                    old.lng,
                    radar.bearingDeg,
                    radar.distanceKm
                )
            } else null
            val merged = old.copy(
                temperature = weather.temperature,
                apparentTemperature = weather.apparentTemperature,
                weatherCode = weather.weatherCode,
                cloudCover = weather.cloudCover,
                precipProbability = weather.precipProbability,
                nextRainMinutes = weather.nextRainMinutes,
                rainTotalMm = weather.rainTotalMm,
                radarDetected = radar.detected,
                radarDistanceKm = radar.distanceKm,
                radarSpeedKmh = radar.speedKmh,
                radarBearingDeg = radar.bearingDeg,
                radarPlaceName = radarPlace,
                radarMovementBearingDeg = radar.movementBearingDeg,
                radarEtaMinutes = radar.etaMinutes,
                radarConfidence = radar.confidence,
                rainingAtUser = radar.rainingAtUser || weather.currentPrecipitation >= 0.025 ||
                    weather.weatherCode in listOf(51,53,55,56,57,61,63,65,66,67,80,81,82,95,96,99),
                radarApproaching = radar.approaching,
                radarPathIntersects = radar.pathIntersects,
                radarStatus = radar.status,
                updatedAt = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
            )
            WeatherWidgetStore.save(applicationContext, merged)
            WeatherWidgetProvider.updateAll(applicationContext, refreshing = false)
            Result.success()
        } catch (e: Exception) {
            WeatherWidgetProvider.updateAll(applicationContext, refreshing = false)
            Result.retry()
        }
    }

    private fun fetchWeather(lat: Double, lng: Double): ModelWeather {
        val url = "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng" +
            "&current=temperature_2m,apparent_temperature,weather_code,cloud_cover,precipitation" +
            "&hourly=precipitation_probability&forecast_hours=6" +
            "&minutely_15=precipitation&forecast_minutely_15=16&timezone=auto"
        val json = JSONObject(getText(url))
        val current = json.getJSONObject("current")
        val temp = current.optDouble("temperature_2m", Double.NaN).takeUnless { it.isNaN() }
        val apparent = current.optDouble("apparent_temperature", Double.NaN).takeUnless { it.isNaN() }
        val weatherCode = if (current.has("weather_code")) current.optInt("weather_code") else null
        val cloudCover = if (current.has("cloud_cover")) current.optInt("cloud_cover") else null
        val currentPrecipitation = current.optDouble("precipitation", 0.0)
        val probs = json.optJSONObject("hourly")?.optJSONArray("precipitation_probability")
        val probability = if (probs != null && probs.length() > 0 && !probs.isNull(0)) probs.optInt(0) else null
        val arr = json.optJSONObject("minutely_15")?.optJSONArray("precipitation")
        var next: Int? = null
        var total = 0.0
        if (arr != null) {
            for (i in 0 until arr.length()) {
                val mm = arr.optDouble(i, 0.0)
                total += mm
                if (next == null && mm >= 0.025) next = i * 15
            }
        }
        fetchSatelliteClouds(lat, lng)
        return ModelWeather(temp, apparent, weatherCode, cloudCover, probability, next, total, currentPrecipitation)
    }

    private fun fetchSatelliteClouds(lat: Double, lng: Double) {
        val target = File(applicationContext.filesDir, "widget_clouds.png")
        try {
            val meta = JSONObject(getText("https://api.rainviewer.com/public/weather-maps.json"))
            val frames = meta.optJSONObject("satellite")?.optJSONArray("infrared")
            if (frames == null || frames.length() == 0) {
                target.delete()
                return
            }
            val frame = frames.getJSONObject(frames.length() - 1)
            val mosaic = downloadMosaic(meta.getString("host"), frame.getString("path"), lat, lng, 5, "0/0_0.png")
            if (mosaic == null) target.delete() else target.outputStream().use {
                mosaic.bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
            }
        } catch (_: Exception) {
            target.delete()
        }
    }

    private fun fetchRadar(lat: Double, lng: Double): RadarResult {
        val meta = JSONObject(getText("https://api.rainviewer.com/public/weather-maps.json"))
        val host = meta.getString("host")
        val past = meta.getJSONObject("radar").getJSONArray("past")
        if (past.length() == 0) return RadarResult.unavailable("Radar nemá dostupné snímky.")
        val start = max(0, past.length() - 4)
        val observations = mutableListOf<TimedRadarAnalysis>()
        for (i in start until past.length()) {
            val frame = past.getJSONObject(i)
            val mosaic = downloadRadarMosaic(host, frame.getString("path"), lat, lng) ?: continue
            if (i == past.length() - 1) {
                File(applicationContext.filesDir, "widget_radar.png").outputStream().use {
                    mosaic.bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
                }
            }
            val analysis = analyze(mosaic.bitmap, lat, mosaic.userX, mosaic.userY)
            if (analysis.detected) observations += TimedRadarAnalysis(frame.getLong("time"), analysis)
        }
        if (observations.isEmpty()) {
            return RadarResult(
                false, null, null, null, null, null, 0.70, false, false, false,
                "V okolí radar nezachytil zrážky."
            )
        }
        val latest = observations.last()
        val rainingAtUser = latest.analysis.distanceKm != null &&
            latest.analysis.distanceKm <= max(1.0, latest.analysis.kmPerPixel * 2.5)
        if (observations.size < 2) {
            return RadarResult(
                true, latest.analysis.distanceKm, null, latest.analysis.bearingDeg,
                null, null, 0.25, rainingAtUser, false, false,
                if (rainingAtUser) "Radar potvrdzuje zrážky priamo v tvojej polohe."
                else "Zrážky sú v okolí, ale chýba história pohybu."
            )
        }
        val oldest = observations.first()
        val dtHours = (latest.time - oldest.time) / 3600.0
        if (dtHours <= 0.0) return RadarResult.unavailable("Radarové snímky majú neplatný čas.")
        val vx = (latest.analysis.centroidX!! - oldest.analysis.centroidX!!) * latest.analysis.kmPerPixel / dtHours
        val vy = (latest.analysis.centroidY!! - oldest.analysis.centroidY!!) * latest.analysis.kmPerPixel / dtHours
        val speed = hypot(vx, vy)
        val usefulMotion = speed in 3.0..180.0
        val movementBearing = if (usefulMotion) {
            var value = Math.toDegrees(atan2(vx, -vy))
            if (value < 0) value += 360.0
            value
        } else null
        val rx = (latest.analysis.centroidX!! - latest.analysis.userX) * latest.analysis.kmPerPixel
        val ry = (latest.analysis.centroidY!! - latest.analysis.userY) * latest.analysis.kmPerPixel
        val v2 = vx * vx + vy * vy
        val hoursToClosest = if (usefulMotion && v2 > 0) -(rx * vx + ry * vy) / v2 else null
        val closestKm = if (hoursToClosest != null && hoursToClosest >= 0) {
            hypot(rx + vx * hoursToClosest, ry + vy * hoursToClosest)
        } else null
        val trend = oldest.analysis.distanceKm!! - latest.analysis.distanceKm!!
        val approaching = usefulMotion && trend > max(0.8, latest.analysis.kmPerPixel * 0.75) &&
            hoursToClosest != null && hoursToClosest >= 0
        val intersects = approaching && closestKm != null && hoursToClosest != null &&
            hoursToClosest <= 1.5 &&
            closestKm <= latest.analysis.radiusKm + 5.0
        var confidence = 0.20
        confidence += min(0.40, observations.size * 0.10)
        if (latest.analysis.pixelCount >= 12) confidence += 0.08
        if (latest.analysis.pixelCount >= 40) confidence += 0.07
        if (usefulMotion) confidence += 0.10
        if (abs(trend) >= 1.0) confidence += 0.05
        if (intersects) confidence += 0.05
        if (speed > 120) confidence -= 0.15
        confidence = confidence.coerceIn(0.0, 0.95)
        var eta = if (intersects && speed > 0) {
            ((latest.analysis.distanceKm!! / speed) * 60.0).roundToInt().takeIf { it in 0..120 }
        } else null
        if (confidence < 0.50) eta = null
        if (rainingAtUser) eta = null
        val status = when {
            rainingAtUser -> "Radar potvrdzuje zrážky priamo v tvojej polohe."
            !usefulMotion -> "Zrážky sú v okolí, pohyb zatiaľ nie je spoľahlivý."
            !approaching -> "Zrážky sa k tvojej polohe nepribližujú."
            !intersects -> "Zrážková oblasť podľa dráhy tvoju polohu minie."
            eta == null -> "Zrážky smerujú k polohe, ale ETA nemá dostatočnú istotu."
            else -> "Radar sleduje zrážky smerujúce k tvojej polohe."
        }
        return RadarResult(
            true, latest.analysis.distanceKm, if (usefulMotion) speed else null,
            latest.analysis.bearingDeg, movementBearing, eta, confidence,
            rainingAtUser, approaching, intersects, status
        )
    }

    private fun analyze(bitmap: Bitmap, lat: Double, userX: Double, userY: Double): RadarAnalysis {
        val w = bitmap.width; val h = bitmap.height
        val cx = userX; val cy = userY
        var nearest = Double.MAX_VALUE
        var nearestX = 0.0; var nearestY = 0.0
        var sx = 0.0; var sy = 0.0; var count = 0
        val step = 3
        for (y in 0 until h step step) for (x in 0 until w step step) {
            val pixel = bitmap.getPixel(x, y)
            val alpha = (pixel ushr 24) and 0xff
            if (alpha > 35) {
                val d = hypot(x - cx, y - cy)
                if (d < nearest) { nearest = d; nearestX = x.toDouble(); nearestY = y.toDouble() }
                sx += x; sy += y; count++
            }
        }
        val kmPerPixel = 156.54303392 * cos(Math.toRadians(lat)) / 2.0.pow(7.0) / 2.0
        if (count < 5 || nearest == Double.MAX_VALUE) return RadarAnalysis(false, null, null, null, null, 0, kmPerPixel, userX, userY, 0.0)
        val dx = nearestX - cx; val dy = nearestY - cy
        var bearing = Math.toDegrees(atan2(dx, -dy)); if (bearing < 0) bearing += 360.0
        val radiusKm = sqrt(count * step * step * kmPerPixel * kmPerPixel / Math.PI)
        return RadarAnalysis(true, nearest * kmPerPixel, bearing, sx/count, sy/count, count, kmPerPixel, userX, userY, radiusKm)
    }

    private fun downloadRadarMosaic(host: String, path: String, lat: Double, lng: Double): RadarMosaic? {
        return downloadMosaic(host, path, lat, lng, 7, "2/0_0.png")
    }

    private fun downloadMosaic(host: String, path: String, lat: Double, lng: Double, zoom: Int, suffix: String): RadarMosaic? {
        val tileSize = 256
        val n = 2.0.pow(zoom)
        val clippedLat = lat.coerceIn(-85.05112878, 85.05112878)
        val x = (lng + 180.0) / 360.0 * n
        val latRad = Math.toRadians(clippedLat)
        val y = (1.0 - ln(tan(latRad) + 1.0 / cos(latRad)) / Math.PI) / 2.0 * n
        val baseX = floor(x).toInt()
        val baseY = floor(y).toInt()
        val side = tileSize * 3
        val mosaic = Bitmap.createBitmap(side, side, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(mosaic)
        var loaded = 0
        val worldTiles = 1 shl zoom
        for (dy in -1..1) for (dx in -1..1) {
            val tileY = baseY + dy
            if (tileY !in 0 until worldTiles) continue
            val tileX = ((baseX + dx) % worldTiles + worldTiles) % worldTiles
            val tile = downloadBitmap("$host$path/$tileSize/$zoom/$tileX/$tileY/$suffix") ?: continue
            canvas.drawBitmap(tile, ((dx + 1) * tileSize).toFloat(), ((dy + 1) * tileSize).toFloat(), null)
            loaded++
        }
        if (loaded == 0) return null
        return RadarMosaic(
            mosaic,
            tileSize + (x - baseX) * tileSize,
            tileSize + (y - baseY) * tileSize
        )
    }

    private fun getText(url: String): String {
        val c = URL(url).openConnection() as HttpURLConnection
        c.connectTimeout = 12000; c.readTimeout = 12000
        c.setRequestProperty("User-Agent", "MojeMeteo/1.0")
        return c.inputStream.bufferedReader().use { it.readText() }
    }

    private fun downloadBitmap(url: String): Bitmap? = try {
        val c = URL(url).openConnection() as HttpURLConnection
        c.connectTimeout = 12000; c.readTimeout = 12000
        c.inputStream.use { BitmapFactory.decodeStream(it) }
    } catch (_: Exception) { null }
}

data class ModelWeather(val temperature: Double?, val apparentTemperature: Double?, val weatherCode: Int?, val cloudCover: Int?, val precipProbability: Int?, val nextRainMinutes: Int?, val rainTotalMm: Double?, val currentPrecipitation: Double)
data class RadarResult(
    val detected: Boolean,
    val distanceKm: Double?,
    val speedKmh: Double?,
    val bearingDeg: Double?,
    val movementBearingDeg: Double?,
    val etaMinutes: Int?,
    val confidence: Double,
    val rainingAtUser: Boolean,
    val approaching: Boolean,
    val pathIntersects: Boolean,
    val status: String
) {
    companion object {
        fun unavailable(status: String) = RadarResult(false, null, null, null, null, null, 0.0, false, false, false, status)
    }
}
data class RadarAnalysis(
    val detected: Boolean,
    val distanceKm: Double?,
    val bearingDeg: Double?,
    val centroidX: Double?,
    val centroidY: Double?,
    val pixelCount: Int,
    val kmPerPixel: Double,
    val userX: Double,
    val userY: Double,
    val radiusKm: Double
)
data class TimedRadarAnalysis(val time: Long, val analysis: RadarAnalysis)
data class RadarMosaic(val bitmap: Bitmap, val userX: Double, val userY: Double)

object WeatherWidgetScheduler {
    private const val WORK = "moje_meteo_widget_periodic"
    fun schedule(context: Context) {
        val request = PeriodicWorkRequestBuilder<WeatherWidgetWorker>(15, TimeUnit.MINUTES).build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(WORK, ExistingPeriodicWorkPolicy.UPDATE, request)
    }
    fun runNow(context: Context) {
        WorkManager.getInstance(context).enqueue(OneTimeWorkRequestBuilder<WeatherWidgetWorker>().build())
    }
}
