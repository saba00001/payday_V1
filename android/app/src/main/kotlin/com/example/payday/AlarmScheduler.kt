package com.example.payday

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import java.util.Calendar

object AlarmScheduler {

    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val REMINDER_ENABLED_KEY = "flutter.payday_reminder_enabled"
    private const val REMINDER_HOUR_KEY = "flutter.payday_reminder_hour"
    private const val REMINDER_MINUTE_KEY = "flutter.payday_reminder_minute"

    // Real alarm uses a fixed request code — always the same identity so
    // cancel/update/reschedule all operate on the same PendingIntent.
    private const val ALARM_REQUEST_CODE = 9001

    // Test alarm uses a DIFFERENT request code so it never cancels or
    // interferes with the real scheduled alarm.
    private const val TEST_ALARM_REQUEST_CODE = 9002

    // ── Public API ────────────────────────────────────────────────────────

    /**
     * Schedule the daily reminder alarm at [hour]:[minute].
     * Cancels any existing real alarm first to prevent duplicates.
     * If the chosen time has already passed today, schedules for tomorrow.
     */
    fun scheduleAlarm(context: Context, hour: Int, minute: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pendingIntent = buildPendingIntent(context, ALARM_REQUEST_CODE) ?: return

        // Cancel existing real alarm before scheduling new one (idempotent).
        try { alarmManager.cancel(pendingIntent) } catch (_: Exception) {}

        val triggerMillis = computeNextTriggerMillis(hour, minute)

        setAlarm(alarmManager, triggerMillis, pendingIntent)
    }

    /**
     * Cancel the real scheduled alarm.
     * Uses the exact same PendingIntent identity as scheduleAlarm().
     */
    fun cancelAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pendingIntent = buildPendingIntent(context, ALARM_REQUEST_CODE) ?: return
        try { alarmManager.cancel(pendingIntent) } catch (_: Exception) {}
    }

    /**
     * Reschedule the real alarm using stored preferences.
     * Called from AlarmReceiver (after firing) and BootReceiver.
     * No-op if reminder is disabled or prefs are missing/malformed.
     */
    fun scheduleNextAlarm(context: Context) {
        try {
            val prefs = getPrefs(context)
            val enabled = prefs.getBoolean(REMINDER_ENABLED_KEY, false)
            if (!enabled) return

            val hour = prefs.getInt(REMINDER_HOUR_KEY, 9)
            val minute = prefs.getInt(REMINDER_MINUTE_KEY, 0)

            // Validate hour/minute ranges to guard against corrupted prefs.
            if (hour !in 0..23 || minute !in 0..59) return

            scheduleAlarm(context, hour, minute)
        } catch (_: Exception) {
            // Malformed prefs or system service unavailable — fail silently.
        }
    }

    /**
     * Restore alarm after device reboot.
     * Idempotent: scheduleAlarm() always cancels before re-scheduling.
     */
    fun restoreAlarmAfterBoot(context: Context) {
        scheduleNextAlarm(context)
    }

    /**
     * Schedule a test alarm ~3 seconds from now.
     * Uses a SEPARATE request code so it never cancels the real alarm.
     * After the test fires, AlarmReceiver calls scheduleNextAlarm() which
     * restores the real alarm correctly.
     */
    fun scheduleImmediateTest(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        // Use TEST_ALARM_REQUEST_CODE — completely separate from real alarm.
        val pendingIntent = buildPendingIntent(context, TEST_ALARM_REQUEST_CODE) ?: return

        val triggerTime = System.currentTimeMillis() + 3_000L

        setAlarm(alarmManager, triggerTime, pendingIntent)
    }

    // ── Private helpers ───────────────────────────────────────────────────

    /**
     * Compute the next trigger time for [hour]:[minute].
     * If the time has already passed today (or is within the current second),
     * schedule for tomorrow. Uses date-only comparison to avoid sub-second
     * drift causing the alarm to fire immediately.
     */
    private fun computeNextTriggerMillis(hour: Int, minute: Int): Long {
        val now = System.currentTimeMillis()
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        // If the computed time is not strictly in the future, advance by one day.
        if (cal.timeInMillis <= now) {
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        return cal.timeInMillis
    }

    /**
     * Set the alarm using the best available API for the current Android version.
     * Gracefully falls back to inexact alarm if exact alarm permission is denied.
     */
    private fun setAlarm(alarmManager: AlarmManager, triggerMillis: Long, pendingIntent: PendingIntent) {
        try {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP, triggerMillis, pendingIntent
                        )
                    } else {
                        // Exact alarm permission not granted — use inexact fallback.
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP, triggerMillis, pendingIntent
                        )
                    }
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, triggerMillis, pendingIntent
                    )
                }
                else -> {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP, triggerMillis, pendingIntent
                    )
                }
            }
        } catch (_: SecurityException) {
            // Exact alarm permission denied — fall back to inexact.
            try {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerMillis, pendingIntent)
            } catch (_: Exception) {
                // System service unavailable — fail silently.
            }
        } catch (_: Exception) {
            // Any other scheduling error — fail silently.
        }
    }

    /**
     * Build a PendingIntent for AlarmReceiver with the given [requestCode].
     * Using FLAG_UPDATE_CURRENT ensures the same logical alarm is updated
     * rather than creating a new one. FLAG_IMMUTABLE is required on Android 12+.
     */
    private fun buildPendingIntent(context: Context, requestCode: Int): PendingIntent? {
        return try {
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = "com.payday.ALARM_TRIGGER"
            }
            PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun getPrefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
