package com.example.moje_meteo

import android.content.Context
import android.location.Geocoder
import org.json.JSONObject
import java.util.Locale
import kotlin.math.*

object PlaceDirectionResolver {
    private const val PREF = "moje_meteo_place_cache"
    private const val MAX_ENTRIES = 120
    private const val MAX_AGE_MS = 30L * 24L * 60L * 60L * 1000L

    fun resolve(
        context: Context,
        latitude: Double,
        longitude: Double,
        bearingDeg: Double?,
        distanceKm: Double?
    ): String? {
        if (bearingDeg == null) return null
        val lookupDistanceKm = (distanceKm ?: 20.0).coerceIn(10.0, 80.0)
        val target = destination(latitude, longitude, bearingDeg, lookupDistanceKm)
        val key = "%.1f,%.1f".format(Locale.US, target.first, target.second)
        val cached = readCache(context, key)
        if (cached != null) return cached

        if (!Geocoder.isPresent()) return null
        return try {
            @Suppress("DEPRECATION")
            val addresses = Geocoder(context, Locale.getDefault())
                .getFromLocation(target.first, target.second, 5)
                .orEmpty()
            val name = addresses.asSequence().mapNotNull { address ->
                address.locality?.takeIf { it.isNotBlank() }
                    ?: address.subAdminArea?.takeIf { it.isNotBlank() }
                    ?: address.adminArea?.takeIf { it.isNotBlank() }
            }.firstOrNull()?.trim()
            if (name != null) writeCache(context, key, name)
            name
        } catch (_: Exception) {
            null
        }
    }

    private fun destination(lat: Double, lon: Double, bearing: Double, distanceKm: Double): Pair<Double, Double> {
        val earthKm = 6371.0088
        val angular = distanceKm / earthKm
        val brng = Math.toRadians(bearing)
        val lat1 = Math.toRadians(lat)
        val lon1 = Math.toRadians(lon)
        val lat2 = asin(sin(lat1) * cos(angular) + cos(lat1) * sin(angular) * cos(brng))
        val lon2 = lon1 + atan2(
            sin(brng) * sin(angular) * cos(lat1),
            cos(angular) - sin(lat1) * sin(lat2)
        )
        return Math.toDegrees(lat2) to ((Math.toDegrees(lon2) + 540.0) % 360.0 - 180.0)
    }

    private fun readCache(context: Context, key: String): String? {
        val raw = context.getSharedPreferences(PREF, Context.MODE_PRIVATE).getString(key, null) ?: return null
        return try {
            val item = JSONObject(raw)
            val timestamp = item.optLong("time", 0L)
            if (System.currentTimeMillis() - timestamp > MAX_AGE_MS) {
                context.getSharedPreferences(PREF, Context.MODE_PRIVATE).edit().remove(key).apply()
                null
            } else item.optString("name").takeIf { it.isNotBlank() }
        } catch (_: Exception) {
            null
        }
    }

    private fun writeCache(context: Context, key: String, name: String) {
        val prefs = context.getSharedPreferences(PREF, Context.MODE_PRIVATE)
        val entries = prefs.all.mapNotNull { (entryKey, value) ->
            try {
                entryKey to JSONObject(value as String).optLong("time", 0L)
            } catch (_: Exception) { null }
        }.sortedBy { it.second }
        val editor = prefs.edit()
        if (entries.size >= MAX_ENTRIES) {
            entries.take(entries.size - MAX_ENTRIES + 1).forEach { editor.remove(it.first) }
        }
        editor.putString(key, JSONObject().put("name", name).put("time", System.currentTimeMillis()).toString()).apply()
    }
}
