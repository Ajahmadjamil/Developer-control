package com.ahmadjamil.developercontrol

import android.content.ComponentName
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.widget.Toast

/**
 * Quick Settings tile (notification shade) that toggles Developer Options
 * and USB Debugging together — same behavior as the app's combined switch.
 *
 * Add it: swipe down → edit tiles → drag "Dev Mode" into the panel.
 * Or use the in-app "Add Quick Settings tile" button (Android 13+).
 */
class DeveloperModeTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    override fun onClick() {
        super.onClick()

        if (!SecureSettingsHelper.hasWriteSecureSettings(this)) {
            showToast("Grant WRITE_SECURE_SETTINGS via ADB first")
            SecureSettingsHelper.openDeveloperOptionsSettings(this)
            updateTile()
            return
        }

        val result = SecureSettingsHelper.toggleDeveloperMode(this)
        if (result == null) {
            showToast("Could not change settings")
        } else {
            showToast(
                if (result) "Developer Mode ON" else "Developer Mode OFF",
            )
        }
        updateTile()
        // Keep any other listening tiles / panels in sync.
        requestListeningState(
            this,
            ComponentName(this, DeveloperModeTileService::class.java),
        )
    }

    private fun updateTile() {
        val tile = qsTile ?: return
        val active = SecureSettingsHelper.isDeveloperModeActive(this)
        val hasPerm = SecureSettingsHelper.hasWriteSecureSettings(this)

        tile.label = "Dev Mode"
        tile.contentDescription = "Toggle Developer Options and USB Debugging"
        tile.state = when {
            !hasPerm -> Tile.STATE_UNAVAILABLE
            active -> Tile.STATE_ACTIVE
            else -> Tile.STATE_INACTIVE
        }

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

    private fun showToast(message: String) {
        Toast.makeText(applicationContext, message, Toast.LENGTH_SHORT).show()
    }
}
