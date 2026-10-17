package com.example.payday

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Restores the reminder alarm after device reboot.
 *
 * Hardening guarantees:
 * - Wrapped in try-catch: malformed/missing prefs never crash the receiver.
 * - Delegates to AlarmScheduler.restoreAlarmAfterBoot() which calls
 *   scheduleNextAlarm() — a no-op if reminder is disabled.
 * - Idempotent: scheduleAlarm() always cancels before re-scheduling,
 *   so duplicate alarms cannot be created even if this receiver fires twice.
 * - OFF reminder is never restored: scheduleNextAlarm() checks the
 *   REMINDER_ENABLED_KEY pref and returns early if false.
 * - Malformed prefs (invalid hour/minute) are validated in AlarmScheduler
 *   and cause a silent no-op rather than a crash.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return

        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.LOCKED_BOOT_COMPLETED" &&
            action != Intent.ACTION_TIME_CHANGED &&
            action != Intent.ACTION_TIMEZONE_CHANGED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }

        try {
            AlarmScheduler.restoreAlarmAfterBoot(context)
        } catch (_: Exception) {
            // Any error during alarm restoration must not crash the receiver.
            // The user will need to re-enable the reminder manually in this
            // unlikely scenario.
        }
    }
}
