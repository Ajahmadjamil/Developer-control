package com.ahmadjamil.developercontrol

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews

/**
 * Home screen "Tap to Lock" widget.
 * Click goes straight to this BroadcastReceiver — Flutter Activity is never opened.
 */
class LockScreenWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_LOCK -> {
                LockHelper.lockScreen(context)
                return
            }
            ACTION_WIDGET_PINNED -> {
                // Launcher confirmed the widget was pinned — refresh its views.
                val manager = AppWidgetManager.getInstance(context)
                val ids = manager.getAppWidgetIds(
                    ComponentName(context, LockScreenWidgetProvider::class.java),
                )
                for (id in ids) {
                    updateWidget(context, manager, id)
                }
                return
            }
        }
        super.onReceive(context, intent)
    }

    companion object {
        const val ACTION_LOCK = "com.ahmadjamil.developercontrol.ACTION_LOCK_SCREEN"
        const val ACTION_WIDGET_PINNED = "com.ahmadjamil.developercontrol.ACTION_WIDGET_PINNED"

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val views = RemoteViews(context.packageName, R.layout.lock_screen_widget)

            val lockIntent = Intent(context, LockScreenWidgetProvider::class.java).apply {
                action = ACTION_LOCK
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pending = PendingIntent.getBroadcast(context, appWidgetId, lockIntent, flags)
            views.setOnClickPendingIntent(R.id.lock_widget_root, pending)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
