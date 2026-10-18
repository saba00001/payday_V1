import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/work_object_model.dart';
import '../../models/work_day_model.dart';
import '../../models/payment_transaction_model.dart';
import '../../models/salary_period_model.dart';
import '../../models/advance_model.dart';
import '../backup/backup_document.dart';

final class LocalStorageException implements Exception {
  final String message;

  const LocalStorageException(this.message);

  @override
  String toString() => message;
}

class LocalStorageService {
  static const String _objectsKey = 'payday_objects_v1';
  static const String _workDaysKey = 'payday_workdays_v1';
  static const String _transactionsKey = 'payday_transactions_v1';
  static const String _advancesKey = 'payday_advances_v1';
  static const String _periodsKey = 'payday_periods_v1';
  static const String _dailyWageKey = 'payday_daily_wage_v1';
  static const String _reminderEnabledKey = 'payday_reminder_enabled';
  static const String _reminderHourKey = 'payday_reminder_hour';
  static const String _reminderMinuteKey = 'payday_reminder_minute';
  static const String _workScheduleKey = 'payday_work_schedule_v1';
  static const String _dataVersionKey = 'payday_data_version';
  static const String _lastBackupAtKey = 'payday_last_backup_at';
  static const String _legacyRecoveryKey = 'payday_pre_migration_backup_v1';
  static const String _preResetRecoveryKey = 'payday_pre_reset_recovery_v1';

  static const int _currentDataVersion = 2;

  SharedPreferences? _prefs;
  bool _hadExistingDataAtInitialization = false;

