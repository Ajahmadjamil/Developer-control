package com.ahmadjamil.developercontrol

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar

/**
 * Local daily schedule for Developer Mode (Options + USB Debugging).
 *
 * Alarms only fire at start/end times — manual toggles (app / QS tile)
 * are kept until the next scheduled on/off.
 */
object DevModeScheduleHelper {
    private const val TAG = "DevModeSchedule"
    private const val PREFS = "dev_mode_schedule"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_START = "start_minutes"
    private const val KEY_END = "end_minutes"

    const val ACTION_TURN_ON = "com.ahmadjamil.developercontrol.ACTION_SCHEDULE_TURN_ON"
    const val ACTION_TURN_OFF = "com.ahmadjamil.developercontrol.ACTION_SCHEDULE_TURN_OFF"

    private const val REQ_ON = 2001
    private const val REQ_OFF = 2002

    /** Default 09:00 → 18:00 */
    private const val DEFAULT_START = 9 * 60
    private const val DEFAULT_END = 18 * 60

    fun isEnabled(context: Context): Boolean {
        return prefs(context).getBoolean(KEY_ENABLED, false)
    }

    fun startMinutes(context: Context): Int {
        return prefs(context).getInt(KEY_START, DEFAULT_START)
    }

    fun endMinutes(context: Context): Int {
        return prefs(context).getInt(KEY_END, DEFAULT_END)
    }

    /**
     * Saves schedule, (re)arms alarms, and applies the expected state once.
     * After that, only alarms change state — manual overrides stick until then.
     */
    fun syncSchedule(
        context: Context,
        enabled: Boolean,
        startMinutes: Int,
        endMinutes: Int,
        applyNow: Boolean = true,
    ): Map<String, Any?> {
        val start = startMinutes.coerceIn(0, 24 * 60 - 1)
        val end = endMinutes.coerceIn(0, 24 * 60 - 1)

        if (enabled && start == end) {
            return mapOf(
                "ok" to false,
                "enabled" to isEnabled(context),
                "startMinutes" to start,
                "endMinutes" to end,
                "message" to "Start and end time must be different",
            )
        }

        prefs(context).edit()
            .putBoolean(KEY_ENABLED, enabled)
            .putInt(KEY_START, start)
            .putInt(KEY_END, end)
            .apply()

        cancelAlarms(context)

        if (!enabled) {
            return mapOf(
                "ok" to true,
                "enabled" to false,
                "startMinutes" to start,
                "endMinutes" to end,
                "message" to "Schedule off",
            )
        }

        scheduleNextAlarms(context)

        var applied: Boolean? = null
        if (applyNow) {
            val shouldBeOn = isInsideWindow(nowMinutes(), start, end)
            applied = SecureSettingsHelper.setDeveloperModeEnabled(context, shouldBeOn)
            refreshTile(context)
        }

        return mapOf(
            "ok" to true,
            "enabled" to true,
            "startMinutes" to start,
            "endMinutes" to end,
            "insideWindow" to isInsideWindow(nowMinutes(), start, end),
            "applied" to applied,
            "message" to "Schedule armed",
        )
    }

    fun rescheduleFromStorage(context: Context) {
        if (!isEnabled(context)) {
            cancelAlarms(context)
            return
        }
        val start = startMinutes(context)
        val end = endMinutes(context)
        if (start == end) return
        scheduleNextAlarms(context)
    }

    /** Called by [DevModeScheduleReceiver] at alarm time. */
    fun onAlarm(context: Context, turnOn: Boolean) {
        if (!isEnabled(context)) return

        if (!SecureSettingsHelper.hasWriteSecureSettings(context)) {
            Log.w(TAG, "Schedule alarm fired but WRITE_SECURE_SETTINGS missing")
            scheduleNextAlarms(context)
            return
        }

        // Don't force Dev Mode ON while a banking app is in the foreground.
        if (turnOn && BankingGuardStore.isCurrentlyInBank(context)) {
            Log.i(TAG, "Scheduled ON skipped — banking app is open")
            scheduleNextAlarms(context)
            return
        }

        // If schedule turns OFF during a bank session, don't restore ON on exit.
        if (!turnOn && BankingGuardStore.isCurrentlyInBank(context)) {
            val pkg = BankingGuardStore.activeBankPackage(context) ?: ""
            BankingGuardStore.markEnteredBank(context, pkg, wasOn = false)
        }

        SecureSettingsHelper.setDeveloperModeEnabled(context, turnOn)
        refreshTile(context)
        scheduleNextAlarms(context)
        Log.i(TAG, if (turnOn) "Scheduled Dev Mode ON" else "Scheduled Dev Mode OFF")
    }

    fun getStatus(context: Context): Map<String, Any?> {
        val enabled = isEnabled(context)
        val start = startMinutes(context)
        val end = endMinutes(context)
        return mapOf(
            "enabled" to enabled,
            "startMinutes" to start,
            "endMinutes" to end,
            "insideWindow" to if (enabled) isInsideWindow(nowMinutes(), start, end) else false,
            "canScheduleExact" to canScheduleExact(context),
        )
    }

    private fun scheduleNextAlarms(context: Context) {
        val start = startMinutes(context)
        val end = endMinutes(context)
        val nextOn = nextTriggerMillis(start)
        val nextOff = nextTriggerMillis(end)
        setAlarm(context, nextOn, ACTION_TURN_ON, REQ_ON)
        setAlarm(context, nextOff, ACTION_TURN_OFF, REQ_OFF)
        Log.i(TAG, "Next ON in ${(nextOn - System.currentTimeMillis()) / 1000}s, OFF in ${(nextOff - System.currentTimeMillis()) / 1000}s")
    }

    private fun setAlarm(context: Context, triggerAt: Long, action: String, requestCode: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, DevModeScheduleReceiver::class.java).setAction(action)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pi = PendingIntent.getBroadcast(context, requestCode, intent, flags)

        try {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    if (canScheduleExact(context)) {
                        am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
                    } else {
                        // Still try — some devices allow it; otherwise inexact.
                        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
                    }
                }
                else -> am.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Exact alarm blocked, falling back", e)
            am.set(AlarmManager.RTC_WAKEUP, triggerAt, pi)
        }
    }

    private fun cancelAlarms(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        for ((action, code) in listOf(ACTION_TURN_ON to REQ_ON, ACTION_TURN_OFF to REQ_OFF)) {
            val intent = Intent(context, DevModeScheduleReceiver::class.java).setAction(action)
            val pi = PendingIntent.getBroadcast(context, code, intent, flags)
            am.cancel(pi)
        }
    }

    fun isInsideWindow(nowMinutes: Int, start: Int, end: Int): Boolean {
        return if (start < end) {
            nowMinutes in start until end
        } else {
            // Overnight window, e.g. 22:00 → 08:00
            nowMinutes >= start || nowMinutes < end
        }
    }

    private fun nextTriggerMillis(minuteOfDay: Int): Long {
        val cal = Calendar.getInstance().apply {
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            set(Calendar.HOUR_OF_DAY, minuteOfDay / 60)
            set(Calendar.MINUTE, minuteOfDay % 60)
            if (timeInMillis <= System.currentTimeMillis()) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }
        return cal.timeInMillis
    }

    private fun nowMinutes(): Int {
        val cal = Calendar.getInstance()
        return cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
    }

    private fun canScheduleExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return am.canScheduleExactAlarms()
    }

    private fun refreshTile(context: Context) {
        try {
            android.service.quicksettings.TileService.requestListeningState(
                context,
                ComponentName(context, DeveloperModeTileService::class.java),
            )
        } catch (_: Exception) {
            // Tile may not be added yet
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
