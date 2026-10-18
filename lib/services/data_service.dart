import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/payment_transaction_model.dart';
import '../models/advance_model.dart';
import '../models/salary_period_model.dart';
import '../models/work_day_model.dart';
import '../models/work_object_model.dart';
import './storage/local_storage_service.dart';

// ── Monthly Summary Data ──────────────────────────────────────────────────────
class ObjectMonthlySummary {
  final String objectId;
  final String objectName;
  final bool isDeleted;
  final int workedDays;
  final double earned;

  const ObjectMonthlySummary({
    required this.objectId,
    required this.objectName,
    required this.isDeleted,
    required this.workedDays,
    required this.earned,
  });
}

class MonthlySummaryData {
  final int year;
  final int month;
  final int workedDays;
  final double earned;
  final double received;
  final double advanceRepaid;
  final double remaining;
  final int paymentCount;
  final List<ObjectMonthlySummary> objectBreakdown;
  final List<PaymentTransactionModel> payments;
  final bool isEmpty;

  const MonthlySummaryData({
    required this.year,
    required this.month,
    required this.workedDays,
    required this.earned,
    required this.received,
    required this.advanceRepaid,
    required this.remaining,
    required this.paymentCount,
    required this.objectBreakdown,
    required this.payments,
    required this.isEmpty,
  });
}

class AdvanceBalance {
  final AdvanceModel advance;
  final double repaid;
  final double remaining;

  const AdvanceBalance({
    required this.advance,
    required this.repaid,
    required this.remaining,
  });
}

class _AdvanceAllocation {
  final Map<String, double> byWorkDay;
  final Map<String, double> byAdvance;

  const _AdvanceAllocation({required this.byWorkDay, required this.byAdvance});
}

class DataService {
  static final ValueNotifier<int> dataRevision = ValueNotifier<int>(0);

  static void notifyDataRestored() {
    dataRevision.value++;
  }

  final LocalStorageService _storage;
  final _uuid = const Uuid();

  List<WorkObjectModel> _objects = [];
  List<WorkDayModel> _workDays = [];
  List<PaymentTransactionModel> _transactions = [];
  List<AdvanceModel> _advances = [];
  List<SalaryPeriodModel> _periods = [];

  DataService(this._storage);

  // ── Storage accessor (for settings) ──────────────────────────────────
  LocalStorageService get storage => _storage;

  // ── Init ──────────────────────────────────────────────────────────────
  Future<void> init() async {
    await _storage.init();
    await reloadFromStorage();
  }

  Future<void> reloadFromStorage() async {
    _objects = _storage.loadObjects();
    _workDays = _storage.loadWorkDays();
    _transactions = _storage.loadTransactions();
    _advances = _storage.loadAdvances();
    _periods = _storage.loadPeriods();
    await _ensureCurrentPeriod();
  }

  Future<void> _ensureCurrentPeriod() async {
    final now = DateTime.now();
    final exists = _periods.any(
      (p) => p.year == now.year && p.month == now.month,
    );
    if (!exists) {
      final wage = _storage.loadDailyWage();
      _periods.add(
        SalaryPeriodModel(
          id: _uuid.v4(),
          year: now.year,
          month: now.month,
          dailyWage: wage,
          createdAt: now,
        ),
      );
      await _storage.savePeriods(_periods);
    }
  }

  // ── Getters ───────────────────────────────────────────────────────────
  List<WorkObjectModel> get objects => List.unmodifiable(_objects);
  List<WorkObjectModel> get activeObjects =>
      _objects.where((o) => o.status == WorkObjectStatus.active).toList();
  List<WorkObjectModel> get completedObjects =>
      _objects.where((o) => o.status == WorkObjectStatus.completed).toList();
  List<WorkDayModel> get workDays => List.unmodifiable(_workDays);
  List<PaymentTransactionModel> get transactions =>
      List.unmodifiable(_transactions);
  List<AdvanceModel> get advances => List.unmodifiable(_advances);
  List<SalaryPeriodModel> get periods => List.unmodifiable(_periods);