  bool get hadExistingDataAtInitialization => _hadExistingDataAtInitialization;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _hadExistingDataAtInitialization =
        _backupKeys.any((key) => _prefs!.get(key) != null) ||
        _prefs!.get(_legacyRecoveryKey) != null;
    await _checkDataVersion();
  }

  Future<void> resetUserData() async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _requirePrefs();
    final previousRawData = exportRawStorageState();
    try {
      if (previousRawData.isNotEmpty) {
        final recovery = jsonEncode({
          'format': 'payday-storage-recovery',
          'version': prefs.getInt(_dataVersionKey) ?? 0,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'reason': 'confirmed-user-reset',
          'data': previousRawData,
        });
        if (!await prefs.setString(_preResetRecoveryKey, recovery)) {
          throw const LocalStorageException(
            'გასუფთავებამდე მონაცემების შიდა ასლის შენახვა ვერ მოხერხდა.',
          );
        }
      }
      for (final key in _backupKeys) {
        if (!await prefs.remove(key)) {
          throw LocalStorageException(
            'მონაცემის გასუფთავება ვერ მოხერხდა ($key).',
          );
        }
      }
    } catch (error) {
      try {
        await _restoreRawStorageState(previousRawData);
      } catch (rollbackError) {
        throw LocalStorageException(
          'მონაცემების გასუფთავება და თავდაპირველი მდგომარეობის დაბრუნება '
          'ვერ მოხერხდა: $error; $rollbackError',
        );
      }
      rethrow;
    }
  }

  Future<void> _checkDataVersion() async {
    final version = _requirePrefs().getInt(_dataVersionKey) ?? 0;
    if (version < _currentDataVersion) {
      final prefs = _requirePrefs();
      final previous = <String, Object?>{
        for (final key in _backupKeys)
          if (prefs.get(key) != null) key: prefs.get(key),
      };
      if (previous.isNotEmpty) {
        final recovery = jsonEncode({
          'format': 'payday-storage-recovery',
          'version': version,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'data': previous,
        });
        if (!await prefs.setString(_legacyRecoveryKey, recovery)) {
          throw const LocalStorageException(
            'მონაცემების განახლებამდე უსაფრთხო ასლის შექმნა ვერ მოხერხდა.',
          );
        }
      }
      final saved = await _requirePrefs().setInt(
        _dataVersionKey,
        _currentDataVersion,
      );
      if (!saved) {
        throw const LocalStorageException(
          'მონაცემების ვერსიის შენახვა ვერ მოხერხდა.',
        );
      }
    }
  }

  // ── Objects ───────────────────────────────────────────────────────────
  List<WorkObjectModel> loadObjects() {
    return _decode(
      _objectsKey,
      () => WorkObjectModel.decodeList(
        _requirePrefs().getString(_objectsKey) ?? '[]',
      ),
    );
  }

  Future<void> saveObjects(List<WorkObjectModel> objects) async {
    await _setString(_objectsKey, WorkObjectModel.encodeList(objects));
  }

  // ── Work Days ─────────────────────────────────────────────────────────
  List<WorkDayModel> loadWorkDays() {
    return _decode(
      _workDaysKey,
      () => WorkDayModel.decodeList(
        _requirePrefs().getString(_workDaysKey) ?? '[]',
      ),
    );
  }

  Future<void> saveWorkDays(List<WorkDayModel> days) async {
    await _setString(_workDaysKey, WorkDayModel.encodeList(days));
  }

  // ── Transactions ──────────────────────────────────────────────────────
  List<PaymentTransactionModel> loadTransactions() {
    return _decode(
      _transactionsKey,
      () => PaymentTransactionModel.decodeList(
        _requirePrefs().getString(_transactionsKey) ?? '[]',
      ),
    );
  }

  Future<void> saveTransactions(
    List<PaymentTransactionModel> transactions,
  ) async {
    await _setString(
      _transactionsKey,
      PaymentTransactionModel.encodeList(transactions),
    );
  }

  // ── Advances ─────────────────────────────────────────────────────────
  List<AdvanceModel> loadAdvances() {
    return _decode(
      _advancesKey,
      () => AdvanceModel.decodeList(
        _requirePrefs().getString(_advancesKey) ?? '[]',
      ),
    );
  }

  Future<void> saveAdvances(List<AdvanceModel> advances) async {
    await _setString(_advancesKey, AdvanceModel.encodeList(advances));
  }

  // ── Salary Periods ────────────────────────────────────────────────────
  List<SalaryPeriodModel> loadPeriods() {
    return _decode(
      _periodsKey,
      () => SalaryPeriodModel.decodeList(
        _requirePrefs().getString(_periodsKey) ?? '[]',
      ),
    );
  }

  Future<void> savePeriods(List<SalaryPeriodModel> periods) async {
    await _setString(_periodsKey, SalaryPeriodModel.encodeList(periods));
  }

  // ── Settings ──────────────────────────────────────────────────────────
  double loadDailyWage() {
    return _decode(
      _dailyWageKey,
      () => _requirePrefs().getDouble(_dailyWageKey) ?? 80.0,
    );
  }

  Future<void> saveDailyWage(double wage) async {
    if (!wage.isFinite || wage <= 0) {
      throw const LocalStorageException('დღიური ანაზღაურება არასწორია.');
    }
    final saved = await _requirePrefs().setDouble(_dailyWageKey, wage);
    if (!saved) {
      throw const LocalStorageException('ანაზღაურების შენახვა ვერ მოხერხდა.');
    }
  }

  bool loadReminderEnabled() {
    return _decode(
      _reminderEnabledKey,
      () => _requirePrefs().getBool(_reminderEnabledKey) ?? false,
    );
  }

  Future<void> saveReminderEnabled(bool enabled) async {
    final saved = await _requirePrefs().setBool(_reminderEnabledKey, enabled);
    if (!saved) {
      throw const LocalStorageException(
        'შეხსენების პარამეტრის შენახვა ვერ მოხერხდა.',
      );
    }
  }

  int loadReminderHour() {
    return _decode(_reminderHourKey, () {
      final hour = _requirePrefs().getInt(_reminderHourKey) ?? 9;
      if (hour < 0 || hour > 23) throw const FormatException();
      return hour;
    });
  }

  int loadReminderMinute() {
    return _decode(_reminderMinuteKey, () {
      final minute = _requirePrefs().getInt(_reminderMinuteKey) ?? 0;
      if (minute < 0 || minute > 59) throw const FormatException();
      return minute;
    });
  }

  Future<void> saveReminderTime(int hour, int minute) async {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw const LocalStorageException('შეხსენების დრო არასწორია.');
    }
    final prefs = _requirePrefs();
    if (!await prefs.setInt(_reminderHourKey, hour) ||
        !await prefs.setInt(_reminderMinuteKey, minute)) {
      throw const LocalStorageException(
        'შეხსენების დროის შენახვა ვერ მოხერხდა.',
      );
    }
  }

  // Work schedule: list of weekday ints (1=Mon..7=Sun)
  List<int> loadWorkSchedule() {
    return _decode(_workScheduleKey, () {
      final stored = _requirePrefs().getStringList(_workScheduleKey);
      if (stored == null) return [1, 2, 3, 4, 5];
      final days = stored.map(int.parse).toList();
      if (days.any((day) => day < 1 || day > 7) ||
          days.toSet().length != days.length) {
        throw const FormatException();
      }
      return days;
    });
  }

  Future<void> saveWorkSchedule(List<int> days) async {
    if (days.any((day) => day < 1 || day > 7) ||
        days.toSet().length != days.length) {
      throw const LocalStorageException('სამუშაო დღეების პარამეტრი არასწორია.');
    }
    final saved = await _requirePrefs().setStringList(
      _workScheduleKey,
      days.map((day) => day.toString()).toList(),
    );
    if (!saved) {
      throw const LocalStorageException(
        'სამუშაო დღეების შენახვა ვერ მოხერხდა.',
      );
    }
  }

  DateTime? loadLastBackupAt() {
    return _decode(_lastBackupAtKey, () {
      final value = _requirePrefs().getString(_lastBackupAtKey);
      if (value == null) return null;
      final parsed = DateTime.tryParse(value);
      if (parsed == null) throw const FormatException();
      return parsed;
    });
  }

  Future<void> saveLastBackupAt(DateTime dateTime) =>
      _setString(_lastBackupAtKey, dateTime.toUtc().toIso8601String());

  Future<Map<String, Object?>> exportBackupData() async {
    final data = <String, Object?>{
      'objects': loadObjects().map((item) => item.toMap()).toList(),
      'workDays': loadWorkDays().map((item) => item.toMap()).toList(),
      'transactions': loadTransactions().map((item) => item.toMap()).toList(),
      'advances': loadAdvances().map((item) => item.toMap()).toList(),
      'periods': loadPeriods().map((item) => item.toMap()).toList(),
      'dailyWage': loadDailyWage(),
      'reminderEnabled': loadReminderEnabled(),
      'reminderHour': loadReminderHour(),
      'reminderMinute': loadReminderMinute(),
      'workSchedule': loadWorkSchedule(),
    };
    BackupDocument.validateData(data);
    return data;
  }

  Map<String, Object?> exportRawStorageState() {
    final prefs = _requirePrefs();
    return {
      for (final key in [..._backupKeys, _dataVersionKey, _legacyRecoveryKey])
        if (prefs.get(key) != null) key: prefs.get(key),
    };
  }

  Future<void> restoreBackupData(Map<String, Object?> data) async {
    BackupDocument.validateData(data);
    final previousRawData = exportRawStorageState();
    try {
      await _writeBackupData(data);
      await exportBackupData();
    } catch (error) {
      try {
        await _restoreRawStorageState(previousRawData);
      } catch (rollbackError) {
        throw LocalStorageException(
          'აღდგენა და მიმდინარე მონაცემების დაბრუნება ვერ მოხერხდა: '
          '$error; $rollbackError',
        );
      }
      throw LocalStorageException('მონაცემების აღდგენა ვერ მოხერხდა: $error');
    }
  }

  Future<void> _restoreRawStorageState(Map<String, Object?> data) async {
    final prefs = _requirePrefs();
    for (final key in _backupKeys) {
      final value = data[key];
      if (value == null) {
        if (!await prefs.remove(key)) {
          throw LocalStorageException(
            'მიმდინარე მონაცემის დაბრუნება ვერ მოხერხდა ($key).',
          );
        }
        continue;
      }
      final saved = switch (value) {
        bool value => await prefs.setBool(key, value),
        int value => await prefs.setInt(key, value),
        double value => await prefs.setDouble(key, value),
        String value => await prefs.setString(key, value),
        List<String> value => await prefs.setStringList(key, value),
        _ => throw LocalStorageException(
          'შენახული მონაცემის ტიპი უცნობია ($key).',
        ),
      };
      if (!saved) {
        throw LocalStorageException(
          'მიმდინარე მონაცემის დაბრუნება ვერ მოხერხდა ($key).',
        );
      }
    }
  }

  Future<void> _writeBackupData(Map<String, Object?> data) async {
    final prefs = _requirePrefs();
    final values = <String, Future<bool> Function()>{
      _objectsKey: () =>
          prefs.setString(_objectsKey, jsonEncode(data['objects'])),
      _workDaysKey: () =>
          prefs.setString(_workDaysKey, jsonEncode(data['workDays'])),
      _transactionsKey: () =>
          prefs.setString(_transactionsKey, jsonEncode(data['transactions'])),
      _advancesKey: () =>
          prefs.setString(_advancesKey, jsonEncode(data['advances'])),
      _periodsKey: () =>
          prefs.setString(_periodsKey, jsonEncode(data['periods'])),
      _dailyWageKey: () =>
          prefs.setDouble(_dailyWageKey, (data['dailyWage'] as num).toDouble()),
      _reminderEnabledKey: () =>
          prefs.setBool(_reminderEnabledKey, data['reminderEnabled'] as bool),
      _reminderHourKey: () =>
          prefs.setInt(_reminderHourKey, data['reminderHour'] as int),
      _reminderMinuteKey: () =>
          prefs.setInt(_reminderMinuteKey, data['reminderMinute'] as int),
      _workScheduleKey: () => prefs.setStringList(
        _workScheduleKey,
        (data['workSchedule'] as List)
            .cast<int>()
            .map((day) => day.toString())
            .toList(),
      ),
    };
    for (final write in values.values) {
      if (!await write()) {
        throw const LocalStorageException('მონაცემის ჩაწერა ვერ მოხერხდა.');
      }
    }
    if (!await prefs.remove(_lastBackupAtKey)) {
      throw const LocalStorageException(
        'ძველი backup-ის თარიღის განახლება ვერ მოხერხდა.',
      );
    }
  }

  // ── Clear All ─────────────────────────────────────────────────────────
  Future<void> clearAll() async {
    final prefs = _requirePrefs();
    for (final key in [
      _objectsKey,
      _workDaysKey,
      _transactionsKey,
      _advancesKey,
      _periodsKey,
    ]) {
      if (!await prefs.remove(key)) {
        throw const LocalStorageException('მონაცემების წაშლა ვერ მოხერხდა.');
      }
    }
  }

  SharedPreferences _requirePrefs() =>
      _prefs ??
      (throw const LocalStorageException(
        'მონაცემთა საცავი ინიციალიზებული არ არის.',
      ));

  static const _backupKeys = [
    _objectsKey,
    _workDaysKey,
    _transactionsKey,
    _advancesKey,
    _periodsKey,
    _dailyWageKey,
    _reminderEnabledKey,
    _reminderHourKey,
    _reminderMinuteKey,
    _workScheduleKey,
    _lastBackupAtKey,
  ];

  T _decode<T>(String key, T Function() decode) {
    try {
      return decode();
    } on Object catch (error) {
      if (kDebugMode) {
        final reason = error is FormatException
            ? error.message
            : error.runtimeType.toString();
        debugPrint(
          'PayDay local storage decode failed for $key '
          '($reason). Stored values are not logged.',
        );
      }
      throw LocalStorageException(
        'მონაცემები ვერ იკითხება ($key; ${error.runtimeType}).',
      );
    }
  }

  Future<void> _setString(String key, String value) async {
    final saved = await _requirePrefs().setString(key, value);
    if (!saved) {
      throw LocalStorageException('მონაცემის შენახვა ვერ მოხერხდა ($key).');
    }
  }
}
