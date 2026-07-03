package com.gitpulse.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class OverviewWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.widget_overview)
            
            val imagePath = widgetData.getString("overview_image", null)
            if (imagePath != null) {
                val bitmap = android.graphics.BitmapFactory.decodeFile(imagePath)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_image, bitmap)
                }
            }
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