  // ── Objects ───────────────────────────────────────────────────────────
  Future<WorkObjectModel> createObject({
    required String name,
    String address = '',
    String note = '',
  }) async {
    final obj = WorkObjectModel(
      id: _uuid.v4(),
      name: name,
      address: address,
      note: note,
      status: WorkObjectStatus.active,
      createdAt: DateTime.now(),
    );
    _objects.add(obj);
    await _storage.saveObjects(_objects);
    return obj;
  }

  Future<void> updateObject(WorkObjectModel updated) async {
    final idx = _objects.indexWhere((o) => o.id == updated.id);
    if (idx >= 0) {
      _objects[idx] = updated;
      await _storage.saveObjects(_objects);
    }
  }

  Future<void> completeObject(String id) async {
    final idx = _objects.indexWhere((o) => o.id == id);
    if (idx >= 0) {
      _objects[idx] = _objects[idx].copyWith(
        status: WorkObjectStatus.completed,
        completedAt: DateTime.now(),
      );
      await _storage.saveObjects(_objects);
    }
  }

  /// Returns the number of WorkDay records associated with this object.
  /// Callers should warn the user before deleting if count > 0.
  int getWorkDayCountForObject(String objectId) {
    return _workDays.where((d) => d.objectId == objectId).length;
  }

  /// Deletes the object. Does NOT delete associated WorkDay records —
  /// historical data is preserved with the objectName snapshot stored in each
  /// WorkDayModel. The objectId reference becomes a dangling reference which
  /// is handled gracefully everywhere via getObjectById returning null.
  Future<void> deleteObject(String id) async {
    _objects.removeWhere((o) => o.id == id);
    await _storage.saveObjects(_objects);
  }

  WorkObjectModel? getObjectById(String id) {
    if (id.isEmpty) return null;
    try {
      return _objects.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  // Object statistics — earned is sum of worked-day wages for this object;
  // received is sum of transactions explicitly linked to this object.
  Map<String, dynamic> getObjectStats(String objectId) {
    final days = _workDays
        .where((d) => d.objectId == objectId && d.isWorked)
        .toList();
    final earned = days.fold<double>(0, (sum, d) => sum + d.dailyWage);
    final received = _transactions
        .where((t) => t.objectId == objectId)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final repaymentsByWorkDay = _advanceAllocation.byWorkDay;
    final advanceRepaid = days.fold<double>(
      0,
      (sum, day) => sum + (repaymentsByWorkDay[day.id] ?? 0),
    );
    final remaining = (earned - received - advanceRepaid).clamp(
      0.0,
      double.infinity,
    );
    return {
      'workedDays': days.length,
      'earned': earned,
      'received': received,
      'advanceRepaid': advanceRepaid,
      'remaining': remaining,
    };
  }

  // ── Work Days ─────────────────────────────────────────────────────────

  /// Returns the WorkDay for the given calendar date (date-only, ignores time).
  WorkDayModel? getWorkDayForDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    try {
      return _workDays.firstWhere((d) {
        final d2 = DateTime(d.date.year, d.date.month, d.date.day);
        return d2 == dateOnly;
      });
    } catch (_) {
      return null;
    }
  }

  /// Marks a date as worked.
  ///
  /// DUPLICATE SAFETY: ONE DATE = ONE WORKDAY RECORD.
  /// - If a worked record already exists for this date, it updates the
  ///   objectId/objectName/note but PRESERVES the stored dailyWage
  ///   (historical wage must never change).
  /// - If a non-worked record exists (notWorked/scheduled/unmarked),
  ///   it is promoted to worked and the current applicable wage is stored.
  /// - Only if no record exists at all is a new record created.
  Future<WorkDayModel> markWorked({
    required DateTime date,
    required String objectId,
    required String objectName,
    String note = '',
  }) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final existing = getWorkDayForDate(dateOnly);

    if (existing != null) {
      if (existing.isWorked) {
        // Already worked: update object/note but PRESERVE historical wage.
        final updated = existing.copyWith(
          objectId: objectId,
          objectName: objectName,
          note: note.isNotEmpty ? note : existing.note,
          updatedAt: DateTime.now(),
        );
        final idx = _workDays.indexWhere((d) => d.id == existing.id);
        _workDays[idx] = updated;
        await _storage.saveWorkDays(_workDays);
        return updated;
      } else {
        // Existing non-worked record: promote to worked, store current wage.
        final wage = getDailyWageForDate(dateOnly);
        final now = DateTime.now();
        final updated = existing.copyWith(
          status: WorkDayStatus.worked,
          objectId: objectId,
          objectName: objectName,
          dailyWage: wage,
          note: note.isNotEmpty ? note : existing.note,
          updatedAt: now,
          workedAt: now,
        );
        final idx = _workDays.indexWhere((d) => d.id == existing.id);
        _workDays[idx] = updated;
        await _storage.saveWorkDays(_workDays);
        return updated;
      }
    }

    // No record exists — create new with current applicable wage.
    final wage = getDailyWageForDate(dateOnly);
    final now = DateTime.now();
    final newDay = WorkDayModel(
      id: _uuid.v4(),
      date: dateOnly,
      status: WorkDayStatus.worked,
      objectId: objectId,
      objectName: objectName,
      dailyWage: wage,
      note: note,
      createdAt: now,
      updatedAt: now,
      workedAt: now,
    );
    _workDays.add(newDay);
    await _storage.saveWorkDays(_workDays);
    return newDay;
  }

