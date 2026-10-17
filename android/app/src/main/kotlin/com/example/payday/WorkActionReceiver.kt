package com.example.payday

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences

/**
 * Handles YES ("ვიმუშავე") and NO ("არ მიმუშავია") actions from the
 * reminder notification action buttons.
 *
 * This receiver only persists the user's intent to SharedPreferences.
 * The actual WorkDay creation / salary update is handled by the Flutter
 * DataService when the app next comes to the foreground, using the full
 * duplicate-prevention and idempotency logic already in place.
 *
 * This design ensures:
 * - No duplicate WorkDay is created at the native layer.
 * - The existing business rules (one date = one WorkDay, historical wage
 *   preservation, no-object graceful handling) are enforced in one place.
 * - Rapid YES taps (notification + Home button) are idempotent because
 *   DataService.markWorked() is idempotent for already-worked dates.
 */
class WorkActionReceiver : BroadcastReceiver() {

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val WORKED_KEY = "flutter.payday_reminder_action_result"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return

        try {
            when (intent.action) {
                AlarmReceiver.ACTION_WORKED -> {
                    // User confirmed work from notification.
                    // Persist "worked" so Flutter reads it on next resume.
                    // If a "worked" result is already stored (rapid double-tap),
                    // writing it again is idempotent — same value, no harm.
                    saveActionResult(context, "worked")
                }
                AlarmReceiver.ACTION_NOT_WORKED -> {
                    // User declined work from notification.
                    // Persist "not_worked" so Flutter can record the day state.
                    // Does NOT create a WorkDay or add salary at the native layer.
                    saveActionResult(context, "not_worked")
                }
                else -> {
                    // Unknown action — ignore safely.
                    return
                }
            }
        } catch (_: Exception) {
            // Any error in action handling must not crash the receiver.
        }

        // Dismiss the reminder notification regardless of which action was taken.
        try {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.cancel(AlarmReceiver.NOTIFICATION_ID)
        } catch (_: Exception) {
            // Notification dismissal failure must not crash the receiver.
        }
    }

    private fun saveActionResult(context: Context, result: String) {
        try {
            val prefs: SharedPreferences =
                context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(WORKED_KEY, result)
                .apply()
        } catch (_: Exception) {
            // Prefs write failure — fail silently.
        }
    }
}
