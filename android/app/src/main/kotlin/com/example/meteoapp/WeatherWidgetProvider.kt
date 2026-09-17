package com.example.moje_meteo

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.graphics.drawable.GradientDrawable
import android.widget.RemoteViews
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.*

class WeatherWidgetProvider : AppWidgetProvider() {
    override fun onEnabled(context: Context) { super.onEnabled(context); WeatherWidgetScheduler.schedule(context); WeatherWidgetScheduler.runNow(context) }
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) { ids.forEach { render(context, manager, it, false) }; WeatherWidgetScheduler.schedule(context) }
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH) { updateAll(context, true); WeatherWidgetScheduler.runNow(context) }
    }

    companion object {
        const val ACTION_REFRESH = "com.example.moje_meteo.WIDGET_REFRESH"

        fun updateAll(context: Context, refreshing: Boolean = false) {
            val m = AppWidgetManager.getInstance(context)
            m.getAppWidgetIds(ComponentName(context, WeatherWidgetProvider::class.java)).forEach { render(context, m, it, refreshing) }
        }

        private fun render(context: Context, manager: AppWidgetManager, id: Int, refreshing: Boolean) {
            val d = WeatherWidgetStore.read(context)
            val rv = RemoteViews(context.packageName, R.layout.weather_widget_4x4)
            rv.setTextViewText(R.id.widget_clock, SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date()))
            rv.setTextViewText(R.id.widget_location, d.locationName)
            rv.setTextViewText(R.id.widget_temp, d.temperature?.let { "${it.roundToInt()}°" } ?: "—°")
            rv.setTextViewText(R.id.widget_feels, d.apparentTemperature?.let { "Pocitovo ${it.roundToInt()}°" } ?: "Pocitovo —")
            rv.setTextViewText(R.id.widget_probability, d.precipProbability?.let { "$it %" } ?: "— %")
            rv.setTextViewText(R.id.widget_eta, when {
                d.radarEtaMinutes != null && d.radarPathIntersects && d.radarConfidence >= 0.50 ->
                    "DÁŽĎ ZA ${d.radarEtaMinutes} MIN"
                d.radarDetected && d.radarApproaching && !d.radarPathIntersects ->
                    "ZRÁŽKY ŤA PODĽA DRÁHY MINÚ"
                d.radarDetected -> d.radarStatus.uppercase(Locale.getDefault())
                d.nextRainMinutes != null -> "MODEL: MOŽNÝ DÁŽĎ ~${d.nextRainMinutes} MIN"
                else -> "BEZ ZRÁŽOK V DOSAHU"
            })
            rv.setTextViewText(R.id.widget_distance, d.radarDistanceKm?.let { "%.1f km".format(Locale.US, it) } ?: "— km")
            rv.setTextViewText(R.id.widget_speed, d.radarSpeedKmh?.let { "%.0f km/h".format(Locale.US, it) } ?: "— km/h")
            rv.setTextViewText(R.id.widget_direction, d.radarMovementBearingDeg?.let { "→ ${directionName(it)}" } ?: "—")
            rv.setTextViewText(R.id.widget_total, d.rainTotalMm?.let { "%.1f mm".format(Locale.US, it) } ?: "— mm")
            rv.setTextViewText(R.id.widget_updated, if (refreshing) "Aktualizujem…" else "Aktualizované ${d.updatedAt ?: "—"}")
            rv.setTextViewText(
                R.id.widget_source,
                if (d.radarDetected) "LIVE RADAR • ISTOTA ${(d.radarConfidence * 100).roundToInt()} % • RainViewer"
                else "RADAR • ${d.radarStatus}"
            )
            rv.setImageViewBitmap(R.id.widget_orb, drawCinematicOrb(context, d))

            val refresh = Intent(context, WeatherWidgetProvider::class.java).apply { action = ACTION_REFRESH }
            rv.setOnClickPendingIntent(R.id.widget_refresh, PendingIntent.getBroadcast(context, 5101, refresh, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
                rv.setOnClickPendingIntent(R.id.widget_root, PendingIntent.getActivity(context, 5102, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            }
            manager.updateAppWidget(id, rv)
        }

        private fun drawCinematicOrb(context: Context, d: WidgetWeatherData): Bitmap {
            val w = 760; val h = 470
            val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val c = Canvas(out); val p = Paint(Paint.ANTI_ALIAS_FLAG)
            val cx = 330f; val cy = 238f; val rx = 250f; val ry = 190f

            // atmospheric glow behind the orb
            p.shader = RadialGradient(cx, cy, 300f, intArrayOf(0x6643E9FF, 0x22206A94, Color.TRANSPARENT), floatArrayOf(0f,.55f,1f), Shader.TileMode.CLAMP)
            c.drawCircle(cx, cy, 300f, p); p.shader = null

            // outer glass halo
            p.style = Paint.Style.STROKE; p.strokeWidth = 3f; p.color = 0x557FEAFF
            c.drawOval(RectF(cx-rx-10, cy-ry-10, cx+rx+10, cy+ry+10), p)
            p.strokeWidth = 18f; p.color = 0x1824D8FF; c.drawOval(RectF(cx-rx-3, cy-ry-3, cx+rx+3, cy+ry+3), p)

            // clip all map/radar content into a tilted 3D-looking globe
            val globe = RectF(cx-rx, cy-ry, cx+rx, cy+ry)
            c.save(); c.clipPath(Path().apply { addOval(globe, Path.Direction.CW) })
            p.style = Paint.Style.FILL
            p.shader = LinearGradient(0f, globe.top, 0f, globe.bottom, intArrayOf(0xFF071522.toInt(),0xFF0A2A3B.toInt(),0xFF071018.toInt()), null, Shader.TileMode.CLAMP)
            c.drawOval(globe, p); p.shader = null

            val radarFile = File(context.filesDir, "widget_radar.png")
            if (radarFile.exists()) {
                BitmapFactory.decodeFile(radarFile.absolutePath)?.let { radar ->
                    p.alpha = 205; c.drawBitmap(radar, null, globe, p); p.alpha = 255
                }
            } else {
                // stylized terrain/cloud layers when radar has not loaded yet
                p.shader = LinearGradient(globe.left, globe.top, globe.right, globe.bottom, 0xFF123B49.toInt(), 0xFF07131D.toInt(), Shader.TileMode.CLAMP)
                c.drawOval(globe, p); p.shader = null
                p.color = 0x5546D5B3; c.drawOval(RectF(cx-240,cy+40,cx+80,cy+190),p)
                p.color = 0x334FC4FF; c.drawOval(RectF(cx-100,cy-180,cx+230,cy+30),p)
            }

            // spherical lighting: dark limb + cold highlight
            p.shader = RadialGradient(cx-85, cy-80, 360f, intArrayOf(0x0018E8FF,0x1514BDE8,0xB0000710.toInt()), floatArrayOf(0f,.55f,1f), Shader.TileMode.CLAMP)
            c.drawOval(globe,p); p.shader=null
            c.restore()

            // perspective range rings (5 / 10 / 20 / 50 km)
            p.style=Paint.Style.STROKE; p.strokeWidth=2f; p.color=0x887DEBFF.toInt()
            val rings = arrayOf(Pair(62f,46f),Pair(105f,79f),Pair(160f,121f),Pair(222f,168f))
            rings.forEach { (a,b) -> c.drawOval(RectF(cx-a,cy-b,cx+a,cy+b),p) }
            p.strokeWidth=1f; p.color=0x447DEBFF
            c.drawLine(cx-rx+18,cy,cx+rx-18,cy,p); c.drawLine(cx,cy-ry+12,cx,cy+ry-12,p)

            // range labels
            p.style=Paint.Style.FILL; p.typeface=Typeface.create(Typeface.DEFAULT,Typeface.BOLD); p.textSize=18f; p.color=0xB9BDEEFF.toInt()
            c.drawText("5",cx+48,cy-38,p); c.drawText("10",cx+88,cy-66,p); c.drawText("20",cx+140,cy-105,p); c.drawText("50 km",cx+186,cy-145,p)

            // compass labels
            p.textAlign=Paint.Align.CENTER; p.textSize=24f; p.color=Color.WHITE
            c.drawText("N",cx,cy-ry+27,p); c.drawText("S",cx,cy+ry-10,p)
            c.drawText("W",cx-rx+22,cy+7,p); c.drawText("E",cx+rx-22,cy+7,p)

            // user point and pulse
            p.color=0x334EEDFF; c.drawCircle(cx,cy,24f,p); p.color=0xFFB9FAFF.toInt(); c.drawCircle(cx,cy,8f,p)
            p.textSize=20f; p.color=Color.WHITE; c.drawText("TY",cx,cy+34,p)

            // incoming precipitation marker and vector
            d.radarBearingDeg?.let { bearing ->
                val r = Math.toRadians(bearing-90.0)
                val markerR=178.0
                val x=(cx+cos(r)*markerR).toFloat(); val y=(cy+sin(r)*markerR*.76).toFloat()
                p.shader=RadialGradient(x,y,46f,intArrayOf(0xFFFFD65A.toInt(),0x99FF7A2F.toInt(),Color.TRANSPARENT),null,Shader.TileMode.CLAMP)
                c.drawCircle(x,y,46f,p); p.shader=null; p.color=0xFFFFD968.toInt(); c.drawCircle(x,y,8f,p)
                // arrow toward user only when ETA exists; otherwise indicate location without false trajectory
                if (d.radarEtaMinutes != null && d.radarPathIntersects && d.radarConfidence >= 0.50) {
                    p.style=Paint.Style.STROKE; p.strokeWidth=5f; p.color=0xFFFFD968.toInt()
                    c.drawLine(x,y,cx,cy,p)
                    val ang=atan2((cy-y).toDouble(),(cx-x).toDouble())
                    val ax=(cx-cos(ang-0.55)*24).toFloat(); val ay=(cy-sin(ang-0.55)*24).toFloat()
                    val bx=(cx-cos(ang+0.55)*24).toFloat(); val by=(cy-sin(ang+0.55)*24).toFloat()
                    c.drawLine(cx,cy,ax,ay,p); c.drawLine(cx,cy,bx,by,p); p.style=Paint.Style.FILL
                }
            }

            // right-side floating glass telemetry inside the visual
            drawGlassPanel(c, 575f, 135f, 175f, 196f)
            p.textAlign=Paint.Align.LEFT; p.typeface=Typeface.create(Typeface.DEFAULT,Typeface.BOLD)
            p.textSize=14f; p.color=0xFF7FDFF2.toInt(); c.drawText("STORM TRACK",594f,161f,p)
            p.textSize=28f; p.color=Color.WHITE
            c.drawText(d.radarDistanceKm?.let{"%.1f km".format(Locale.US,it)}?:"— km",594f,199f,p)
            p.textSize=15f; p.color=0xFF9CB6C9.toInt(); c.drawText("VZDIALENOSŤ",594f,220f,p)
            p.textSize=22f; p.color=0xFFEAF9FF.toInt(); c.drawText(d.radarSpeedKmh?.let{"%.0f km/h".format(Locale.US,it)}?:"— km/h",594f,255f,p)
            p.textSize=15f; p.color=0xFF9CB6C9.toInt(); c.drawText("POHYB",594f,276f,p)
            p.textSize=22f; p.color=if(d.radarEtaMinutes!=null) 0xFFFFD968.toInt() else 0xFFEAF9FF.toInt()
            c.drawText(d.radarEtaMinutes?.let{"ETA $it min"}?:"ETA —",594f,310f,p)

            return out
        }

        private fun drawGlassPanel(c: Canvas, x:Float,y:Float,w:Float,h:Float) {
            val p=Paint(Paint.ANTI_ALIAS_FLAG); val r=RectF(x,y,x+w,y+h)
            p.color=0xB0122230.toInt(); c.drawRoundRect(r,24f,24f,p)
            p.style=Paint.Style.STROKE; p.strokeWidth=2f; p.color=0x557FEAFF; c.drawRoundRect(r,24f,24f,p)
        }

        private fun directionName(deg: Double): String {
            val names=arrayOf("S","SV","V","JV","J","JZ","Z","SZ")
            return names[((deg+22.5)/45.0).toInt()%8]
        }
    }
}
