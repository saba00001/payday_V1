package com.example.payday

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class AlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PayDayReminder"
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

        showReminderNotification(context)
    }

    private fun showReminderNotification(context: Context) {
        val notificationManager = NotificationManagerCompat.from(context)
        if (!notificationManager.areNotificationsEnabled()) {
            Log.w(TAG, "Reminder fired, but app notifications are disabled.")
            return
        }

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

        try {
            notificationManager.notify(NOTIFICATION_ID, builder.build())
        } catch (error: SecurityException) {
            Log.e(TAG, "Reminder notification permission was denied.", error)
        } catch (error: Exception) {
            Log.e(TAG, "Could not show reminder notification.", error)
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
            } catch (error: Exception) {
                Log.e(TAG, "Could not create reminder notification channel.", error)
            }
        }
    }
}
