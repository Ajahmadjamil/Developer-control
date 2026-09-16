package com.ahmadjamil.developercontrol

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast

/**
 * Device admin receiver — fallback lock via DevicePolicyManager.lockNow().
 * Some devices may require unlock with PIN/password after this (not biometrics).
 */
class LockDeviceAdminReceiver : DeviceAdminReceiver() {

    override fun onEnabled(context: Context, intent: Intent) {
        Toast.makeText(context, "Device Admin enabled for Tap to Lock", Toast.LENGTH_SHORT).show()
    }

    override fun onDisabled(context: Context, intent: Intent) {
        Toast.makeText(context, "Device Admin disabled", Toast.LENGTH_SHORT).show()
    }
}
