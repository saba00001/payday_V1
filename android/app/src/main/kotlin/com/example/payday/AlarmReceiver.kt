package com.example.payday

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class AlarmReceiver : BroadcastReceiver() {

    companion object {
        const val CHANNEL_ID = "payday_reminder_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_WORKED = "com.payday.ACTION_WORKED"
        const val ACTION_NOT_WORKED = "com.payday.ACTION_NOT_WORKED"
    }

    override fun onReceive(context: Context, intent: Intent) {
        // Create notification channel first (idempotent on repeated calls).
        createNotificationChannel(context)

        // Reschedule for the next day BEFORE showing UI/notification.
        // This ensures the next alarm is always set even if the display step fails.
        try {
            AlarmScheduler.scheduleNextAlarm(context)
        } catch (_: Exception) {
            // Scheduling failure must not prevent the reminder from showing.
        }

        try {
            val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager

            val isLocked = keyguardManager?.isKeyguardLocked ?: true
            val isScreenOn = powerManager?.isInteractive ?: false

            if (!isLocked && isScreenOn) {
                // Phone is unlocked and screen is on — show full-screen ReminderActivity.
                showReminderActivity(context)
            } else {
                // Phone is locked or screen is off — show notification only.
                // Respects lock screen; does NOT force UI over Android lock screen.
                showReminderNotification(context)
            }
        } catch (_: Exception) {
            // Any display error — attempt notification fallback.
            try { showReminderNotification(context) } catch (_: Exception) {}
        }
    }

    private fun showReminderActivity(context: Context) {
        try {
            val activityIntent = Intent(context, ReminderActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            context.startActivity(activityIntent)
        } catch (_: Exception) {
            // Activity start failed (e.g. background activity restriction on some OEMs).
            // Fall back to notification.
            try { showReminderNotification(context) } catch (_: Exception) {}
        }
    }

    private fun showReminderNotification(context: Context) {
        // Open app on notification tap.
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPendingIntent = PendingIntent.getActivity(
            context, 100, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // YES action — handled by WorkActionReceiver.
        val workedIntent = Intent(ACTION_WORKED).apply {
            setClass(context, WorkActionReceiver::class.java)
        }
        val workedPendingIntent = PendingIntent.getBroadcast(
            context, 101, workedIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // NO action — handled by WorkActionReceiver.
        val notWorkedIntent = Intent(ACTION_NOT_WORKED).apply {
            setClass(context, WorkActionReceiver::class.java)
        }
        val notWorkedPendingIntent = PendingIntent.getBroadcast(
            context, 102, notWorkedIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("PayDay")
            .setContentText("იმუშავე დღეს?")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(openPendingIntent)
            .addAction(0, "✓ კი, ვიმუშავე", workedPendingIntent)
            .addAction(0, "არა, არ მიმუშავია", notWorkedPendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        // Full-screen intent: only set if the permission is available.
        // On Android 14+ check canUseFullScreenIntent(); on older versions always allowed.
        val canUseFsi = canUseFullScreenIntent(context)
        if (canUseFsi) {
            val fullScreenIntent = Intent(context, ReminderActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val fullScreenPendingIntent = PendingIntent.getActivity(
                context, 103, fullScreenIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.setFullScreenIntent(fullScreenPendingIntent, true)
        }

        try {
            val notificationManager = NotificationManagerCompat.from(context)
            notificationManager.notify(NOTIFICATION_ID, builder.build())
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS permission not granted — silently ignore.
            // App must not crash when notification permission is denied.
        } catch (_: Exception) {
            // Any other notification error — fail silently.
        }
    }

    /**
     * Returns true if the app is allowed to use full-screen intents.
     * On Android 14+ (API 34) this requires USE_FULL_SCREEN_INTENT permission
     * and the user may revoke it. On older versions it is always allowed.
     */
    private fun canUseFullScreenIntent(context: Context): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                nm?.canUseFullScreenIntent() ?: false
            } else {
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "PayDay შეხსენება",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "ყოველდღიური სამუშაო შეხსენება"
                    enableVibration(true)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
                val manager = context.getSystemService(NotificationManager::class.java)
                manager?.createNotificationChannel(channel)
            } catch (_: Exception) {
                // Channel creation failure must not crash the receiver.
            }
        }
    }
}
