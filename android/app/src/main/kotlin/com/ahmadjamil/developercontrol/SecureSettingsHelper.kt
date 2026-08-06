package com.ahmadjamil.developercontrol

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import android.util.Log

/**
 * Shared Settings.Global helpers used by [MainActivity] and [DeveloperModeTileService].
 */
object SecureSettingsHelper {
    private const val TAG = "DeveloperControl"

    fun hasWriteSecureSettings(context: Context): Boolean {
        return context.checkSelfPermission(android.Manifest.permission.WRITE_SECURE_SETTINGS) ==
            PackageManager.PERMISSION_GRANTED
    }

    fun isDeveloperOptionsEnabled(context: Context): Boolean {
        return isGlobalSettingEnabled(context, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED)
    }

    fun isUsbDebuggingEnabled(context: Context): Boolean {
        return isGlobalSettingEnabled(context, Settings.Global.ADB_ENABLED)
    }

    /** True when both Developer Options and USB Debugging are on. */
    fun isDeveloperModeActive(context: Context): Boolean {
        return isDeveloperOptionsEnabled(context) && isUsbDebuggingEnabled(context)
    }

    fun setDeveloperOptionsEnabled(context: Context, enabled: Boolean): Boolean {
        if (!enabled) {
            putGlobalSetting(context, Settings.Global.ADB_ENABLED, false)
        }
        return putGlobalSetting(context, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, enabled)
    }

    fun setUsbDebuggingEnabled(context: Context, enabled: Boolean): Boolean {
        if (enabled && !isDeveloperOptionsEnabled(context)) {
            putGlobalSetting(context, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, true)
        }
        return putGlobalSetting(context, Settings.Global.ADB_ENABLED, enabled)
    }

    /**
     * Turns both Developer Options and USB Debugging on or off together.
     * Returns the resulting combined active state, or null if writes failed.
     */
    fun setDeveloperModeEnabled(context: Context, enabled: Boolean): Boolean? {
        if (!hasWriteSecureSettings(context)) return null
        return if (enabled) {
            val ok = setDeveloperOptionsEnabled(context, true) &&
                setUsbDebuggingEnabled(context, true)
            if (ok) true else null
        } else {
            val ok = setUsbDebuggingEnabled(context, false) &&
                setDeveloperOptionsEnabled(context, false)
            if (ok) false else null
        }
    }

    fun toggleDeveloperMode(context: Context): Boolean? {
        val currentlyOn = isDeveloperModeActive(context)
        return setDeveloperModeEnabled(context, !currentlyOn)
    }

    fun openDeviceInfoSettings(context: Context) {
        openSettingsIntent(context, Settings.ACTION_DEVICE_INFO_SETTINGS)
    }

    fun openDeveloperOptionsSettings(context: Context) {
        openSettingsIntent(context, Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
    }

    private fun isGlobalSettingEnabled(context: Context, key: String): Boolean {
        return try {
            Settings.Global.getInt(context.contentResolver, key, 0) == 1
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read global setting: $key", e)
            false
        }
    }

    private fun putGlobalSetting(context: Context, key: String, enabled: Boolean): Boolean {
        if (!hasWriteSecureSettings(context)) return false
        return try {
            Settings.Global.putInt(context.contentResolver, key, if (enabled) 1 else 0)
        } catch (e: SecurityException) {
            Log.w(TAG, "Cannot write $key — WRITE_SECURE_SETTINGS not effective", e)
            false
        }
    }

    private fun openSettingsIntent(context: Context, action: String) {
        val intent = Intent(action).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }
}
