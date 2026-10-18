import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Flutter-side bridge to the native Android AlarmManager reminder system.
///
/// Architecture:
///   ReminderService (Dart) ↔ MethodChannel ↔ MainActivity.kt
///   ↔ AlarmScheduler.kt ↔ AlarmReceiver.kt ↔ ReminderActivity.kt
///   ↔ WorkActionReceiver.kt
///
/// On non-Android platforms all methods are no-ops (return false/null).
/// All methods catch PlatformException and MissingPluginException so the
/// app never crashes due to channel errors.
class ReminderService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.payday/alarm',
  );

  // SharedPreferences keys — must match AlarmScheduler.kt constants
  // (prefixed with "flutter." because Flutter's SharedPreferences plugin
  //  adds this prefix automatically).
  static const String _reminderEnabledKey = 'payday_reminder_enabled';
  static const String _reminderHourKey = 'payday_reminder_hour';
  static const String _reminderMinuteKey = 'payday_reminder_minute';

  // ── Schedule / Cancel ─────────────────────────────────────────────────

  /// Schedule the daily alarm at [hour]:[minute].
  ///
  /// Persists the time to SharedPreferences so BootReceiver can restore it
  /// after a device reboot without needing the Flutter app to be running.
  ///
  /// If the chosen time has already passed today, the native layer schedules
  /// for tomorrow automatically.
  ///
  /// Calling this while a reminder is already scheduled cancels the old alarm
  /// first (idempotent — no duplicate alarms).
  static Future<bool> scheduleAlarm({
    required int hour,
    required int minute,
  }) async {
    if (!_isAndroid) return false;

    // Validate inputs before persisting or sending to native.
    final safeHour = hour.clamp(0, 23);
    final safeMinute = minute.clamp(0, 59);

    try {
      // Persist first so BootReceiver can read the correct time after reboot.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_reminderEnabledKey, true);
      await prefs.setInt(_reminderHourKey, safeHour);
      await prefs.setInt(_reminderMinuteKey, safeMinute);

      final result = await _channel.invokeMethod<bool>('scheduleAlarm', {
        'hour': safeHour,
        'minute': safeMinute,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('ReminderService.scheduleAlarm PlatformException: $e');
      return false;
    } on MissingPluginException catch (e) {
      debugPrint('ReminderService.scheduleAlarm MissingPluginException: $e');
      return false;
    } catch (e) {
      debugPrint('ReminderService.scheduleAlarm error: $e');
      return false;
    }
  }

  /// Cancel the scheduled alarm and mark reminder as disabled.
  ///
  /// Uses the exact same PendingIntent identity as scheduleAlarm() so the
  /// native AlarmManager correctly cancels the pending alarm.
  ///
  /// Persists the disabled state so BootReceiver does not restore the alarm
  /// after a reboot.
  static Future<bool> cancelAlarm() async {
    if (!_isAndroid) return false;
    try {
      // Persist disabled state first so BootReceiver won't restore it.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_reminderEnabledKey, false);

      final result = await _channel.invokeMethod<bool>('cancelAlarm');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('ReminderService.cancelAlarm PlatformException: $e');
      return false;
    } on MissingPluginException catch (e) {
      debugPrint('ReminderService.cancelAlarm MissingPluginException: $e');
      return false;
    } catch (e) {
      debugPrint('ReminderService.cancelAlarm error: $e');
      return false;
    }
  }

  /// Trigger a test alarm in ~3 seconds.
  ///
  /// Uses the SAME native architecture as the real reminder:
  ///   AlarmScheduler.scheduleImmediateTest() → AlarmReceiver → ReminderActivity/notification
  ///
  /// The test alarm uses a SEPARATE PendingIntent request code (9002) so it
  /// does NOT cancel or interfere with the real scheduled alarm (9001).
  ///
  /// After the test fires, AlarmReceiver calls scheduleNextAlarm() which
  /// restores the real alarm correctly.
  ///
  /// The test does NOT modify reminder enabled state or scheduled time.
  static Future<bool> scheduleTestAlarm() async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('scheduleTestAlarm');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('ReminderService.scheduleTestAlarm PlatformException: $e');
      return false;
    } on MissingPluginException catch (e) {
      debugPrint(
        'ReminderService.scheduleTestAlarm MissingPluginException: $e',
      );
      return false;
    } catch (e) {
      debugPrint('ReminderService.scheduleTestAlarm error: $e');
      return false;
    }
  }

  // ── Permission Checks ─────────────────────────────────────────────────

  /// Returns true if the app can schedule exact alarms (Android 12+ / API 31+).
  /// Always returns true on older Android versions.
  /// Returns false (not true) on error — caller should show permission UI.
  static Future<bool> canScheduleExactAlarms() async {
    if (!_isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>(
        'canScheduleExactAlarms',
      );
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> canPostNotifications() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('canPostNotifications') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> requestNotificationPermission() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('requestPostNotifications') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // ── Settings Navigation ───────────────────────────────────────────────

  static Future<void> openExactAlarmSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('openExactAlarmSettings');
    } on PlatformException catch (e) {
      debugPrint(
        'ReminderService.openExactAlarmSettings PlatformException: $e',
      );
    } on MissingPluginException {
      // No-op on non-Android.
    } catch (e) {
      debugPrint('ReminderService.openExactAlarmSettings error: $e');
    }
  }

  static Future<void> openNotificationSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } on PlatformException catch (e) {
      debugPrint(
        'ReminderService.openNotificationSettings PlatformException: $e',
      );
    } on MissingPluginException {
      // No-op on non-Android.
    } catch (e) {
      debugPrint('ReminderService.openNotificationSettings error: $e');
    }
  }

  // ── Notification Action Result ────────────────────────────────────────

  /// Reads and clears any pending action result stored by WorkActionReceiver
  /// or ReminderActivity after the user tapped YES or NO.
  ///
  /// Returns:
  ///   "worked"     — user tapped "კი, ვიმუშავე"
  ///   "not_worked" — user tapped "არა, არ მიმუშავია"
  ///   null         — no pending result
  ///
  /// The result is consumed (cleared) on read — calling this twice returns
  /// null on the second call, preventing duplicate WorkDay creation.
  static Future<String?> getReminderActionResult() async {
    if (!_isAndroid) return null;
    try {
      final result = await _channel.invokeMethod<String?>(
        'getReminderActionResult',
      );
      return result;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> consumeReminderPrompt() async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('consumeReminderPrompt') ??
          false;
    } on PlatformException catch (error) {
      debugPrint('ReminderService.consumeReminderPrompt failed: $error');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;
}
