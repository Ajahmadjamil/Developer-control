package com.ahmadjamil.developercontrol

import android.app.PendingIntent
import android.app.admin.DevicePolicyManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.widget.RemoteViews
import android.widget.Toast

/**
 * Tap to Lock helpers — Device Admin only (no Accessibility floating button).
 */
object LockHelper {

    fun isDeviceAdminActive(context: Context): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val admin = ComponentName(context, LockDeviceAdminReceiver::class.java)
        return dpm.isAdminActive(admin)
    }

    fun hasLockPermission(context: Context): Boolean = isDeviceAdminActive(context)

    fun deviceAdminComponent(context: Context): ComponentName {
        return ComponentName(context, LockDeviceAdminReceiver::class.java)
    }

    /** Intent for the system Device Admin activation screen (no NEW_TASK — use from Activity). */
    fun createAddDeviceAdminIntent(context: Context): Intent {
        return Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(
                DevicePolicyManager.EXTRA_DEVICE_ADMIN,
                deviceAdminComponent(context),
            )
            putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "Allow Developer Control to lock the screen from the home widget.",
            )
        }
    }

    fun lockScreen(context: Context): Boolean {
        if (isDeviceAdminActive(context)) {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            dpm.lockNow()
            return true
        }

        Toast.makeText(
            context.applicationContext,
            "Turn on Tap to Lock in the app first",
            Toast.LENGTH_SHORT,
        ).show()
        return false
    }

    /**
     * Asks the launcher to pin the Tap to Lock widget.
     * Must be called from a resumed Activity for the system dialog to show reliably.
     */
    fun requestPinLockWidget(context: Context): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return mapOf(
                "shown" to false,
                "supported" to false,
                "message" to "Long-press your home screen → Widgets → Tap to Lock",
            )
        }

        val manager = AppWidgetManager.getInstance(context)
        if (!manager.isRequestPinAppWidgetSupported) {
            return mapOf(
                "shown" to false,
                "supported" to false,
                "message" to "Long-press your home screen → Widgets → Tap to Lock",
            )
        }

        val provider = ComponentName(context, LockScreenWidgetProvider::class.java)

        // Preview so the pin dialog looks correct.
        val extras = Bundle()
        val preview = RemoteViews(context.packageName, R.layout.lock_screen_widget)
        extras.putParcelable(AppWidgetManager.EXTRA_APPWIDGET_PREVIEW, preview)

        val successFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val successIntent = Intent(context, LockScreenWidgetProvider::class.java).apply {
            action = LockScreenWidgetProvider.ACTION_WIDGET_PINNED
        }
        val successCallback = PendingIntent.getBroadcast(
            context,
            0,
            successIntent,
            successFlags,
        )

        val shown = manager.requestPinAppWidget(provider, extras, successCallback)
        return mapOf(
            "shown" to shown,
            "supported" to true,
            "message" to if (shown) {
                ""
            } else {
                "Long-press your home screen → Widgets → Tap to Lock"
            },
        )
    }
}