  Future<WorkDayModel> markNotWorked(DateTime date) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final existing = getWorkDayForDate(dateOnly);
    if (existing != null) {
      final updated = existing.copyWith(
        status: WorkDayStatus.notWorked,
        updatedAt: DateTime.now(),
      );
      final idx = _workDays.indexWhere((d) => d.id == existing.id);
      _workDays[idx] = updated;
      await _storage.saveWorkDays(_workDays);
      return updated;
    }
    final newDay = WorkDayModel(
      id: _uuid.v4(),
      date: dateOnly,
      status: WorkDayStatus.notWorked,
      dailyWage: getDailyWageForDate(dateOnly),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _workDays.add(newDay);
    await _storage.saveWorkDays(_workDays);
    return newDay;
  }

  Future<void> updateWorkDayNote(String id, String note) async {
    final idx = _workDays.indexWhere((d) => d.id == id);
    if (idx >= 0) {
      _workDays[idx] = _workDays[idx].copyWith(
        note: note,
        updatedAt: DateTime.now(),
      );
      await _storage.saveWorkDays(_workDays);
    }
  }

  /// Updates an existing WorkDay record (e.g. changing objectId after
  /// object-change confirmation). Does NOT create a duplicate.
  Future<void> updateWorkDay(WorkDayModel updated) async {
    final idx = _workDays.indexWhere((d) => d.id == updated.id);
    if (idx >= 0) {
      _workDays[idx] = updated;
      await _storage.saveWorkDays(_workDays);
    }
  }

  List<WorkDayModel> getWorkDaysForMonth(int year, int month) {
    return _workDays
        .where((d) => d.date.year == year && d.date.month == month)
        .toList();
  }

  List<WorkDayModel> getWorkDaysForObject(String objectId) {
    return _workDays.where((d) => d.objectId == objectId).toList();
  }

  // ── Salary Periods ────────────────────────────────────────────────────
  SalaryPeriodModel? getPeriodForMonth(int year, int month) {
    try {
      return _periods.firstWhere((p) => p.year == year && p.month == month);
    } catch (_) {
      return null;
    }
  }

