package com.ahmadjamil.developercontrol

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fires at scheduled times (and on boot) to turn Developer Mode on/off.
 * Does not fight manual toggles between alarms.
 */
class DevModeScheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            DevModeScheduleHelper.ACTION_TURN_ON -> {
                DevModeScheduleHelper.onAlarm(context, turnOn = true)
            }
            DevModeScheduleHelper.ACTION_TURN_OFF -> {
                DevModeScheduleHelper.onAlarm(context, turnOn = false)
            }
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            -> {
                DevModeScheduleHelper.rescheduleFromStorage(context)
            }
        }
    }
}
