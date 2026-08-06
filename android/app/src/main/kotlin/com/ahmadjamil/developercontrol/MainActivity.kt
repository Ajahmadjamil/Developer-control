package com.ahmadjamil.developercontrol

import android.app.StatusBarManager
import android.content.ComponentName
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor

/**
 * Platform channel bridge for Settings.Global access, Settings deep-links,
 * and prompting the user to add the Quick Settings tile.
 *
 * WRITE_SECURE_SETTINGS must be granted via ADB for write operations:
 *   adb shell pm grant com.ahmadjamil.developercontrol android.permission.WRITE_SECURE_SETTINGS
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.ahmadjamil.developercontrol/secure_settings"
        private const val TAG = "DeveloperControl"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "hasWriteSecureSettings" -> {
                            result.success(SecureSettingsHelper.hasWriteSecureSettings(this))
                        }
                        "isDeveloperOptionsEnabled" -> {
                            result.success(SecureSettingsHelper.isDeveloperOptionsEnabled(this))
                        }
                        "isUsbDebuggingEnabled" -> {
                            result.success(SecureSettingsHelper.isUsbDebuggingEnabled(this))
                        }
                        "setDeveloperOptionsEnabled" -> {
                            val enabled = call.argument<Boolean>("enabled") ?: true
                            val ok = SecureSettingsHelper.setDeveloperOptionsEnabled(this, enabled)
                            refreshQuickSettingsTile()
                            result.success(ok)
                        }
                        "setUsbDebuggingEnabled" -> {
                            val enabled = call.argument<Boolean>("enabled")
                                ?: !SecureSettingsHelper.isUsbDebuggingEnabled(this)
                            val ok = SecureSettingsHelper.setUsbDebuggingEnabled(this, enabled)
                            refreshQuickSettingsTile()
                            result.success(ok)
                        }
                        "toggleUsbDebugging" -> {
                            val currentlyEnabled =
                                SecureSettingsHelper.isUsbDebuggingEnabled(this)
                            val target = !currentlyEnabled
                            val success =
                                SecureSettingsHelper.setUsbDebuggingEnabled(this, target)
                            refreshQuickSettingsTile()
                            result.success(
                                mapOf(
                                    "success" to success,
                                    "enabled" to if (success) target else currentlyEnabled,
                                ),
                            )
                        }
                        "openDeviceInfoSettings" -> {
                            SecureSettingsHelper.openDeviceInfoSettings(this)
                            result.success(true)
                        }
                        "openDeveloperOptionsSettings" -> {
                            SecureSettingsHelper.openDeveloperOptionsSettings(this)
                            result.success(true)
                        }
                        "requestAddQuickSettingsTile" -> {
                            requestAddQuickSettingsTile(result)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: SecurityException) {
                    Log.w(TAG, "SecurityException on ${call.method}", e)
                    result.error("PERMISSION_DENIED", e.message, null)
                } catch (e: Exception) {
                    Log.e(TAG, "Error on ${call.method}", e)
                    result.error("NATIVE_ERROR", e.message, null)
                }
            }
    }

    private fun refreshQuickSettingsTile() {
        TileServiceCompat.requestListeningState(this)
    }

    private fun requestAddQuickSettingsTile(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            // Pre-Android 13: no system prompt — user must add the tile manually.
            result.success(
                mapOf(
                    "supported" to false,
                    "message" to
                        "Open Quick Settings, tap edit, and add the Dev Mode tile.",
                ),
            )
            return
        }
        requestAddTileApi33(result)
    }

    @RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private fun requestAddTileApi33(result: MethodChannel.Result) {
        val statusBarManager = getSystemService(StatusBarManager::class.java)
        if (statusBarManager == null) {
            result.success(
                mapOf(
                    "supported" to false,
                    "message" to "Status bar service unavailable on this device.",
                ),
            )
            return
        }

        val component = ComponentName(this, DeveloperModeTileService::class.java)
        val label = "Dev Mode"
        val icon = Icon.createWithResource(this, R.drawable.ic_qs_developer)
        val executor = Executor { command -> command.run() }

        statusBarManager.requestAddTileService(
            component,
            label,
            icon,
            executor,
        ) { code ->
            runOnUiThread {
                val message = when (code) {
                    StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED ->
                        "Dev Mode tile added"
                    StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED ->
                        "Dev Mode tile is already in Quick Settings"
                    StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_NOT_ADDED ->
                        "Tile was not added"
                    else -> "Could not add tile (code $code)"
                }
                result.success(
                    mapOf(
                        "supported" to true,
                        "resultCode" to code,
                        "message" to message,
                    ),
                )
            }
        }
    }
}

/** Thin wrapper so MainActivity does not need to import TileService directly for refresh. */
private object TileServiceCompat {
    fun requestListeningState(activity: MainActivity) {
        android.service.quicksettings.TileService.requestListeningState(
            activity,
            ComponentName(activity, DeveloperModeTileService::class.java),
        )
    }
}
