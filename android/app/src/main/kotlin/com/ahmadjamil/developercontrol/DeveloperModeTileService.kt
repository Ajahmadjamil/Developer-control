package com.ahmadjamil.developercontrol

import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.widget.Toast

/**
 * Quick Settings tile (notification shade) that toggles Developer Options
 * and USB Debugging together — same behavior as the app's combined switch.
 *
 * Not an ACTIVE_TILE on purpose: the system rebinds each time the shade opens,
 * so the tile picks up changes made in Settings, by the schedule, or by the ROM.
 *
 * Add it: swipe down → edit tiles → drag "Dev Mode" into the panel.
 * Or use the in-app "Add Quick Settings tile" button (Android 13+).
 */
class DeveloperModeTileService : TileService() {

    companion object {
        /** Some ROMs accept the write, then flip it back a moment later. */
        private const val SETTLE_MS = 500L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var listening = false

    override fun onTileAdded() {
        super.onTileAdded()
        updateTile()
    }

    override fun onStartListening() {
        super.onStartListening()
        listening = true
        updateTile()
    }

    override fun onStopListening() {
        listening = false
        super.onStopListening()
    }

    override fun onDestroy() {
        mainHandler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun onClick() {
        super.onClick()

        if (!SecureSettingsHelper.hasWriteSecureSettings(this)) {
            showToast("Grant WRITE_SECURE_SETTINGS via ADB first")
            openAndCollapse(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
            updateTile()
            return
        }

        val target = !SecureSettingsHelper.isDeveloperModeActive(this)
        SecureSettingsHelper.setDeveloperModeEnabled(this, target)
        updateTile()

        // Report what actually stuck, not what we asked for.
        mainHandler.postDelayed({
            if (listening) updateTile()
            val active = SecureSettingsHelper.isDeveloperModeActive(this)
            showToast(
                when {
                    active != target ->
                        "Phone blocked the change — switch it in Developer options"
                    active -> "Developer Mode ON"
                    else -> "Developer Mode OFF"
                },
            )
        }, SETTLE_MS)
    }

    private fun updateTile() {
        val tile = qsTile ?: return
        val active = SecureSettingsHelper.isDeveloperModeActive(this)
        val hasPerm = SecureSettingsHelper.hasWriteSecureSettings(this)

        tile.label = "Dev Mode"
        tile.contentDescription = "Toggle Developer Options and USB Debugging"
        // Never STATE_UNAVAILABLE: SystemUI drops clicks on unavailable tiles,
        // so a missing ADB grant would leave the tile silently dead.
        tile.state = if (active) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = when {
                !hasPerm -> "Need ADB grant"
                active -> "On"
                else -> "Off"
            }
        }

        tile.icon = Icon.createWithResource(this, R.drawable.ic_qs_developer)
        tile.updateTile()
    }

    /** Plain startActivity from a tile is blocked on Android 14+; collapse instead. */
    private fun openAndCollapse(action: String) {
        val intent = Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(
                PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE),
            )
        } else {
            @Suppress("DEPRECATION", "StartActivityAndCollapseDeprecated")
            startActivityAndCollapse(intent)
        }
    }

    private fun showToast(message: String) {
        Toast.makeText(applicationContext, message, Toast.LENGTH_SHORT).show()
    }
}