  /// Returns the daily wage applicable for a given date.
  /// Uses the SalaryPeriod for that month if it exists, otherwise falls back
  /// to the stored global daily wage setting.
  double getDailyWageForDate(DateTime date) {
    final period = getPeriodForMonth(date.year, date.month);
    return period?.dailyWage ?? _storage.loadDailyWage();
  }

  // ── Salary Calculations ───────────────────────────────────────────────
  Map<String, double> getSalaryForMonth(int year, int month) {
    final days = getWorkDaysForMonth(
      year,
      month,
    ).where((d) => d.isWorked).toList();
    final earned = days.fold<double>(0, (sum, d) => sum + d.dailyWage);
    final received = _transactions
        .where((t) {
          final dt = t.dateTime;
          return dt.year == year && dt.month == month;
        })
        .fold<double>(0, (sum, t) => sum + t.amount);
    final repaymentsByWorkDay = _advanceAllocation.byWorkDay;
    final advanceRepaid = days.fold<double>(
      0,
      (sum, day) => sum + (repaymentsByWorkDay[day.id] ?? 0),
    );
    return {
      'earned': earned,
      'received': received,
      'advanceRepaid': advanceRepaid,
      'remaining': (earned - received - advanceRepaid).clamp(
        0.0,
        double.infinity,
      ),
      'workedDays': days.length.toDouble(),
    };
  }

  Map<String, double> getTotalSalary() {
    final earned = _workDays
        .where((d) => d.isWorked)
        .fold<double>(0, (s, d) => s + d.dailyWage);
    final received = _transactions.fold<double>(0, (s, t) => s + t.amount);
    final advanceRepaid = _advanceAllocation.byWorkDay.values.fold<double>(
      0,
      (sum, amount) => sum + amount,
    );
    return {
      'earned': earned,
      'received': received,
      'advanceRepaid': advanceRepaid,
      'remaining': (earned - received - advanceRepaid).clamp(
        0.0,
        double.infinity,
      ),
    };
  }

  _AdvanceAllocation get _advanceAllocation {
    final byWorkDay = <String, double>{};
    final byAdvance = <String, double>{};
    final remainingByAdvance = {
      for (final advance in _advances) advance.id: advance.amount,
    };
    final orderedAdvances = [..._advances]
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final orderedWorkDays = _workDays.where((day) => day.isWorked).toList()
      ..sort((a, b) {
        final dateOrder = a.date.compareTo(b.date);
        return dateOrder != 0 ? dateOrder : a.createdAt.compareTo(b.createdAt);
      });

    for (final day in orderedWorkDays) {
      var wageRemaining = day.dailyWage;
      for (final advance in orderedAdvances) {
        if (wageRemaining <= 0) break;
        if (advance.objectId != day.objectId ||
            day.date.isBefore(
              DateTime(
                advance.dateTime.year,
                advance.dateTime.month,
                advance.dateTime.day,
              ),
            ) ||
            (day.workedAt ?? day.createdAt).isBefore(advance.dateTime)) {
          continue;
        }

        final advanceRemaining = remainingByAdvance[advance.id] ?? 0;
        if (advanceRemaining <= 0) continue;
        final applied = wageRemaining < advanceRemaining
            ? wageRemaining
            : advanceRemaining;
        remainingByAdvance[advance.id] = advanceRemaining - applied;
        byWorkDay.update(
          day.id,
          (amount) => amount + applied,
          ifAbsent: () => applied,
        );
        byAdvance.update(
          advance.id,
          (amount) => amount + applied,
          ifAbsent: () => applied,
        );
        wageRemaining -= applied;
      }
    }
    return _AdvanceAllocation(byWorkDay: byWorkDay, byAdvance: byAdvance);
  }

