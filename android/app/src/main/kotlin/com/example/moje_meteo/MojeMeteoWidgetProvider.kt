package com.example.moje_meteo

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class MojeMeteoWidgetProvider : AppWidgetProvider() {
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetScheduler.schedule(context)
        WidgetScheduler.runNow(context)
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val prefs = context.getSharedPreferences("moje_meteo_widget", Context.MODE_PRIVATE)
        val imagePath = prefs.getString("widget_image", null)
        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.widget_storm_orb)
            if (imagePath != null) {
                val bmp = android.graphics.BitmapFactory.decodeFile(imagePath)
                if (bmp != null) views.setImageViewBitmap(R.id.widget_image, bmp)
            }
            val open = Intent(context, MainActivity::class.java)
            val pi = PendingIntent.getActivity(context, 0, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_image, pi)
            manager.updateAppWidget(id, views)
        }
    }
}
