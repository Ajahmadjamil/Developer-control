package com.ahmadjamil.developercontrol

import android.app.AppOpsManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Process
import android.provider.Settings
import android.util.Log

/**
 * Watches the foreground app via Usage Access.
 * Banking app opens → Dev Mode OFF (remember prior state).
 * Banking app closes → restore Dev Mode if it was on before.
 */
class BankingGuardService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var lastTop: String? = null

    private val tick = object : Runnable {
        override fun run() {
            try {
                poll()
            } catch (e: Exception) {
                Log.w(TAG, "poll failed", e)
            }
            handler.postDelayed(this, POLL_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startAsForeground()
        handler.removeCallbacks(tick)
        handler.post(tick)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        if (BankingGuardStore.isCurrentlyInBank(this)) {
            leaveBankIfNeeded()
        }
        super.onDestroy()
    }

    private fun poll() {
        if (!BankingGuardStore.isEnabled(this)) {
            stopSelf()
            return
        }
        if (!hasUsageAccess(this)) return

        val top = currentForegroundPackage() ?: return
        if (top == lastTop) return
        lastTop = top

        val watched = BankingGuardStore.getPackages(this)
        val inBank = top in watched
        val wasInBank = BankingGuardStore.isCurrentlyInBank(this)

        when {
            inBank && !wasInBank -> enterBank(top)
            !inBank && wasInBank -> leaveBankIfNeeded()
        }
    }

    private fun enterBank(packageName: String) {
        val wasOn = SecureSettingsHelper.isDeveloperModeActive(this)
        BankingGuardStore.markEnteredBank(this, packageName, wasOn)
        if (wasOn) {
            SecureSettingsHelper.setDeveloperModeEnabled(this, false)
            refreshTile()
            Log.i(TAG, "Bank opened ($packageName) — Dev Mode OFF (was on)")
        } else {
            Log.i(TAG, "Bank opened ($packageName) — Dev Mode already off")
        }
        updateNotification("Banking app open — Dev Mode off")
    }

    private fun leaveBankIfNeeded() {
        if (!BankingGuardStore.isCurrentlyInBank(this)) return
        val wasOn = BankingGuardStore.wasOnBeforeBank(this)
        BankingGuardStore.clearSession(this)
        if (wasOn) {
            SecureSettingsHelper.setDeveloperModeEnabled(this, true)
            refreshTile()
            Log.i(TAG, "Left bank — Dev Mode restored ON")
        } else {
            Log.i(TAG, "Left bank — left Dev Mode OFF")
        }
        updateNotification("Watching banking apps")
    }

    private fun currentForegroundPackage(): String? {
        val usm = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val begin = end - 15_000
        val events = usm.queryEvents(begin, end)
        val event = UsageEvents.Event()
        var lastMoveToFg: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                lastMoveToFg = event.packageName
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED
            ) {
                lastMoveToFg = event.packageName
            }
        }
        return lastMoveToFg
    }

    private fun startAsForeground() {
        ensureChannel()
        val pending = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        startForeground(NOTIF_ID, buildNotification("Watching banking apps", pending))
    }

    private fun updateNotification(text: String) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val pending = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        nm.notify(NOTIF_ID, buildNotification(text, pending))
    }

    private fun buildNotification(text: String, contentIntent: PendingIntent): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Banking Guard")
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Banking Guard",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps Dev Mode off while banking apps are open"
            },
        )
    }

    private fun refreshTile() {
        try {
            android.service.quicksettings.TileService.requestListeningState(
                this,
                ComponentName(this, DeveloperModeTileService::class.java),
            )
        } catch (_: Exception) {
        }
    }

    companion object {
        private const val TAG = "BankingGuard"
        private const val POLL_MS = 1000L
        private const val NOTIF_ID = 4201
        private const val CHANNEL_ID = "banking_guard"

        fun hasUsageAccess(context: Context): Boolean {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName,
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName,
                )
            }
            return mode == AppOpsManager.MODE_ALLOWED
        }

        fun openUsageAccessSettings(context: Context) {
            context.startActivity(
                Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
            )
        }

        fun start(context: Context) {
            val intent = Intent(context, BankingGuardService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, BankingGuardService::class.java))
        }

        fun syncEnabled(context: Context, enabled: Boolean): Map<String, Any?> {
            if (enabled && !SecureSettingsHelper.hasWriteSecureSettings(context)) {
                return mapOf(
                    "ok" to false,
                    "enabled" to false,
                    "message" to "Grant WRITE_SECURE_SETTINGS via ADB first",
                )
            }
            if (enabled && !hasUsageAccess(context)) {
                return mapOf(
                    "ok" to false,
                    "enabled" to false,
                    "needsUsageAccess" to true,
                    "message" to "Allow Usage Access for Developer Control",
                )
            }
            if (enabled && BankingGuardStore.getPackages(context).isEmpty()) {
                return mapOf(
                    "ok" to false,
                    "enabled" to false,
                    "message" to "Pick at least one banking app first",
                )
            }

            BankingGuardStore.setEnabled(context, enabled)
            if (enabled) {
                start(context)
            } else {
                if (BankingGuardStore.isCurrentlyInBank(context) &&
                    BankingGuardStore.wasOnBeforeBank(context)
                ) {
                    SecureSettingsHelper.setDeveloperModeEnabled(context, true)
                }
                BankingGuardStore.clearSession(context)
                stop(context)
            }
            return mapOf(
                "ok" to true,
                "enabled" to enabled,
                "message" to if (enabled) "Banking Guard on" else "Banking Guard off",
            )
        }

        fun status(context: Context): Map<String, Any?> {
            return mapOf(
                "enabled" to BankingGuardStore.isEnabled(context),
                "hasUsageAccess" to hasUsageAccess(context),
                "packages" to BankingGuardStore.getPackages(context).toList(),
                "inBank" to BankingGuardStore.isCurrentlyInBank(context),
                "activePackage" to BankingGuardStore.activeBankPackage(context),
            )
        }

        fun listLaunchableApps(context: Context): List<Map<String, String>> {
            val pm = context.packageManager
            val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            val activities = pm.queryIntentActivities(intent, PackageManager.MATCH_ALL)
            val self = context.packageName
            return activities
                .mapNotNull { info ->
                    val pkg = info.activityInfo.packageName
                    if (pkg == self) return@mapNotNull null
                    val appInfo: ApplicationInfo = try {
                        pm.getApplicationInfo(pkg, 0)
                    } catch (_: Exception) {
                        return@mapNotNull null
                    }
                    val label = pm.getApplicationLabel(appInfo).toString()
                    mapOf("packageName" to pkg, "label" to label)
                }
                .distinctBy { it["packageName"] }
                .sortedBy { it["label"]?.lowercase() }
        }
    }
}
