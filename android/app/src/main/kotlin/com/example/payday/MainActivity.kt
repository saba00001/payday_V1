package com.example.payday

import android.app.Activity
import android.app.AlarmManager
import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity — Flutter host activity and MethodChannel bridge.
 *
 * MethodChannel: "com.example.payday/alarm"
 *
 * All handlers:
 * - Validate arguments before use (missing args use safe defaults).
 * - Catch all exceptions and return result.error() or safe fallback.
 * - Never crash on permission denial.
 * - Return accurate success/failure state.
 */
class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.example.payday/alarm"
    private val backupChannel = "com.example.payday/backup"
    private val createBackupRequest = 7101
    private val openBackupRequest = 7102
    private var pendingBackupResult: MethodChannel.Result? = null
    private var pendingBackupPath: String? = null
    private var pendingBackupIsExport = false
    private var pendingNotificationPermission: MethodChannel.Result? = null
    private val notificationPermissionRequest = 7103

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {

                        "scheduleAlarm" -> {
                            // Validate arguments — use safe defaults if missing.
                            val hour = call.argument<Int>("hour")?.coerceIn(0, 23) ?: 9
                            val minute = call.argument<Int>("minute")?.coerceIn(0, 59) ?: 0
                            result.success(AlarmScheduler.scheduleAlarm(this, hour, minute))
                        }

                        "cancelAlarm" -> {
                            result.success(AlarmScheduler.cancelAlarm(this))
                        }

                        "scheduleTestAlarm" -> {
                            result.success(AlarmScheduler.scheduleImmediateTest(this))
                        }

                        "canScheduleExactAlarms" -> {
                            val canSchedule = try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                    val alarmManager = getSystemService(ALARM_SERVICE) as? AlarmManager
                                    alarmManager?.canScheduleExactAlarms() ?: false
                                } else {
                                    // Below Android 12: exact alarms always available.
                                    true
                                }
                            } catch (_: Exception) {
                                false
                            }
                            result.success(canSchedule)
                        }

                        "openExactAlarmSettings" -> {
                            val opened = try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                    val intent = Intent(
                                        android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM
                                    ).apply {
                                        data = android.net.Uri.parse("package:$packageName")
                                    }
                                    startActivity(intent)
                                    true
                                } else {
                                    // Not needed below Android 12.
                                    false
                                }
                            } catch (_: Exception) {
                                false
                            }
                            result.success(opened)
                        }

                        "openNotificationSettings" -> {
                            val opened = try {
                                val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    Intent(
                                        android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS
                                    ).apply {
                                        putExtra(
                                            android.provider.Settings.EXTRA_APP_PACKAGE,
                                            packageName
                                        )
                                    }
                                } else {
                                    Intent(
                                        android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                                    ).apply {
                                        data = android.net.Uri.parse("package:$packageName")
                                    }

                                }
                                startActivity(intent)
                                true
                            } catch (_: Exception) {
                                false
                            }
                            result.success(opened)
                        }

                        "canPostNotifications" -> {
                            val runtimePermissionGranted =
                                Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                                    checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                                    android.content.pm.PackageManager.PERMISSION_GRANTED
                            val appNotificationsEnabled =
                                androidx.core.app.NotificationManagerCompat
                                    .from(this)
                                    .areNotificationsEnabled()
                            val reminderChannelEnabled =
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    val manager =
                                        getSystemService(NOTIFICATION_SERVICE)
                                            as? android.app.NotificationManager
                                    manager
                                        ?.getNotificationChannel(AlarmReceiver.CHANNEL_ID)
                                        ?.importance !=
                                        android.app.NotificationManager.IMPORTANCE_NONE
                                } else {
                                    true
                                }
                            result.success(
                                runtimePermissionGranted &&
                                    appNotificationsEnabled &&
                                    reminderChannelEnabled
                            )
                        }

                        "requestPostNotifications" -> {
                            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                                android.content.pm.PackageManager.PERMISSION_GRANTED
                            ) {
                                result.success(true)
                            } else if (pendingNotificationPermission != null) {
                                throw IllegalStateException("Notification permission request is already active")
                            } else {
                                pendingNotificationPermission = result
                                requestPermissions(
                                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                    notificationPermissionRequest
                                )
                            }
                        }

                        "getReminderActionResult" -> {
                            // Read and clear the pending action result stored by
                            // WorkActionReceiver or ReminderActivity.
                            // Returns "worked", "not_worked", or null.
                            val actionResult = try {
                                val prefs = getSharedPreferences(
                                    "FlutterSharedPreferences", MODE_PRIVATE
                                )
                                val value = prefs.getString(
                                    "flutter.payday_reminder_action_result", null
                                )
                                if (value != null) {
                                    // Clear after reading — consume once.
                                    prefs.edit()
                                        .remove("flutter.payday_reminder_action_result")
                                        .apply()
                                }
                                value
                            } catch (_: Exception) {
                                null
                            }
                            result.success(actionResult)
                        }

                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    // Top-level catch: no MethodChannel call should ever crash the app.
                    result.error("UNEXPECTED_ERROR", e.message ?: "Unknown error", null)
                }
            }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.payday/updater"
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getInstalledVersion" -> {
                        @Suppress("DEPRECATION")
                        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            packageManager.getPackageInfo(
                                packageName,
                                android.content.pm.PackageManager.PackageInfoFlags.of(0)
                            )
                        } else {
                            packageManager.getPackageInfo(packageName, 0)
                        }
                        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            packageInfo.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            packageInfo.versionCode.toLong()
                        }
                        result.success("${packageInfo.versionName}+$versionCode")
                    }

                    "getUpdateDirectory" -> {
                        val directory = File(cacheDir, "updates")
                        if (!directory.exists() && !directory.mkdirs()) {
                            throw IllegalStateException("Could not create update cache")
                        }
                        result.success(directory.canonicalPath)
                    }

                    "canInstallUnknownApps" -> {
                        result.success(
                            Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                                packageManager.canRequestPackageInstalls()
                        )
                    }

                    "openInstallPermissionSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName")
                                )
                            )
                        }
                        result.success(null)
                    }

                    "installApk" -> {
                        val rawPath = call.argument<String>("path")
                            ?: throw IllegalArgumentException("Missing APK path")
                        val updateDirectory = File(cacheDir, "updates").canonicalFile
                        val apk = File(rawPath).canonicalFile
                        if (!apk.path.startsWith(updateDirectory.path + File.separator) ||
                            apk.extension.lowercase() != "apk" ||
                            !apk.isFile ||
                            apk.length() == 0L
                        ) {
                            throw IllegalArgumentException("Invalid update APK")
                        }
                        val apkUri = FileProvider.getUriForFile(
                            this,
                            "$packageName.updateprovider",
                            apk
                        )
                        val installIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(
                                apkUri,
                                "application/vnd.android.package-archive"
                            )
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(installIntent)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error(
                    "UPDATE_BRIDGE_ERROR",
                    error.message ?: "Android update operation failed",
                    null
                )
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backupChannel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getTransferDirectory" -> {
                            val directory = File(cacheDir, "payday-backup-transfer")
                            if (!directory.exists() && !directory.mkdirs()) {
                                throw IllegalStateException("Could not create backup transfer directory")
                            }
                            result.success(directory.canonicalPath)
                        }
                        "getInternalBackupDirectory" -> {
                            val directory = File(filesDir, "backup-snapshots")
                            if (!directory.exists() && !directory.mkdirs()) {
                                throw IllegalStateException("Could not create backup snapshot directory")
                            }
                            result.success(directory.canonicalPath)
                        }
                        "saveBackupFile" -> {
                            val rawPath = call.argument<String>("path")
                                ?: throw IllegalArgumentException("Missing backup path")
                            val transferDirectory = File(
                                cacheDir,
                                "payday-backup-transfer"
                            ).canonicalFile
                            val backupFile = File(rawPath).canonicalFile
                            if (!backupFile.path.startsWith(
                                    transferDirectory.path + File.separator
                                ) || !backupFile.isFile || backupFile.length() == 0L
                            ) {
                                throw IllegalArgumentException("Invalid backup file")
                            }
                            if (pendingBackupResult != null) {
                                throw IllegalStateException("A backup file picker is already open")
                            }
                            pendingBackupResult = result
                            pendingBackupPath = backupFile.path
                            pendingBackupIsExport = true
                            startActivityForResult(
                                Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = "application/json"
                                    putExtra(
                                        Intent.EXTRA_TITLE,
                                        "PayDay-Backup-${System.currentTimeMillis()}.paydaybackup"
                                    )
                                },
                                createBackupRequest
                            )
                        }
                        "selectBackupFile" -> {
                            if (pendingBackupResult != null) {
                                throw IllegalStateException("A backup file picker is already open")
                            }
                            pendingBackupResult = result
                            pendingBackupPath = null
                            pendingBackupIsExport = false
                            startActivityForResult(
                                Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = "*/*"
                                    putExtra(
                                        Intent.EXTRA_MIME_TYPES,
                                        arrayOf("application/json", "application/octet-stream")
                                    )
                                },
                                openBackupRequest
                            )
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error(
                        "BACKUP_BRIDGE_ERROR",
                        error.message ?: "Backup file operation failed",
                        null
                    )
                }
            }
    }

    @Deprecated("Deprecated in Android API")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != notificationPermissionRequest) return
        val result = pendingNotificationPermission ?: return
        pendingNotificationPermission = null
        result.success(
            grantResults.firstOrNull() ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
        )
    }

    @Deprecated("Deprecated in Android API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != createBackupRequest && requestCode != openBackupRequest) {
            return
        }
        val result = pendingBackupResult ?: return
        val path = pendingBackupPath
        val isExport = pendingBackupIsExport
        pendingBackupResult = null
        pendingBackupPath = null
        pendingBackupIsExport = false

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            if (isExport) result.success(false) else result.success(null)
            return
        }

        try {
            val uri = data.data!!
            if (isExport) {
                val source = path?.let { File(it) }
                    ?: throw IllegalStateException("Backup export file is missing")
                val copied = contentResolver.openOutputStream(uri, "wt")?.use { output ->
                    val count = source.inputStream().use { input -> input.copyTo(output) }
                    output.flush()
                    count
                } ?: throw IllegalStateException("Could not open selected destination")
                if (source.length() == 0L || copied != source.length()) {
                    throw IllegalStateException("Backup file was not completely written")
                }
                source.delete()
                result.success(true)
            } else {
                val directory = File(cacheDir, "payday-backup-transfer")
                if (!directory.exists() && !directory.mkdirs()) {
                    throw IllegalStateException("Could not create backup transfer directory")
                }
                val destination = File(directory, "payday-selected-backup.paydaybackup")
                contentResolver.openInputStream(uri)?.use { input ->
                    destination.outputStream().use { output ->
                        val buffer = ByteArray(8192)
                        var total = 0L
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            total += count
                            if (total > 20L * 1024 * 1024) {
                                throw IllegalArgumentException("Backup exceeds 20 MB")
                            }
                            output.write(buffer, 0, count)
                        }
                    }
                } ?: throw IllegalStateException("Could not read selected backup")
                if (destination.length() == 0L) {
                    throw IllegalArgumentException("Selected backup is empty")
                }
                result.success(destination.canonicalPath)
            }
        } catch (error: Exception) {
            result.error(
                "BACKUP_FILE_ERROR",
                error.message ?: "Backup file operation failed",
                null
            )
        }
    }
}