  List<AdvanceBalance> getAdvanceBalances({bool includePaid = false}) {
    final repaidByAdvance = _advanceAllocation.byAdvance;
    return _advances
        .map((advance) {
          final repaid = repaidByAdvance[advance.id] ?? 0;
          return AdvanceBalance(
            advance: advance,
            repaid: repaid,
            remaining: (advance.amount - repaid).clamp(0.0, double.infinity),
          );
        })
        .where((balance) => includePaid || balance.remaining > 0.001)
        .toList()
      ..sort((a, b) => b.advance.dateTime.compareTo(a.advance.dateTime));
  }

  List<AdvanceBalance> getAdvanceBalancesForObject(
    String objectId, {
    bool includePaid = true,
  }) {
    return getAdvanceBalances(includePaid: includePaid)
        .where((balance) => balance.advance.objectId == objectId)
        .toList();
  }

  /// Allocates recorded salary payments to the oldest eligible workdays.
  /// Payments without an object are applied across all objects; object-bound
  /// payments are restricted to workdays for that object.
  Map<String, double> get salaryPaymentAllocation {
    final advanceByWorkDay = _advanceAllocation.byWorkDay;
    final orderedDays = _workDays.where((day) => day.isWorked).toList()
      ..sort((a, b) {
        final dateOrder = a.date.compareTo(b.date);
        return dateOrder != 0 ? dateOrder : a.createdAt.compareTo(b.createdAt);
      });
    final orderedPayments = [..._transactions]
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final paidByWorkDay = <String, double>{};

    for (final payment in orderedPayments) {
      var amountRemaining = payment.amount;
      for (final day in orderedDays) {
        if (amountRemaining <= 0.001) break;
        if (_dateOnly(day.date).isAfter(_dateOnly(payment.dateTime)) ||
            (payment.objectId.isNotEmpty &&
                payment.objectId != day.objectId)) {
          continue;
        }
        final netWage = (day.dailyWage - (advanceByWorkDay[day.id] ?? 0))
            .clamp(0.0, double.infinity);
        final alreadyPaid = paidByWorkDay[day.id] ?? 0;
        final unpaid = (netWage - alreadyPaid).clamp(0.0, double.infinity);
        final applied = amountRemaining < unpaid ? amountRemaining : unpaid;
        if (applied <= 0) continue;
        paidByWorkDay[day.id] = alreadyPaid + applied;
        amountRemaining -= applied;
      }
    }
    return Map.unmodifiable(paidByWorkDay);
  }

  Map<String, double> get salaryPaymentProgress {
    final paidAmounts = salaryPaymentAllocation;
    final advanceByWorkDay = _advanceAllocation.byWorkDay;
    return Map.unmodifiable({
      for (final day in _workDays.where((day) => day.isWorked))
        if ((day.dailyWage - (advanceByWorkDay[day.id] ?? 0)) > 0)
          day.id: ((paidAmounts[day.id] ?? 0) /
                  (day.dailyWage - (advanceByWorkDay[day.id] ?? 0)))
              .clamp(0.0, 1.0),
    });
  }

