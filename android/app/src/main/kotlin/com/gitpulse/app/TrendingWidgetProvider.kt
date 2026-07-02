package com.gitpulse.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class TrendingWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                
                val repoName = widgetData.getString("repo_name", "No Data Yet")
                val repoDesc = widgetData.getString("repo_desc", "Open GitPulse to load today's trending repo.")
                val repoStars = widgetData.getString("repo_stars", "0")
                val repoLang = widgetData.getString("repo_lang", "Unknown")
                
                setTextViewText(R.id.repo_name, repoName)
                setTextViewText(R.id.repo_desc, repoDesc)
                setTextViewText(R.id.repo_stars, "⭐ $repoStars")
                setTextViewText(R.id.repo_lang, " • $repoLang")

                // Pending intent to open app
                val intent = Intent(context, MainActivity::class.java)
                intent.action = Intent.ACTION_VIEW
                
                // If we saved an owner/repo, pass it as a deep link or extra
                val owner = widgetData.getString("repo_owner", "")
                val name = widgetData.getString("repo_raw_name", "")
                if (owner!!.isNotEmpty() && name!!.isNotEmpty()) {
                    intent.data = Uri.parse("gitpulse://repo/$owner/$name")
                }
                
                val pendingIntent = PendingIntent.getActivity(
                    context, 
                    appWidgetId, 
                    intent, 
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
