package com.example.moje_meteo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.*
import androidx.core.app.NotificationCompat
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.*

class WeatherWatchWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {
    data class Radar(val distance: Double?, val bearing: Double?, val speed: Double?, val eta: Int?, val confidence: Double, val approaching: Boolean, val radarBitmap: Bitmap?)
    data class Weather(val temp: Double, val apparent: Double, val probability: Int, val precipitation: Double, val wind: Double, val pressure: Double)

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            val p = applicationContext.getSharedPreferences("moje_meteo_widget", Context.MODE_PRIVATE)
            val lat = java.lang.Double.longBitsToDouble(p.getLong("lat_bits", java.lang.Double.doubleToRawLongBits(48.7576)))
            val lng = java.lang.Double.longBitsToDouble(p.getLong("lng_bits", java.lang.Double.doubleToRawLongBits(17.8309)))
            val name = p.getString("location_name", "Nové Mesto nad Váhom") ?: "Moja poloha"
            val weather = loadWeather(lat, lng)
            val radar = loadRadar(lat, lng)
            val bitmap = renderWidget(name, weather, radar)
            val f = File(applicationContext.filesDir, "storm_orb_widget.png")
            f.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 92, it) }
            p.edit().putString("widget_image", f.absolutePath).apply()
            updateWidgets()
            maybeNotify(p, name, weather, radar)
            Result.success()
        } catch (_: Throwable) { Result.retry() }
    }

    private fun loadWeather(lat: Double, lng: Double): Weather {
        val u = "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,apparent_temperature,precipitation,wind_speed_10m,surface_pressure&hourly=precipitation_probability&forecast_hours=3&timezone=auto"
        val j = JSONObject(getText(u))
        val c = j.getJSONObject("current")
        val h = j.getJSONObject("hourly")
        val prob = h.getJSONArray("precipitation_probability").optInt(0, 0)
        return Weather(c.optDouble("temperature_2m",0.0), c.optDouble("apparent_temperature",0.0), prob, c.optDouble("precipitation",0.0), c.optDouble("wind_speed_10m",0.0), c.optDouble("surface_pressure",0.0))
    }

    private fun loadRadar(lat: Double, lng: Double): Radar {
        val root = JSONObject(getText("https://api.rainviewer.com/public/weather-maps.json"))
        val host = root.getString("host")
        val past = root.getJSONObject("radar").getJSONArray("past")
        val start = max(0, past.length()-3)
        val samples = mutableListOf<Triple<Long, Pair<Double,Double>, Bitmap>>()
        for (i in start until past.length()) {
            val f = past.getJSONObject(i); val t=f.getLong("time"); val path=f.getString("path")
            val url="$host$path/512/7/${"%.5f".format(Locale.US,lat)}/${"%.5f".format(Locale.US,lng)}/2/0_0.png"
            val b = getBitmap(url) ?: continue
            val c = radarCentroid(b) ?: continue
            samples.add(Triple(t,c,b))
        }
        if(samples.isEmpty()) return Radar(null,null,null,null,0.45,false,null)
        val last=samples.last(); val e=last.second.first; val n=last.second.second
        val dist=sqrt(e*e+n*n); val bearing=(Math.toDegrees(atan2(e,n))+360.0)%360.0
        var speed:Double?=null; var eta:Int?=null; var approaching=false; var conf=0.58
        if(samples.size>=2){
            val first=samples.first(); val hours=(last.first-first.first)/3600.0
            if(hours>0){
                val vx=(e-first.second.first)/hours; val vy=(n-first.second.second)/hours
                val sp=sqrt(vx*vx+vy*vy)
                if(sp in 2.0..160.0){
                    speed=sp; val radial=(e*vx+n*vy)/max(0.1,dist); val closing=-radial
                    approaching=closing>2
                    if(approaching && closing>0 && dist<70) eta=(dist/closing*60).roundToInt().takeIf{it in 1..180}
                    conf=if(samples.size>=3)0.78 else 0.66
                }
            }
        }
        return Radar(dist,bearing,speed,eta,conf,approaching,last.third)
    }

    private fun radarCentroid(b: Bitmap): Pair<Double,Double>? {
        var sx=0.0; var sy=0.0; var sw=0.0
        val cx=b.width/2.0; val cy=b.height/2.0
        for(y in 2 until b.height step 5) for(x in 2 until b.width step 5){
            val c=b.getPixel(x,y); val a=Color.alpha(c); val r=Color.red(c); val g=Color.green(c); val bl=Color.blue(c)
            val chroma=max(r,max(g,bl))-min(r,min(g,bl)); if(a>35 && chroma>25){
                val w=(a/255.0)*(1+chroma/255.0); sx+=(x-cx)*w; sy+=(cy-y)*w; sw+=w
            }
        }
        if(sw<12) return null
        // 512 px at z7 centered tile ~ 313 km wide at this latitude; adequate local approximation.
        val kmPerPx=0.61
        return Pair(sx/sw*kmPerPx, sy/sw*kmPerPx)
    }

    private fun renderWidget(name:String,w:Weather,r:Radar):Bitmap{
        val W=900; val H=520; val b=Bitmap.createBitmap(W,H,Bitmap.Config.ARGB_8888); val c=Canvas(b)
        val bg=Paint(Paint.ANTI_ALIAS_FLAG); bg.shader=LinearGradient(0f,0f,W.toFloat(),H.toFloat(),Color.rgb(7,25,43),Color.rgb(3,11,20),Shader.TileMode.CLAMP); c.drawRoundRect(0f,0f,W.toFloat(),H.toFloat(),52f,52f,bg)
        val white=Paint(Paint.ANTI_ALIAS_FLAG).apply{color=Color.WHITE; typeface=Typeface.create("sans",Typeface.NORMAL)}
        white.textSize=34f; c.drawText("⌖  $name",40f,52f,white)
        val now=SimpleDateFormat("HH:mm",Locale.getDefault()).format(Date()); white.typeface=Typeface.create("sans",Typeface.BOLD); white.textSize=94f; c.drawText(now,38f,145f,white)
        white.textSize=70f; c.drawText("${w.temp.roundToInt()}°",42f,235f,white)
        white.typeface=Typeface.DEFAULT; white.textSize=26f; c.drawText("Pocitovo ${w.apparent.roundToInt()}°",45f,270f,white)
        white.typeface=Typeface.DEFAULT_BOLD; white.textSize=31f
        val eta=r.eta?.let{"Dážď za ~$it min"} ?: if(r.approaching) "Zrážky sa približujú" else "Bez zásahu radaru"
        c.drawText(eta,42f,325f,white)
        white.textSize=25f; c.drawText("Pravdepodobnosť v tvojej polohe",42f,370f,white)
        white.textSize=48f; c.drawText("${w.probability} %",42f,422f,white)
        val bar=Paint(Paint.ANTI_ALIAS_FLAG).apply{color=Color.rgb(30,90,120)}; c.drawRoundRect(42f,438f,300f,453f,8f,8f,bar); bar.color=Color.rgb(55,205,255); c.drawRoundRect(42f,438f,42f+258f*w.probability/100f,453f,8f,8f,bar)
        // Radar orb: circular clip of actual RainViewer tile.
        val save=c.save(); val orb=RectF(395f,58f,855f,518f); val path=Path(); path.addOval(orb,Path.Direction.CW); c.clipPath(path)
        if(r.radarBitmap!=null){ c.drawBitmap(r.radarBitmap,null,orb,Paint(Paint.ANTI_ALIAS_FLAG)) } else { val p=Paint(); p.color=Color.rgb(10,55,70); c.drawOval(orb,p) }
        c.restoreToCount(save)
        val ring=Paint(Paint.ANTI_ALIAS_FLAG).apply{style=Paint.Style.STROKE;color=Color.argb(180,120,220,255);strokeWidth=4f}; c.drawOval(orb,ring)
        for(rad in listOf(75f,145f,215f)){ c.drawCircle(625f,288f,rad,ring.apply{strokeWidth=2f;color=Color.argb(110,220,245,255)}) }
        white.textSize=25f; white.typeface=Typeface.DEFAULT_BOLD; c.drawText("TY",607f,297f,white)
        val dot=Paint(Paint.ANTI_ALIAS_FLAG).apply{color=Color.CYAN}; c.drawCircle(625f,315f,10f,dot)
        // Direction arrow from precipitation bearing toward user.
        if(r.bearing!=null){
            val ang=Math.toRadians(r.bearing-90); val rr=175.0; val x=(625+cos(ang)*rr).toFloat(); val y=(288+sin(ang)*rr).toFloat();
            val ap=Paint(Paint.ANTI_ALIAS_FLAG).apply{color=Color.WHITE;strokeWidth=9f;strokeCap=Paint.Cap.ROUND}; c.drawLine(x,y,625f,315f,ap)
            val label=direction(r.bearing); white.textSize=24f; c.drawText("Prichádza: $label",610f,44f,white)
        }
        white.textSize=22f; white.typeface=Typeface.DEFAULT
        val d=r.distance?.let{"${"%.1f".format(Locale.US,it)} km"}?:"—"; val sp=r.speed?.let{"${it.roundToInt()} km/h"}?:"—"; c.drawText("Vzdialenosť $d   •   pohyb $sp",390f,505f,white)
        return b
    }

    private fun maybeNotify(p:android.content.SharedPreferences,name:String,w:Weather,r:Radar){
        val eta=r.eta ?: return
        if(!r.approaching || r.confidence<0.62 || eta>60) return
        val now=System.currentTimeMillis(); val last=p.getLong("last_alert",0); val lastEta=p.getInt("last_eta",999)
        if(now-last<45*60*1000 && abs(lastEta-eta)<8) return
        val nm=applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val ch="approaching_weather"; if(android.os.Build.VERSION.SDK_INT>=26) nm.createNotificationChannel(NotificationChannel(ch,"Blížiace sa zrážky",NotificationManager.IMPORTANCE_DEFAULT))
        val intent=Intent(applicationContext,MainActivity::class.java); val pi=PendingIntent.getActivity(applicationContext,2,intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val d=r.distance?.let{" (${"%.1f".format(Locale.US,it)} km, ${direction(r.bearing)})"}?:""
        val n=NotificationCompat.Builder(applicationContext,ch).setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle("Dážď sa približuje").setContentText("Za približne $eta min$d • pravdepodobnosť ${w.probability} %").setContentIntent(pi).setAutoCancel(true).setOnlyAlertOnce(true).build()
        nm.notify(4107,n); p.edit().putLong("last_alert",now).putInt("last_eta",eta).apply()
    }

    private fun direction(b:Double?):String{ if(b==null)return "—"; val a=arrayOf("S","SV","V","JV","J","JZ","Z","SZ"); return a[((b+22.5)/45.0).toInt()%8] }
    private fun updateWidgets(){ val m=android.appwidget.AppWidgetManager.getInstance(applicationContext); val ids=m.getAppWidgetIds(android.content.ComponentName(applicationContext,MojeMeteoWidgetProvider::class.java)); MojeMeteoWidgetProvider().onUpdate(applicationContext,m,ids) }
    private fun getText(s:String):String{ val c=URL(s).openConnection() as HttpURLConnection; c.connectTimeout=9000;c.readTimeout=9000;c.setRequestProperty("User-Agent","MojeMeteo/1.0"); return c.inputStream.bufferedReader().use{it.readText()} }
    private fun getBitmap(s:String):Bitmap?=try{ val c=URL(s).openConnection() as HttpURLConnection;c.connectTimeout=9000;c.readTimeout=9000; BitmapFactory.decodeStream(c.inputStream)}catch(_:Throwable){null}
}