  int get workedDaysSinceLastPayment {
    if (_transactions.isEmpty) {
      return _workDays.where((day) => day.isWorked).length;
    }
    final lastPayment = _transactions
        .map((transaction) => transaction.dateTime)
        .reduce((latest, date) => date.isAfter(latest) ? date : latest);
    final lastPaymentDate = _dateOnly(lastPayment);
    return _workDays
        .where(
          (day) =>
              day.isWorked && _dateOnly(day.date).isAfter(lastPaymentDate),
        )
        .length;
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  Future<AdvanceModel?> addAdvance({
    required double amount,
    required String objectId,
    DateTime? dateTime,
  }) async {
    final object = getObjectById(objectId);
    if (!amount.isFinite || amount <= 0 || object == null) {
      return null;
    }
    final advance = AdvanceModel(
      id: _uuid.v4(),
      amount: amount,
      dateTime: dateTime ?? DateTime.now(),
      objectId: object.id,
      objectName: object.name,
    );
    _advances.add(advance);
    await _storage.saveAdvances(_advances);
    return advance;
  }

  Future<void> deleteAdvance(String id) async {
    _advances.removeWhere((advance) => advance.id == id);
    await _storage.saveAdvances(_advances);
  }

  // ── Transactions ──────────────────────────────────────────────────────

  /// Adds a payment transaction.
  /// [dateTime] defaults to the current time and determines its salary period.
  ///
  /// PAYMENT VALIDATION:
  /// - amount must be > 0
  /// - amount must not exceed remaining (earned - received)
  /// - Uses strict comparison (no epsilon) to prevent overpayment
  Future<PaymentTransactionModel?> addTransaction({
    required double amount,
    DateTime? dateTime,
    String objectId = '',
    String objectName = '',
    String note = '',
  }) async {
    if (amount <= 0) return null;
    final total = getTotalSalary();
    final remaining = total['remaining']!;
    // Strict validation: amount must not exceed remaining.
    // Allow a tiny floating-point tolerance (0.001) to handle rounding.
    if (amount > remaining + 0.001) return null;

    final transactionDate = dateTime ?? DateTime.now();
    final periodId =
        getPeriodForMonth(transactionDate.year, transactionDate.month)?.id ??
        '';
    final tx = PaymentTransactionModel(
      id: _uuid.v4(),
      amount: amount,
      dateTime: transactionDate,
      salaryPeriodId: periodId,
      objectId: objectId,
      objectName: objectName,
      note: note,
    );
    _transactions.add(tx);
    await _storage.saveTransactions(_transactions);
    return tx;
  }

  Future<void> updateTransaction(PaymentTransactionModel updated) async {
    final idx = _transactions.indexWhere((t) => t.id == updated.id);
    if (idx >= 0) {
      _transactions[idx] = updated;
      await _storage.saveTransactions(_transactions);
    }
  }

  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
    await _storage.saveTransactions(_transactions);
  }

  // ── Settings ──────────────────────────────────────────────────────────
  double get currentDailyWage => _storage.loadDailyWage();

  /// Updates the daily wage.
  ///
  /// HISTORICAL WAGE PRESERVATION:
  /// - Saves the new wage as the global default.
  /// - Updates the current month's SalaryPeriod.dailyWage so that new
  ///   WorkDays created this month use the new wage.
  /// - Does NOT touch any existing WorkDay records — their stored dailyWage
  ///   is immutable once created.
  /// - Does NOT touch past months' SalaryPeriods.
  Future<void> updateDailyWage(double wage) async {
    await _storage.saveDailyWage(wage);
    final now = DateTime.now();
    final idx = _periods.indexWhere(
      (p) => p.year == now.year && p.month == now.month,
    );
    if (idx >= 0) {
      // Update existing current-month period wage.
      _periods[idx] = SalaryPeriodModel(
        id: _periods[idx].id,
        year: _periods[idx].year,
        month: _periods[idx].month,
        dailyWage: wage,
        createdAt: _periods[idx].createdAt,
      );
      await _storage.savePeriods(_periods);
    } else {
      // No period yet for this month — create one with the new wage.
      // saveDailyWage(wage) was already called above, so loadDailyWage()
      // inside _ensureCurrentPeriod() will return the new wage correctly.
      // We create the period directly here to ensure it is awaited properly.
      _periods.add(
        SalaryPeriodModel(
          id: _uuid.v4(),
          year: now.year,
          month: now.month,
          dailyWage: wage,
          createdAt: now,
        ),
      );
      await _storage.savePeriods(_periods);
    }
  }

  List<int> get workSchedule => _storage.loadWorkSchedule();

  Future<void> saveWorkSchedule(List<int> days) =>
      _storage.saveWorkSchedule(days);

  bool get reminderEnabled => _storage.loadReminderEnabled();
  int get reminderHour => _storage.loadReminderHour();
  int get reminderMinute => _storage.loadReminderMinute();

