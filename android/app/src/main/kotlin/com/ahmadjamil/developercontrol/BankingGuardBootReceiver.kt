package com.ahmadjamil.developercontrol

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Restart Banking Guard after reboot if it was enabled. */
class BankingGuardBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> {
                if (BankingGuardStore.isEnabled(context) &&
                    BankingGuardService.hasUsageAccess(context)
                ) {
                    BankingGuardService.start(context)
                }
            }
        }
    }
}
