package com.ahmadjamil.developercontrol

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.util.Log

/**
 * Shared Settings.Global helpers used by [MainActivity] and [DeveloperModeTileService].
 *
 * Android 17 QPR1+ reports development_settings_enabled / adb_enabled as 0 to
 * every third-party app, whatever the real value. Writes still work, so on
 * those builds a 0 means "unknown": USB Debugging comes from system properties,
 * and anything else falls back to what this app last wrote.
 */
object SecureSettingsHelper {
    private const val TAG = "DeveloperControl"

    /** First API level where Settings.Global hides developer state from apps. */
    private const val HIDDEN_READS_SDK = 37

    private const val PREFS = "dev_mode_state"
    private const val KEY_LAST_WRITE_AT = "last_write_at"

    /** System properties lag a write by a few hundred ms — trust the write meanwhile. */
    private const val WRITE_GRACE_MS = 3_000L

    private val readsMayBeHidden = Build.VERSION.SDK_INT >= HIDDEN_READS_SDK

    fun hasWriteSecureSettings(context: Context): Boolean {
        return context.checkSelfPermission(android.Manifest.permission.WRITE_SECURE_SETTINGS) ==
            PackageManager.PERMISSION_GRANTED
    }

    fun isDeveloperOptionsEnabled(context: Context): Boolean {
        return resolveDeveloperOptions(context, isUsbDebuggingEnabled(context))
    }

    fun isUsbDebuggingEnabled(context: Context): Boolean {
        val key = Settings.Global.ADB_ENABLED
        if (isGlobalSettingEnabled(context, key)) return true
        if (!readsMayBeHidden) return false
        if (!inWriteGrace(context)) {
            adbFromSystemProperties()?.let { live ->
                remember(context, key, live, stampWrite = false)
                return live
            }
        }
        return remembered(context, key)
    }

    /** True when both Developer Options and USB Debugging are on. */
    fun isDeveloperModeActive(context: Context): Boolean {
        val usb = isUsbDebuggingEnabled(context)
        return usb && resolveDeveloperOptions(context, usb)
    }

    /** Both values in one pass, so system properties are only read once. */
    fun getDeveloperModeState(context: Context): Map<String, Boolean> {
        val usb = isUsbDebuggingEnabled(context)
        return mapOf(
            "developerOptions" to resolveDeveloperOptions(context, usb),
            "usbDebugging" to usb,
        )
    }

    fun setDeveloperOptionsEnabled(context: Context, enabled: Boolean): Boolean {
        if (!enabled) {
            putGlobalSetting(context, Settings.Global.ADB_ENABLED, false)
        }
        return putGlobalSetting(context, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, enabled)
    }

    fun setUsbDebuggingEnabled(context: Context, enabled: Boolean): Boolean {
        // Always write it: on Android 17+ we can't read whether it's already on.
        if (enabled &&
            !putGlobalSetting(context, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, true)
        ) {
            return false
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

    private fun resolveDeveloperOptions(context: Context, usbDebugging: Boolean): Boolean {
        val key = Settings.Global.DEVELOPMENT_SETTINGS_ENABLED
        if (isGlobalSettingEnabled(context, key)) return true
        if (!readsMayBeHidden) return false
        // USB Debugging can't be on without Developer Options.
        if (usbDebugging) return true
        return remembered(context, key)
    }

    /**
     * USB functions persisted by UsbDeviceManager — lists "adb" while USB
     * Debugging is on. Falls back to whether adbd is running. Null if the
     * sandbox can't read either.
     */
    private fun adbFromSystemProperties(): Boolean? {
        val usbConfig = getSystemProperty("persist.sys.usb.config")
        if (!usbConfig.isNullOrEmpty()) {
            return usbConfig.split(',').contains("adb")
        }
        return when (getSystemProperty("init.svc.adbd")) {
            "running" -> true
            "stopped" -> false
            else -> null
        }
    }

    private fun getSystemProperty(name: String): String? {
        return try {
            val process = ProcessBuilder("getprop", name).start()
            val value = process.inputStream.bufferedReader().use { it.readLine() }
            process.waitFor()
            value?.trim()
        } catch (e: Exception) {
            Log.w(TAG, "getprop $name failed", e)
            null
        }
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
        val written = try {
            Settings.Global.putInt(context.contentResolver, key, if (enabled) 1 else 0)
        } catch (e: SecurityException) {
            Log.w(TAG, "Cannot write $key — WRITE_SECURE_SETTINGS not effective", e)
            false
        }
        if (!written) return false

        // putInt returns true even when the system drops the write, so read it
        // back — except a 0 on Android 17+, which only means "hidden".
        val readBack = isGlobalSettingEnabled(context, key)
        val applied = readBack == enabled || (enabled && readsMayBeHidden)
        if (applied) {
            remember(context, key, enabled, stampWrite = true)
        } else {
            Log.w(TAG, "System ignored write: $key=$enabled")
        }
        return applied
    }

    private fun remembered(context: Context, key: String): Boolean {
        return prefs(context).getBoolean(key, false)
    }

    private fun remember(context: Context, key: String, enabled: Boolean, stampWrite: Boolean) {
        val prefs = prefs(context)
        if (!stampWrite && prefs.getBoolean(key, false) == enabled) return
        prefs.edit().apply {
            putBoolean(key, enabled)
            if (stampWrite) putLong(KEY_LAST_WRITE_AT, System.currentTimeMillis())
            // Live ADB state also tells us Developer Options is on.
            if (!stampWrite && enabled && key == Settings.Global.ADB_ENABLED) {
                putBoolean(Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, true)
            }
        }.apply()
    }

    private fun inWriteGrace(context: Context): Boolean {
        val lastWrite = prefs(context).getLong(KEY_LAST_WRITE_AT, 0L)
        return System.currentTimeMillis() - lastWrite in 0 until WRITE_GRACE_MS
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun openSettingsIntent(context: Context, action: String) {
        val intent = Intent(action).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }
}