  Future<void> setReminder(bool enabled, int hour, int minute) async {
    await _storage.saveReminderEnabled(enabled);
    await _storage.saveReminderTime(hour, minute);
  }

  Future<void> clearAll() async {
    await _storage.clearAll();
    _objects = [];
    _workDays = [];
    _transactions = [];
    _advances = [];
    _periods = [];
  }

  Future<void> resetUserData() async {
    await _storage.resetUserData();
    _objects = [];
    _workDays = [];
    _transactions = [];
    _advances = [];
    _periods = [];
    await _ensureCurrentPeriod();
  }

  // ── Yesterday's Object ────────────────────────────────────────────────
  /// Returns yesterday's active object if the user worked there yesterday.
  /// Only returns active objects — completed objects are excluded.
  WorkObjectModel? getYesterdayObject() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final wd = getWorkDayForDate(yesterday);
    if (wd != null && wd.objectId.isNotEmpty) {
      final obj = getObjectById(wd.objectId);
      // Only suggest if still active
      if (obj != null && obj.status == WorkObjectStatus.active) {
        return obj;
      }
    }
    return null;
  }

  // ── Monthly Summary ───────────────────────────────────────────────────
  /// Returns a complete monthly summary for the given year/month.
  /// Uses WorkDay.dailyWage (historical snapshot) — never current wage.
  /// Payments are matched by their dateTime year+month.
  MonthlySummaryData getMonthlySummary(int year, int month) {
    final workedDays = _workDays
        .where(
          (d) => d.date.year == year && d.date.month == month && d.isWorked,
        )
        .toList();

    final earned = workedDays.fold<double>(0, (s, d) => s + d.dailyWage);

    final monthPayments =
        _transactions
            .where((t) => t.dateTime.year == year && t.dateTime.month == month)
            .toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final received = monthPayments.fold<double>(0, (s, t) => s + t.amount);
    final repaymentsByWorkDay = _advanceAllocation.byWorkDay;
    final advanceRepaid = workedDays.fold<double>(
      0,
      (sum, day) => sum + (repaymentsByWorkDay[day.id] ?? 0),
    );
    final remaining = (earned - received - advanceRepaid).clamp(
      0.0,
      double.infinity,
    );

    // Build per-object breakdown
    final Map<String, List<WorkDayModel>> byObject = {};
    for (final d in workedDays) {
      final key = d.objectId.isNotEmpty ? d.objectId : '__no_object__';
      byObject.putIfAbsent(key, () => []).add(d);
    }

    final objectBreakdown = byObject.entries.map((entry) {
      final objId = entry.key;
      final days = entry.value;
      final objEarned = days.fold<double>(0, (s, d) => s + d.dailyWage);
      // Use snapshot name from first WorkDay; resolve live name if object exists
      final liveObj = objId != '__no_object__' ? getObjectById(objId) : null;
      final isDeleted = objId != '__no_object__' && liveObj == null;
      final name =
          liveObj?.name ??
          (days.isNotEmpty && days.first.objectName.isNotEmpty
              ? days.first.objectName
              : (isDeleted ? 'წაშლილი ობიექტი' : ''));
      return ObjectMonthlySummary(
        objectId: objId,
        objectName: name,
        isDeleted: isDeleted,
        workedDays: days.length,
        earned: objEarned,
      );
    }).toList()..sort((a, b) => b.earned.compareTo(a.earned));

    final isEmpty = workedDays.isEmpty && monthPayments.isEmpty;

    return MonthlySummaryData(
      year: year,
      month: month,
      workedDays: workedDays.length,
      earned: earned,
      received: received,
      advanceRepaid: advanceRepaid,
      remaining: remaining,
      paymentCount: monthPayments.length,
      objectBreakdown: objectBreakdown,
      payments: monthPayments,
      isEmpty: isEmpty,
    );
  }
}
