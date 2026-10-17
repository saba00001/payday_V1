import 'package:shared_preferences/shared_preferences.dart';
import '../../models/work_object_model.dart';
import '../../models/work_day_model.dart';
import '../../models/payment_transaction_model.dart';
import '../../models/salary_period_model.dart';
import '../../models/advance_model.dart';

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

  static const int _currentDataVersion = 1;

  SharedPreferences? _prefs;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _checkDataVersion();
    } catch (e) {
      // Defensive: continue even if prefs fail
    }
  }

  Future<void> _checkDataVersion() async {
    final version = _prefs?.getInt(_dataVersionKey) ?? 0;
    if (version < _currentDataVersion) {
      await _prefs?.setInt(_dataVersionKey, _currentDataVersion);
    }
  }

  // ── Objects ───────────────────────────────────────────────────────────
  List<WorkObjectModel> loadObjects() {
    try {
      final json = _prefs?.getString(_objectsKey) ?? '[]';
      return WorkObjectModel.decodeList(json);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveObjects(List<WorkObjectModel> objects) async {
    try {
      await _prefs?.setString(_objectsKey, WorkObjectModel.encodeList(objects));
    } catch (_) {}
  }

  // ── Work Days ─────────────────────────────────────────────────────────
  List<WorkDayModel> loadWorkDays() {
    try {
      final json = _prefs?.getString(_workDaysKey) ?? '[]';
      return WorkDayModel.decodeList(json);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveWorkDays(List<WorkDayModel> days) async {
    try {
      await _prefs?.setString(_workDaysKey, WorkDayModel.encodeList(days));
    } catch (_) {}
  }

  // ── Transactions ──────────────────────────────────────────────────────
  List<PaymentTransactionModel> loadTransactions() {
    try {
      final json = _prefs?.getString(_transactionsKey) ?? '[]';
      return PaymentTransactionModel.decodeList(json);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTransactions(
    List<PaymentTransactionModel> transactions,
  ) async {
    try {
      await _prefs?.setString(
        _transactionsKey,
        PaymentTransactionModel.encodeList(transactions),
      );
    } catch (_) {}
  }

  // ── Advances ─────────────────────────────────────────────────────────
  List<AdvanceModel> loadAdvances() {
    try {
      final json = _prefs?.getString(_advancesKey) ?? '[]';
      return AdvanceModel.decodeList(json);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAdvances(List<AdvanceModel> advances) async {
    try {
      await _prefs?.setString(_advancesKey, AdvanceModel.encodeList(advances));
    } catch (_) {}
  }

  // ── Salary Periods ────────────────────────────────────────────────────
  List<SalaryPeriodModel> loadPeriods() {
    try {
      final json = _prefs?.getString(_periodsKey) ?? '[]';
      return SalaryPeriodModel.decodeList(json);
    } catch (_) {
      return [];
    }
  }

  Future<void> savePeriods(List<SalaryPeriodModel> periods) async {
    try {
      await _prefs?.setString(
        _periodsKey,
        SalaryPeriodModel.encodeList(periods),
      );
    } catch (_) {}
  }

  // ── Settings ──────────────────────────────────────────────────────────
  double loadDailyWage() {
    try {
      return _prefs?.getDouble(_dailyWageKey) ?? 80.0;
    } catch (_) {
      return 80.0;
    }
  }

  Future<void> saveDailyWage(double wage) async {
    try {
      await _prefs?.setDouble(_dailyWageKey, wage);
    } catch (_) {}
  }

  bool loadReminderEnabled() {
    try {
      return _prefs?.getBool(_reminderEnabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveReminderEnabled(bool enabled) async {
    try {
      await _prefs?.setBool(_reminderEnabledKey, enabled);
    } catch (_) {}
  }

  int loadReminderHour() {
    try {
      return _prefs?.getInt(_reminderHourKey) ?? 9;
    } catch (_) {
      return 9;
    }
  }

  int loadReminderMinute() {
    try {
      return _prefs?.getInt(_reminderMinuteKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> saveReminderTime(int hour, int minute) async {
    try {
      await _prefs?.setInt(_reminderHourKey, hour);
      await _prefs?.setInt(_reminderMinuteKey, minute);
    } catch (_) {}
  }

  // Work schedule: list of weekday ints (1=Mon..7=Sun)
  List<int> loadWorkSchedule() {
    try {
      final stored = _prefs?.getStringList(_workScheduleKey);
      if (stored == null) return [1, 2, 3, 4, 5];
      return stored.map(int.parse).toList();
    } catch (_) {
      return [1, 2, 3, 4, 5];
    }
  }

  Future<void> saveWorkSchedule(List<int> days) async {
    try {
      await _prefs?.setStringList(
        _workScheduleKey,
        days.map((d) => d.toString()).toList(),
      );
    } catch (_) {}
  }

  // ── Clear All ─────────────────────────────────────────────────────────
  Future<void> clearAll() async {
    try {
      await _prefs?.remove(_objectsKey);
      await _prefs?.remove(_workDaysKey);
      await _prefs?.remove(_transactionsKey);
      await _prefs?.remove(_advancesKey);
      await _prefs?.remove(_periodsKey);
    } catch (_) {}
  }
}
