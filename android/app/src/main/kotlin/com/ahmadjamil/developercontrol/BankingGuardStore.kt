package com.ahmadjamil.developercontrol

import android.content.Context

/**
 * Separate prefs for Banking Guard — does not touch schedule / lock prefs.
 */
object BankingGuardStore {
    private const val PREFS = "banking_guard"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_PACKAGES = "packages"
    private const val KEY_WAS_ON = "was_on_before_bank"
    private const val KEY_IN_BANK = "currently_in_bank"
    private const val KEY_ACTIVE_PKG = "active_bank_package"

    fun isEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_ENABLED, false)

    fun setEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply()
        if (!enabled) {
            clearSession(context)
        }
    }

    fun getPackages(context: Context): Set<String> {
        return prefs(context).getStringSet(KEY_PACKAGES, emptySet())?.toSet()
            ?: emptySet()
    }

    fun setPackages(context: Context, packages: Set<String>) {
        prefs(context).edit().putStringSet(KEY_PACKAGES, packages).apply()
    }

    fun isCurrentlyInBank(context: Context): Boolean =
        prefs(context).getBoolean(KEY_IN_BANK, false)

    fun activeBankPackage(context: Context): String? =
        prefs(context).getString(KEY_ACTIVE_PKG, null)

    fun wasOnBeforeBank(context: Context): Boolean =
        prefs(context).getBoolean(KEY_WAS_ON, false)

    fun markEnteredBank(context: Context, packageName: String, wasOn: Boolean) {
        prefs(context).edit()
            .putBoolean(KEY_IN_BANK, true)
            .putString(KEY_ACTIVE_PKG, packageName)
            .putBoolean(KEY_WAS_ON, wasOn)
            .apply()
    }

    fun clearSession(context: Context) {
        prefs(context).edit()
            .putBoolean(KEY_IN_BANK, false)
            .remove(KEY_ACTIVE_PKG)
            .putBoolean(KEY_WAS_ON, false)
            .apply()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
