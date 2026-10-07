package com.ahmadjamil.developercontrol

import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor

/**
 * Platform channel bridge for Settings.Global access, Settings deep-links,
 * Quick Settings tile, and Tap to Lock Device Admin.
 *
 * WRITE_SECURE_SETTINGS must be granted via ADB for write operations:
 *   adb shell pm grant com.ahmadjamil.developercontrol android.permission.WRITE_SECURE_SETTINGS
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.ahmadjamil.developercontrol/secure_settings"
        private const val TAG = "DeveloperControl"
        private const val REQUEST_DEVICE_ADMIN = 1001
        private const val PIN_DELAY_MS = 450L
    }

    private var pendingEnableResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())

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
                        "getDeveloperModeState" -> {
                            result.success(SecureSettingsHelper.getDeveloperModeState(this))
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
                        "hasLockPermission" -> {
                            result.success(LockHelper.hasLockPermission(this))
                        }
                        // One-shot: Device Admin (if needed) → pin widget dialog
                        "enableTapToLock" -> {
                            enableTapToLock(result)
                        }
                        "requestPinLockWidget" -> {
                            result.success(LockHelper.requestPinLockWidget(this))
                        }
                        // Local Dev Mode schedule (auto on/off by time)
                        "getDevModeSchedule" -> {
                            result.success(DevModeScheduleHelper.getStatus(this))
                        }
                        "syncDevModeSchedule" -> {
                            val enabled = call.argument<Boolean>("enabled") ?: false
                            val start = call.argument<Int>("startMinutes") ?: (9 * 60)
                            val end = call.argument<Int>("endMinutes") ?: (18 * 60)
                            val applyNow = call.argument<Boolean>("applyNow") ?: true
                            val out = DevModeScheduleHelper.syncSchedule(
                                this,
                                enabled,
                                start,
                                end,
                                applyNow,
                            )
                            refreshQuickSettingsTile()
                            result.success(out)
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

    /**
     * Full Tap to Lock setup from one toggle:
     * 1) Activate Device Admin if needed (waits for Activate/Cancel)
     * 2) After a short delay (activity resumed), show the pin-widget dialog
     */
    private fun enableTapToLock(result: MethodChannel.Result) {
        if (pendingEnableResult != null) {
            result.error("BUSY", "Tap to Lock setup already in progress", null)
            return
        }

        if (LockHelper.isDeviceAdminActive(this)) {
            pinWidgetAfterResume(result)
            return
        }

        pendingEnableResult = result
        @Suppress("DEPRECATION")
        startActivityForResult(
            LockHelper.createAddDeviceAdminIntent(this),
            REQUEST_DEVICE_ADMIN,
        )
    }

    private fun pinWidgetAfterResume(result: MethodChannel.Result) {
        // Let the activity fully resume so the launcher pin dialog actually appears.
        mainHandler.postDelayed({
            if (isFinishing || isDestroyed) {
                result.success(
                    mapOf(
                        "success" to false,
                        "message" to "Could not finish setup. Try the toggle again.",
                    ),
                )
                return@postDelayed
            }
            val pin = LockHelper.requestPinLockWidget(this)
            val shown = pin["shown"] as? Boolean ?: false
            val message = (pin["message"] as? String).orEmpty()
            result.success(
                mapOf(
                    "success" to true,
                    "pinShown" to shown,
                    "message" to message,
                ),
            )
        }, PIN_DELAY_MS)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_DEVICE_ADMIN) return

        val result = pendingEnableResult
        pendingEnableResult = null
        if (result == null) return

        if (!LockHelper.isDeviceAdminActive(this)) {
            result.success(
                mapOf(
                    "success" to false,
                    "message" to "Tap Activate on the Device Admin screen to turn this on.",
                ),
            )
            return
        }

        pinWidgetAfterResume(result)
    }

    private fun refreshQuickSettingsTile() {
        TileServiceCompat.requestListeningState(this)
    }

    private fun requestAddQuickSettingsTile(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
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

private object TileServiceCompat {
    fun requestListeningState(activity: MainActivity) {
        android.service.quicksettings.TileService.requestListeningState(
            activity,
            ComponentName(activity, DeveloperModeTileService::class.java),
        )
    }
}
