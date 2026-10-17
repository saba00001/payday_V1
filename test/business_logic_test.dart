// PayDay — Business Logic Unit Tests
// Tests critical rules without requiring a device or Flutter UI.

import 'package:flutter_test/flutter_test.dart';

import 'package:payday/models/work_day_model.dart';
import 'package:payday/models/work_object_model.dart';
import 'package:payday/models/payment_transaction_model.dart';
import 'package:payday/models/advance_model.dart';
import 'package:payday/models/salary_period_model.dart';
import 'package:payday/services/data_service.dart';
import 'package:payday/services/storage/local_storage_service.dart';

// ── Fake storage that operates entirely in memory ─────────────────────────────
class _FakeStorage extends LocalStorageService {
  double _wage = 80.0;
  bool _reminderEnabled = false;
  int _reminderHour = 9;
  int _reminderMinute = 0;
  final List<int> _schedule = [1, 2, 3, 4, 5];

  final List<WorkObjectModel> _objects = [];
  final List<WorkDayModel> _workDays = [];
  final List<PaymentTransactionModel> _transactions = [];
  final List<AdvanceModel> _advances = [];
  final List<SalaryPeriodModel> _periods = [];

  @override
  Future<void> init() async {}

  @override
  List<WorkObjectModel> loadObjects() => List.from(_objects);
  @override
  Future<void> saveObjects(List<WorkObjectModel> objects) async {
    _objects
      ..clear()
      ..addAll(objects);
  }

  @override
  List<WorkDayModel> loadWorkDays() => List.from(_workDays);
  @override
  Future<void> saveWorkDays(List<WorkDayModel> days) async {
    _workDays
      ..clear()
      ..addAll(days);
  }

  @override
  List<PaymentTransactionModel> loadTransactions() => List.from(_transactions);
  @override
  Future<void> saveTransactions(
    List<PaymentTransactionModel> transactions,
  ) async {
    _transactions
      ..clear()
      ..addAll(transactions);
  }

  @override
  List<AdvanceModel> loadAdvances() => List.from(_advances);
  @override
  Future<void> saveAdvances(List<AdvanceModel> advances) async {
    _advances
      ..clear()
      ..addAll(advances);
  }

  @override
  List<SalaryPeriodModel> loadPeriods() => List.from(_periods);
  @override
  Future<void> savePeriods(List<SalaryPeriodModel> periods) async {
    _periods
      ..clear()
      ..addAll(periods);
  }

  @override
  double loadDailyWage() => _wage;
  @override
  Future<void> saveDailyWage(double wage) async => _wage = wage;

  @override
  bool loadReminderEnabled() => _reminderEnabled;
  @override
  Future<void> saveReminderEnabled(bool enabled) async =>
      _reminderEnabled = enabled;

  @override
  int loadReminderHour() => _reminderHour;
  @override
  int loadReminderMinute() => _reminderMinute;
  @override
  Future<void> saveReminderTime(int hour, int minute) async {
    _reminderHour = hour;
    _reminderMinute = minute;
  }

  @override
  List<int> loadWorkSchedule() => List.from(_schedule);
  @override
  Future<void> saveWorkSchedule(List<int> days) async {
    _schedule
      ..clear()
      ..addAll(days);
  }

  @override
  Future<void> clearAll() async {
    _objects.clear();
    _workDays.clear();
    _transactions.clear();
    _advances.clear();
    _periods.clear();
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────
Future<DataService> _makeService({double wage = 80.0}) async {
  final storage = _FakeStorage();
  await storage.saveDailyWage(wage);
  final svc = DataService(storage);
  await svc.init();
  return svc;
}

void main() {
  // ── 1. WorkDay Duplicate Prevention ──────────────────────────────────────
  group('WorkDay duplicate prevention', () {
    test('marking the same date twice creates only one record', () async {
      final svc = await _makeService();
      final obj = await svc.createObject(name: 'ვაჟა-ფშაველას 72');
      final date = DateTime(2026, 9, 17);

      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);
      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);

      final days = svc.workDays
          .where(
            (d) =>
                d.date.year == date.year &&
                d.date.month == date.month &&
                d.date.day == date.day,
          )
          .toList();
      expect(days.length, 1, reason: 'ONE DATE = ONE WORKDAY RECORD');
    });

    test(
      'marking worked then not-worked then worked again keeps one record',
      () async {
        final svc = await _makeService();
        final obj = await svc.createObject(name: 'Test');
        final date = DateTime(2026, 9, 17);

        await svc.markWorked(
          date: date,
          objectId: obj.id,
          objectName: obj.name,
        );
        await svc.markNotWorked(date);
        await svc.markWorked(
          date: date,
          objectId: obj.id,
          objectName: obj.name,
        );

        final days = svc.workDays
            .where(
              (d) =>
                  d.date.year == date.year &&
                  d.date.month == date.month &&
                  d.date.day == date.day,
            )
            .toList();
        expect(days.length, 1);
        expect(days.first.isWorked, isTrue);
      },
    );

    test('three rapid markWorked calls create exactly one record', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      final date = DateTime(2026, 9, 17);

      // Simulate rapid button taps
      await Future.wait([
        svc.markWorked(date: date, objectId: obj.id, objectName: obj.name),
        svc.markWorked(date: date, objectId: obj.id, objectName: obj.name),
        svc.markWorked(date: date, objectId: obj.id, objectName: obj.name),
      ]);

      final days = svc.workDays
          .where(
            (d) => d.date.year == 2026 && d.date.month == 9 && d.date.day == 17,
          )
          .toList();
      expect(
        days.length,
        1,
        reason: 'Concurrent markWorked must not duplicate',
      );
    });
  });

  // ── 2. Reminder ON/OFF State ──────────────────────────────────────────────
  group('Reminder ON/OFF state', () {
    test('reminder enabled state persists correctly', () async {
      final storage = _FakeStorage();
      final svc = DataService(storage);
      await svc.init();

      // Default: disabled
      expect(svc.reminderEnabled, isFalse);

      // Enable
      await svc.setReminder(true, 9, 0);
      expect(svc.reminderEnabled, isTrue);
      expect(svc.reminderHour, 9);
      expect(svc.reminderMinute, 0);

      // Disable
      await svc.setReminder(false, 9, 0);
      expect(svc.reminderEnabled, isFalse);
    });

    test('reminder time is stored and retrieved correctly', () async {
      final storage = _FakeStorage();
      final svc = DataService(storage);
      await svc.init();

      await svc.setReminder(true, 8, 30);
      expect(svc.reminderHour, 8);
      expect(svc.reminderMinute, 30);

      // Change time
      await svc.setReminder(true, 20, 45);
      expect(svc.reminderHour, 20);
      expect(svc.reminderMinute, 45);
    });

    test('reminder config survives service re-init (persistence)', () async {
      final storage = _FakeStorage();
      final svc1 = DataService(storage);
      await svc1.init();
      await svc1.setReminder(true, 7, 15);

      // Simulate app restart: new DataService with same storage
      final svc2 = DataService(storage);
      await svc2.init();
      expect(svc2.reminderEnabled, isTrue);
      expect(svc2.reminderHour, 7);
      expect(svc2.reminderMinute, 15);
    });
  });

  // ── 3. Schedule Replacement (time change cancels old, sets new) ───────────
  group('Schedule replacement', () {
    test('changing reminder time updates stored hour and minute', () async {
      final storage = _FakeStorage();
      final svc = DataService(storage);
      await svc.init();

      await svc.setReminder(true, 9, 0);
      expect(svc.reminderHour, 9);
      expect(svc.reminderMinute, 0);

      // Change time — old time must be replaced, not duplicated
      await svc.setReminder(true, 18, 30);
      expect(svc.reminderHour, 18);
      expect(svc.reminderMinute, 30);
      // Only one time is stored — no duplicate
      expect(svc.reminderEnabled, isTrue);
    });

    test('disabling reminder clears enabled state', () async {
      final storage = _FakeStorage();
      final svc = DataService(storage);
      await svc.init();

      await svc.setReminder(true, 9, 0);
      await svc.setReminder(false, 9, 0);
      expect(svc.reminderEnabled, isFalse);
    });
  });

  // ── 4. YES Idempotency ────────────────────────────────────────────────────
  group('YES idempotency', () {
    test('rapid YES taps create only one WorkDay', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      final date = DateTime(2026, 9, 17);

      // Simulate rapid YES taps (reminder YES + Home YES)
      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);
      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);
      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);

      final days = svc.workDays
          .where(
            (d) => d.date.year == 2026 && d.date.month == 9 && d.date.day == 17,
          )
          .toList();
      expect(
        days.length,
        1,
        reason: 'Rapid YES taps must not create duplicates',
      );
    });

    test('salary is counted only once even after multiple YES calls', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      final date = DateTime(2026, 9, 17);

      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);
      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);

      final total = svc.getTotalSalary();
      expect(
        total['earned'],
        80.0,
        reason: 'Salary must be counted only once regardless of YES call count',
      );
    });

    test('Reminder YES + Home YES is idempotent', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      final date = DateTime(2026, 9, 17);

      // Reminder YES (from notification action)
      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);
      final afterReminder = svc.getTotalSalary();

      // Home YES (user opens app and taps ვიმუშავე again)
      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);
      final afterHome = svc.getTotalSalary();

      expect(
        afterReminder['earned'],
        afterHome['earned'],
        reason: 'Reminder YES + Home YES must be idempotent',
      );
      expect(
        svc.workDays
            .where(
              (d) =>
                  d.date.year == 2026 && d.date.month == 9 && d.date.day == 17,
            )
            .length,
        1,
      );
    });
  });

  // ── 5. NO Does Not Create Worked Day ─────────────────────────────────────
  group('NO does not create worked day', () {
    test('markNotWorked does not create a worked record', () async {
      final svc = await _makeService(wage: 80.0);
      final date = DateTime(2026, 9, 17);

      await svc.markNotWorked(date);

      final wd = svc.getWorkDayForDate(date);
      expect(wd, isNotNull);
      expect(
        wd!.isWorked,
        isFalse,
        reason: 'NO must not create a worked record',
      );
    });

    test('NO does not add earned salary', () async {
      final svc = await _makeService(wage: 80.0);
      final date = DateTime(2026, 9, 17);

      await svc.markNotWorked(date);

      final total = svc.getTotalSalary();
      expect(total['earned'], 0.0, reason: 'NO must not add to earned salary');
    });

    test('NO does not affect future days', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');

      await svc.markNotWorked(DateTime(2026, 9, 17));

      // Future day should have no record
      final futureWd = svc.getWorkDayForDate(DateTime(2026, 9, 18));
      expect(futureWd, isNull, reason: 'NO must not affect future days');

      // Can still mark future day as worked
      await svc.markWorked(
        date: DateTime(2026, 9, 18),
        objectId: obj.id,
        objectName: obj.name,
      );
      final futureWorked = svc.getWorkDayForDate(DateTime(2026, 9, 18));
      expect(futureWorked?.isWorked, isTrue);
    });

    test('NO then YES on same day correctly marks as worked', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      final date = DateTime(2026, 9, 17);

      await svc.markNotWorked(date);
      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);

      final wd = svc.getWorkDayForDate(date);
      expect(wd?.isWorked, isTrue);
      expect(svc.getTotalSalary()['earned'], 80.0);
      // Still only one record
      expect(
        svc.workDays
            .where(
              (d) =>
                  d.date.year == 2026 && d.date.month == 9 && d.date.day == 17,
            )
            .length,
        1,
      );
    });
  });

  // ── 6. No-Object YES Behavior ─────────────────────────────────────────────
  group('No-object YES behavior', () {
    test(
      'markWorked with empty objectId stores empty objectId gracefully',
      () async {
        final svc = await _makeService(wage: 80.0);
        final date = DateTime(2026, 9, 17);

        // Simulate YES with no object selected
        final wd = await svc.markWorked(
          date: date,
          objectId: '',
          objectName: '',
        );

        expect(wd.objectId, '');
        expect(wd.isWorked, isTrue);
        // Salary is still counted (user confirmed work)
        expect(svc.getTotalSalary()['earned'], 80.0);
      },
    );

    test('getObjectById returns null for empty id (no crash)', () async {
      final svc = await _makeService();
      expect(svc.getObjectById(''), isNull);
      expect(svc.getObjectById('nonexistent'), isNull);
    });

    test('object stats for empty objectId return zero gracefully', () async {
      final svc = await _makeService(wage: 80.0);
      final date = DateTime(2026, 9, 17);

      // WorkDay with no object
      await svc.markWorked(date: date, objectId: '', objectName: '');

      // Stats for empty id should not crash
      final stats = svc.getObjectStats('');
      expect(stats['workedDays'], isA<int>());
      expect(stats['earned'], isA<double>());
    });
  });

  // ── 7. Duplicate Protection (YES + Home) ─────────────────────────────────
  group('Duplicate protection', () {
    test(
      'duplicate scheduling: same date different objects keeps one record',
      () async {
        final svc = await _makeService(wage: 80.0);
        final obj1 = await svc.createObject(name: 'ობიექტი 1');
        final obj2 = await svc.createObject(name: 'ობიექტი 2');
        final date = DateTime(2026, 9, 17);

        await svc.markWorked(
          date: date,
          objectId: obj1.id,
          objectName: obj1.name,
        );
        // Second call with different object — should update, not duplicate
        await svc.markWorked(
          date: date,
          objectId: obj2.id,
          objectName: obj2.name,
        );

        final days = svc.workDays
            .where(
              (d) =>
                  d.date.year == 2026 && d.date.month == 9 && d.date.day == 17,
            )
            .toList();
        expect(
          days.length,
          1,
          reason: 'Must not create duplicate even with different object',
        );
        // Latest object wins
        expect(days.first.objectId, obj2.id);
      },
    );

    test('historical wage is preserved when duplicate YES is called', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      final date = DateTime(2026, 9, 17);

      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);
      await svc.updateDailyWage(100.0);
      // Second YES after wage change — must not overwrite stored wage
      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);

      final wd = svc.getWorkDayForDate(date);
      expect(
        wd!.dailyWage,
        80.0,
        reason: 'Historical wage must not be overwritten by duplicate YES',
      );
    });
  });

  // ── 8. Reboot Scheduling Logic ────────────────────────────────────────────
  group('Reboot scheduling logic', () {
    test('reminder config survives simulated reboot (re-init)', () async {
      final storage = _FakeStorage();
      final svc1 = DataService(storage);
      await svc1.init();
      await svc1.setReminder(true, 8, 0);

      // Simulate reboot: new DataService instance with same storage
      final svc2 = DataService(storage);
      await svc2.init();

      expect(
        svc2.reminderEnabled,
        isTrue,
        reason: 'Reminder enabled state must survive reboot',
      );
      expect(svc2.reminderHour, 8);
      expect(svc2.reminderMinute, 0);
    });

    test('disabled reminder is not restored after reboot', () async {
      final storage = _FakeStorage();
      final svc1 = DataService(storage);
      await svc1.init();
      await svc1.setReminder(true, 9, 0);
      await svc1.setReminder(false, 9, 0); // Disable

      // Simulate reboot
      final svc2 = DataService(storage);
      await svc2.init();

      expect(
        svc2.reminderEnabled,
        isFalse,
        reason: 'Disabled reminder must NOT be restored after reboot',
      );
    });

    test('WorkDays survive simulated reboot', () async {
      final storage = _FakeStorage();
      final svc1 = DataService(storage);
      await svc1.init();
      final obj = await svc1.createObject(name: 'Test');
      await svc1.markWorked(
        date: DateTime(2026, 9, 17),
        objectId: obj.id,
        objectName: obj.name,
      );

      // Simulate reboot
      final svc2 = DataService(storage);
      await svc2.init();

      expect(svc2.workDays.length, 1, reason: 'WorkDays must survive reboot');
      expect(svc2.workDays.first.isWorked, isTrue);
    });

    test('objects survive simulated reboot', () async {
      final storage = _FakeStorage();
      final svc1 = DataService(storage);
      await svc1.init();
      await svc1.createObject(name: 'ვაჟა-ფშაველას 72');

      // Simulate reboot
      final svc2 = DataService(storage);
      await svc2.init();

      expect(svc2.objects.length, 1);
      expect(svc2.objects.first.name, 'ვაჟა-ფშაველას 72');
    });

    test('transactions survive simulated reboot', () async {
      final storage = _FakeStorage();
      final svc1 = DataService(storage);
      await svc1.init();
      final obj = await svc1.createObject(name: 'Test');
      await svc1.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc1.addTransaction(amount: 80);

      // Simulate reboot
      final svc2 = DataService(storage);
      await svc2.init();

      expect(
        svc2.transactions.length,
        1,
        reason: 'Transactions must survive reboot',
      );
      expect(svc2.transactions.first.amount, 80.0);
    });

    test('salary periods survive simulated reboot', () async {
      final storage = _FakeStorage();
      final svc1 = DataService(storage);
      await svc1.init();
      await svc1.updateDailyWage(120.0);

      // Simulate reboot
      final svc2 = DataService(storage);
      await svc2.init();

      final now = DateTime.now();
      final period = svc2.getPeriodForMonth(now.year, now.month);
      expect(period, isNotNull);
      expect(
        period!.dailyWage,
        120.0,
        reason: 'Period wage must survive reboot',
      );
    });
  });

  // ── 9. Date/Month Boundary Behavior ──────────────────────────────────────
  group('Date/month boundary behavior', () {
    test('WorkDays are assigned to correct month', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');

      await svc.markWorked(
        date: DateTime(2026, 12, 31),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.markWorked(
        date: DateTime(2027, 1, 1),
        objectId: obj.id,
        objectName: obj.name,
      );

      final decDays = svc.getWorkDaysForMonth(2026, 12);
      final janDays = svc.getWorkDaysForMonth(2027, 1);
      expect(decDays.length, 1, reason: 'December must have 1 day');
      expect(janDays.length, 1, reason: 'January must have 1 day');
    });

    test('December and January salary periods are separate', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');

      await svc.markWorked(
        date: DateTime(2026, 12, 31),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.markWorked(
        date: DateTime(2027, 1, 1),
        objectId: obj.id,
        objectName: obj.name,
      );

      final decSalary = svc.getSalaryForMonth(2026, 12);
      final janSalary = svc.getSalaryForMonth(2027, 1);
      expect(decSalary['workedDays'], 1.0);
      expect(janSalary['workedDays'], 1.0);
    });

    test('December salary does not bleed into January', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');

      // 5 days in December
      for (int i = 27; i <= 31; i++) {
        await svc.markWorked(
          date: DateTime(2026, 12, i),
          objectId: obj.id,
          objectName: obj.name,
        );
      }
      // 3 days in January
      for (int i = 1; i <= 3; i++) {
        await svc.markWorked(
          date: DateTime(2027, 1, i),
          objectId: obj.id,
          objectName: obj.name,
        );
      }

      final decSalary = svc.getSalaryForMonth(2026, 12);
      final janSalary = svc.getSalaryForMonth(2027, 1);
      expect(decSalary['earned'], 400.0, reason: 'December: 5 × 80 = 400');
      expect(janSalary['earned'], 240.0, reason: 'January: 3 × 80 = 240');
      expect(decSalary['workedDays'], 5.0);
      expect(janSalary['workedDays'], 3.0);
    });

    test('same calendar date with different times is one record', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');

      final morning = DateTime(2026, 9, 17, 8, 0, 0);
      final evening = DateTime(2026, 9, 17, 20, 0, 0);

      await svc.markWorked(
        date: morning,
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.markWorked(
        date: evening,
        objectId: obj.id,
        objectName: obj.name,
      );

      final days = svc.workDays
          .where(
            (d) => d.date.year == 2026 && d.date.month == 9 && d.date.day == 17,
          )
          .toList();
      expect(
        days.length,
        1,
        reason: 'Same calendar date with different times = one record',
      );
    });

    test('WorkDay date is stored as date-only (no time component)', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      final dateWithTime = DateTime(2026, 9, 17, 14, 30, 0);

      await svc.markWorked(
        date: dateWithTime,
        objectId: obj.id,
        objectName: obj.name,
      );

      final wd = svc.getWorkDayForDate(dateWithTime);
      expect(wd, isNotNull);
      expect(wd!.date.hour, 0);
      expect(wd.date.minute, 0);
      expect(wd.date.second, 0);
    });
  });

  // ── 10. Object Change Safety ──────────────────────────────────────────────
  group('Object change safety', () {
    test(
      'changing today object updates existing record, no duplicate',
      () async {
        final svc = await _makeService();
        final obj1 = await svc.createObject(name: 'ობიექტი 1');
        final obj2 = await svc.createObject(name: 'ობიექტი 2');
        final date = DateTime(2026, 9, 17);

        final wd = await svc.markWorked(
          date: date,
          objectId: obj1.id,
          objectName: obj1.name,
        );

        final updated = wd.copyWith(
          objectId: obj2.id,
          objectName: obj2.name,
          updatedAt: DateTime.now(),
        );
        await svc.updateWorkDay(updated);

        final days = svc.workDays
            .where(
              (d) =>
                  d.date.year == date.year &&
                  d.date.month == date.month &&
                  d.date.day == date.day,
            )
            .toList();
        expect(days.length, 1, reason: 'No duplicate after object change');
        expect(days.first.objectId, obj2.id);
        expect(
          days.first.dailyWage,
          80.0,
          reason: 'Wage must not change when object changes',
        );
      },
    );

    test('object stats update correctly after object change', () async {
      final svc = await _makeService();
      final obj1 = await svc.createObject(name: 'ობიექტი 1');
      final obj2 = await svc.createObject(name: 'ობიექტი 2');
      final date = DateTime(2026, 9, 17);

      final wd = await svc.markWorked(
        date: date,
        objectId: obj1.id,
        objectName: obj1.name,
      );

      expect(svc.getObjectStats(obj1.id)['workedDays'], 1);
      expect(svc.getObjectStats(obj2.id)['workedDays'], 0);

      await svc.updateWorkDay(
        wd.copyWith(objectId: obj2.id, objectName: obj2.name),
      );

      expect(
        svc.getObjectStats(obj1.id)['workedDays'],
        0,
        reason: 'Old object stats must decrease',
      );
      expect(
        svc.getObjectStats(obj2.id)['workedDays'],
        1,
        reason: 'New object stats must increase',
      );
    });

    test('object change does not double-count global salary', () async {
      final svc = await _makeService(wage: 80.0);
      final obj1 = await svc.createObject(name: 'ობიექტი 1');
      final obj2 = await svc.createObject(name: 'ობიექტი 2');
      final date = DateTime(2026, 9, 17);

      final wd = await svc.markWorked(
        date: date,
        objectId: obj1.id,
        objectName: obj1.name,
      );
      final earnedBefore = svc.getTotalSalary()['earned']!;

      // Change object
      await svc.updateWorkDay(
        wd.copyWith(objectId: obj2.id, objectName: obj2.name),
      );
      final earnedAfter = svc.getTotalSalary()['earned']!;

      expect(
        earnedAfter,
        earnedBefore,
        reason: 'Object change must not double-count global salary',
      );
      expect(earnedAfter, 80.0);
    });
  });

  // ── 11. Salary Calculations ───────────────────────────────────────────────
  group('Salary calculations', () {
    test('earned = sum of worked-day wages', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');

      await svc.markWorked(
        date: DateTime(2026, 9, 15),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.markWorked(
        date: DateTime(2026, 9, 16),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.markWorked(
        date: DateTime(2026, 9, 17),
        objectId: obj.id,
        objectName: obj.name,
      );

      final total = svc.getTotalSalary();
      expect(total['earned'], 240.0);
    });

    test('remaining = earned - received', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');

      for (int i = 1; i <= 5; i++) {
        await svc.markWorked(
          date: DateTime(2026, 9, i),
          objectId: obj.id,
          objectName: obj.name,
        );
      }
      await svc.addTransaction(amount: 200);
      final total = svc.getTotalSalary();
      expect(total['earned'], 400.0);
      expect(total['received'], 200.0);
      expect(total['remaining'], 200.0);
    });

    test('remaining never goes below zero', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.addTransaction(amount: 80);
      final total = svc.getTotalSalary();
      expect(total['remaining'], 0.0);
    });

    test('notWorked days are not counted in earned', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');

      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.markNotWorked(DateTime(2026, 9, 2));
      await svc.markNotWorked(DateTime(2026, 9, 3));

      final total = svc.getTotalSalary();
      expect(
        total['earned'],
        80.0,
        reason: 'Only worked days count toward earned',
      );
    });

    test(
      'full payment lifecycle: earned 400, pay 200, pay 200, reject 1',
      () async {
        final svc = await _makeService(wage: 80.0);
        final obj = await svc.createObject(name: 'Test');

        for (int i = 1; i <= 5; i++) {
          await svc.markWorked(
            date: DateTime(2026, 9, i),
            objectId: obj.id,
            objectName: obj.name,
          );
        }

        final tx1 = await svc.addTransaction(amount: 200);
        expect(tx1, isNotNull);
        expect(svc.getTotalSalary()['remaining'], 200.0);

        final tx2 = await svc.addTransaction(amount: 200);
        expect(tx2, isNotNull);
        expect(svc.getTotalSalary()['remaining'], 0.0);
        expect(svc.getTotalSalary()['received'], 400.0);

        // Any further payment must be rejected
        final tx3 = await svc.addTransaction(amount: 1);
        expect(
          tx3,
          isNull,
          reason: 'Payment after full payment must be rejected',
        );
      },
    );
  });

  // ── 12. Historical Wage Preservation ─────────────────────────────────────
  group('Historical wage preservation', () {
    test('changing wage does not recalculate old WorkDay wages', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');

      final sepDate = DateTime(2026, 9, 17);
      await svc.markWorked(
        date: sepDate,
        objectId: obj.id,
        objectName: obj.name,
      );

      await svc.updateDailyWage(100.0);

      final wd = svc.getWorkDayForDate(sepDate);
      expect(wd, isNotNull);
      expect(
        wd!.dailyWage,
        80.0,
        reason: 'Historical wage must not change when current wage changes',
      );
    });

    test('markWorked on already-worked date preserves stored wage', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      final date = DateTime(2026, 9, 17);

      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);
      await svc.updateDailyWage(100.0);
      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);

      final wd = svc.getWorkDayForDate(date);
      expect(
        wd!.dailyWage,
        80.0,
        reason: 'Re-marking a worked day must not overwrite stored wage',
      );
    });

    test('new WorkDay after wage change uses new wage', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');

      await svc.updateDailyWage(100.0);

      final date = DateTime(2026, 10, 1);
      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);

      final wd = svc.getWorkDayForDate(date);
      expect(wd!.dailyWage, 100.0, reason: 'New WorkDay must use updated wage');
    });

    test(
      'multiple wage changes: each new WorkDay uses wage at time of creation',
      () async {
        final svc = await _makeService(wage: 80.0);
        final obj = await svc.createObject(name: 'Test');

        // Day 1 at 80
        await svc.markWorked(
          date: DateTime(2026, 9, 1),
          objectId: obj.id,
          objectName: obj.name,
        );

        // Change to 100
        await svc.updateDailyWage(100.0);

        // Day 2 at 100
        await svc.markWorked(
          date: DateTime(2026, 9, 2),
          objectId: obj.id,
          objectName: obj.name,
        );

        // Change to 120
        await svc.updateDailyWage(120.0);

        // Day 3 at 120
        await svc.markWorked(
          date: DateTime(2026, 9, 3),
          objectId: obj.id,
          objectName: obj.name,
        );

        final wd1 = svc.getWorkDayForDate(DateTime(2026, 9, 1));
        final wd2 = svc.getWorkDayForDate(DateTime(2026, 9, 2));
        final wd3 = svc.getWorkDayForDate(DateTime(2026, 9, 3));

        expect(wd1!.dailyWage, 80.0, reason: 'Day 1 must keep 80');
        expect(wd2!.dailyWage, 100.0, reason: 'Day 2 must keep 100');
        expect(wd3!.dailyWage, 120.0, reason: 'Day 3 must keep 120');

        // Total earned = 80 + 100 + 120 = 300
        expect(svc.getTotalSalary()['earned'], 300.0);
      },
    );

    test(
      'updateDailyWage creates new period if none exists for current month',
      () async {
        final svc = await _makeService(wage: 80.0);
        final now = DateTime.now();

        // Verify period exists after init
        final periodBefore = svc.getPeriodForMonth(now.year, now.month);
        expect(periodBefore, isNotNull);

        // Update wage
        await svc.updateDailyWage(150.0);

        final periodAfter = svc.getPeriodForMonth(now.year, now.month);
        expect(periodAfter, isNotNull);
        expect(periodAfter!.dailyWage, 150.0);
      },
    );
  });

  // ── 13. Payment Validation ────────────────────────────────────────────────
  group('Payment validation', () {
    test('payment exceeding remaining is rejected', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      final tx = await svc.addTransaction(amount: 100);
      expect(tx, isNull, reason: 'Overpayment must be rejected');
    });

    test('zero payment is rejected', () async {
      final svc = await _makeService(wage: 80.0);
      final tx = await svc.addTransaction(amount: 0);
      expect(tx, isNull);
    });

    test('negative payment is rejected', () async {
      final svc = await _makeService(wage: 80.0);
      final tx = await svc.addTransaction(amount: -50);
      expect(tx, isNull);
    });

    test('exact remaining amount is accepted', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      final tx = await svc.addTransaction(amount: 80);
      expect(tx, isNotNull, reason: 'Exact remaining amount must be accepted');
      expect(svc.getTotalSalary()['remaining'], 0.0);
    });

    test('partial payments sum correctly', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      for (int i = 1; i <= 5; i++) {
        await svc.markWorked(
          date: DateTime(2026, 9, i),
          objectId: obj.id,
          objectName: obj.name,
        );
      }
      await svc.addTransaction(amount: 200);
      await svc.addTransaction(amount: 200);
      final total = svc.getTotalSalary();
      expect(total['received'], 400.0);
      expect(total['remaining'], 0.0);
    });

    test('payment after full payment is rejected', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.addTransaction(amount: 80);
      final tx = await svc.addTransaction(amount: 1);
      expect(tx, isNull, reason: 'No payment allowed when remaining is 0');
    });

    test('deleting a transaction recalculates remaining', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      final tx = await svc.addTransaction(amount: 80);
      expect(svc.getTotalSalary()['remaining'], 0.0);

      await svc.deleteTransaction(tx!.id);
      expect(
        svc.getTotalSalary()['remaining'],
        80.0,
        reason: 'Remaining must increase after deleting a transaction',
      );
    });

    test(
      'deleting one of multiple transactions recalculates correctly',
      () async {
        final svc = await _makeService(wage: 80.0);
        final obj = await svc.createObject(name: 'Test');
        for (int i = 1; i <= 5; i++) {
          await svc.markWorked(
            date: DateTime(2026, 9, i),
            objectId: obj.id,
            objectName: obj.name,
          );
        }
        final tx1 = await svc.addTransaction(amount: 200);
        await svc.addTransaction(amount: 100);

        expect(svc.getTotalSalary()['received'], 300.0);
        expect(svc.getTotalSalary()['remaining'], 100.0);

        // Delete first transaction
        await svc.deleteTransaction(tx1!.id);

        expect(svc.getTotalSalary()['received'], 100.0);
        expect(svc.getTotalSalary()['remaining'], 300.0);
        expect(
          svc.getTotalSalary()['earned'],
          400.0,
          reason: 'Earned must not change',
        );
      },
    );

    test('payment delete does not affect earned', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      final tx = await svc.addTransaction(amount: 50);
      final earnedBefore = svc.getTotalSalary()['earned']!;

      await svc.deleteTransaction(tx!.id);

      expect(
        svc.getTotalSalary()['earned'],
        earnedBefore,
        reason: 'Earned must not change after payment deletion',
      );
    });
  });

  // ── 14. Payment Edit Validation ───────────────────────────────────────────
  group('Payment edit validation', () {
    test('editing payment to exact earned is valid', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      for (int i = 1; i <= 5; i++) {
        await svc.markWorked(
          date: DateTime(2026, 9, i),
          objectId: obj.id,
          objectName: obj.name,
        );
      }
      final tx = await svc.addTransaction(amount: 200);
      final maxAmount = svc.getTotalSalary()['remaining']! + tx!.amount;
      expect(maxAmount, 400.0);
      expect(400 <= maxAmount + 0.001, isTrue);
    });

    test('editing payment beyond earned is invalid', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      for (int i = 1; i <= 5; i++) {
        await svc.markWorked(
          date: DateTime(2026, 9, i),
          objectId: obj.id,
          objectName: obj.name,
        );
      }
      final tx = await svc.addTransaction(amount: 200);
      final maxAmount = svc.getTotalSalary()['remaining']! + tx!.amount;
      expect(500 > maxAmount + 0.001, isTrue);
    });

    test('edit 200→250 is valid when earned=400 and only tx is 200', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      for (int i = 1; i <= 5; i++) {
        await svc.markWorked(
          date: DateTime(2026, 9, i),
          objectId: obj.id,
          objectName: obj.name,
        );
      }
      final tx = await svc.addTransaction(amount: 200);
      // maxAmount = remaining(200) + tx.amount(200) = 400
      final maxAmount = svc.getTotalSalary()['remaining']! + tx!.amount;
      expect(250 <= maxAmount + 0.001, isTrue, reason: '200→250 must be valid');
    });

    test('edit 200→450 is invalid when earned=400', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      for (int i = 1; i <= 5; i++) {
        await svc.markWorked(
          date: DateTime(2026, 9, i),
          objectId: obj.id,
          objectName: obj.name,
        );
      }
      final tx = await svc.addTransaction(amount: 200);
      // maxAmount = remaining(200) + tx.amount(200) = 400
      final maxAmount = svc.getTotalSalary()['remaining']! + tx!.amount;
      expect(
        450 > maxAmount + 0.001,
        isTrue,
        reason: '200→450 must be invalid',
      );
    });

    test('edit updates transaction amount correctly', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      for (int i = 1; i <= 5; i++) {
        await svc.markWorked(
          date: DateTime(2026, 9, i),
          objectId: obj.id,
          objectName: obj.name,
        );
      }
      final tx = await svc.addTransaction(amount: 200);
      await svc.updateTransaction(tx!.copyWith(amount: 300));

      expect(svc.getTotalSalary()['received'], 300.0);
      expect(svc.getTotalSalary()['remaining'], 100.0);
    });
  });

  // ── 15. Object Statistics ─────────────────────────────────────────────────
  group('Object statistics', () {
    test('object earned = sum of its worked-day wages', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      for (int i = 1; i <= 3; i++) {
        await svc.markWorked(
          date: DateTime(2026, 9, i),
          objectId: obj.id,
          objectName: obj.name,
        );
      }
      final stats = svc.getObjectStats(obj.id);
      expect(stats['workedDays'], 3);
      expect(stats['earned'], 240.0);
    });

    test('completed object retains historical stats', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.completeObject(obj.id);

      final stats = svc.getObjectStats(obj.id);
      expect(
        stats['workedDays'],
        1,
        reason: 'Completed object must retain work history',
      );
      expect(stats['earned'], 80.0);
    });

    test('deleted object WorkDays remain in global salary', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );

      final earnedBefore = svc.getTotalSalary()['earned']!;
      await svc.deleteObject(obj.id);
      final earnedAfter = svc.getTotalSalary()['earned']!;

      expect(
        earnedAfter,
        earnedBefore,
        reason: 'Deleting object must not affect historical salary',
      );
      expect(earnedAfter, 80.0);
    });

    test('deleted object WorkDays remain in workDays list', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );

      await svc.deleteObject(obj.id);

      // WorkDay still exists with objectId reference (dangling but preserved)
      final wd = svc.getWorkDayForDate(DateTime(2026, 9, 1));
      expect(wd, isNotNull, reason: 'WorkDay must survive object deletion');
      expect(wd!.isWorked, isTrue);
      expect(wd.objectId, obj.id, reason: 'objectId snapshot preserved');
    });
  });

  // ── 16. Object Completion ─────────────────────────────────────────────────
  group('Object completion', () {
    test('completed object disappears from activeObjects', () async {
      final svc = await _makeService();
      final obj = await svc.createObject(name: 'Test');
      expect(svc.activeObjects.any((o) => o.id == obj.id), isTrue);

      await svc.completeObject(obj.id);
      expect(
        svc.activeObjects.any((o) => o.id == obj.id),
        isFalse,
        reason: 'Completed object must not appear in active list',
      );
      expect(
        svc.completedObjects.any((o) => o.id == obj.id),
        isTrue,
        reason: 'Completed object must appear in completed list',
      );
    });

    test('completed object historical WorkDays remain intact', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.completeObject(obj.id);

      final days = svc.getWorkDaysForObject(obj.id);
      expect(
        days.length,
        1,
        reason: 'Historical WorkDays must survive object completion',
      );
    });

    test('completedAt is set when object is completed', () async {
      final svc = await _makeService();
      final obj = await svc.createObject(name: 'Test');
      expect(obj.completedAt, isNull);

      await svc.completeObject(obj.id);
      final completed = svc.getObjectById(obj.id);
      expect(completed, isNotNull);
      expect(
        completed!.completedAt,
        isNotNull,
        reason: 'completedAt must be set',
      );
      expect(completed.status, WorkObjectStatus.completed);
    });

    test('completing object does not affect global salary', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      final earnedBefore = svc.getTotalSalary()['earned']!;

      await svc.completeObject(obj.id);

      expect(
        svc.getTotalSalary()['earned'],
        earnedBefore,
        reason: 'Completing object must not affect global salary',
      );
    });
  });

  // ── 17. Object Deletion Safety ────────────────────────────────────────────
  group('Object deletion safety', () {
    test('getWorkDayCountForObject returns correct count', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');

      expect(svc.getWorkDayCountForObject(obj.id), 0);

      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.markWorked(
        date: DateTime(2026, 9, 2),
        objectId: obj.id,
        objectName: obj.name,
      );

      expect(svc.getWorkDayCountForObject(obj.id), 2);
    });

    test('deleting object with no WorkDays removes it cleanly', () async {
      final svc = await _makeService();
      final obj = await svc.createObject(name: 'Test');
      expect(svc.objects.length, 1);

      await svc.deleteObject(obj.id);
      expect(svc.objects.length, 0);
      expect(svc.getObjectById(obj.id), isNull);
    });

    test('getObjectById returns null for deleted object (no crash)', () async {
      final svc = await _makeService();
      final obj = await svc.createObject(name: 'Test');
      await svc.deleteObject(obj.id);

      // Must not crash — returns null
      expect(svc.getObjectById(obj.id), isNull);
    });
  });

  // ── 18. Missing/Null Data Safety ──────────────────────────────────────────
  group('Missing/null data safety', () {
    test('getObjectById returns null for missing id', () async {
      final svc = await _makeService();
      expect(svc.getObjectById('nonexistent-id'), isNull);
      expect(svc.getObjectById(''), isNull);
    });

    test('getWorkDayForDate returns null for missing date', () async {
      final svc = await _makeService();
      expect(svc.getWorkDayForDate(DateTime(2026, 9, 17)), isNull);
    });

    test('WorkDayModel.fromMap handles missing optional fields', () {
      final map = <String, dynamic>{
        'id': 'test-id',
        'date': '2026-09-17T00:00:00.000',
        'status': 'worked',
        'dailyWage': 80.0,
        'createdAt': '2026-09-17T10:00:00.000',
        'updatedAt': '2026-09-17T10:00:00.000',
      };
      final wd = WorkDayModel.fromMap(map);
      expect(wd.objectId, '');
      expect(wd.objectName, '');
      expect(wd.note, '');
    });

    test('WorkObjectModel.fromMap handles missing optional fields', () {
      final map = <String, dynamic>{
        'id': 'test-id',
        'name': 'Test Object',
        'createdAt': '2026-09-17T10:00:00.000',
      };
      final obj = WorkObjectModel.fromMap(map);
      expect(obj.address, '');
      expect(obj.note, '');
      expect(obj.completedAt, isNull);
    });

    test('PaymentTransactionModel.fromMap handles missing optional fields', () {
      final map = <String, dynamic>{
        'id': 'test-id',
        'amount': 100.0,
        'dateTime': '2026-09-17T10:00:00.000',
      };
      final tx = PaymentTransactionModel.fromMap(map);
      expect(tx.salaryPeriodId, '');
      expect(tx.objectId, '');
      expect(tx.objectName, '');
      expect(tx.note, '');
    });

    test('decodeList rejects malformed JSON instead of hiding stored data', () {
      expect(
        () => WorkDayModel.decodeList('not-json'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => WorkObjectModel.decodeList('{invalid}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => PaymentTransactionModel.decodeList(''),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SalaryPeriodModel.decodeList('null'),
        throwsA(isA<FormatException>()),
      );
    });

    test('WorkDayModel.fromMap handles unknown status gracefully', () {
      final map = <String, dynamic>{
        'id': 'test-id',
        'date': '2026-09-17T00:00:00.000',
        'status': 'unknown_future_status',
        'dailyWage': 80.0,
        'createdAt': '2026-09-17T10:00:00.000',
        'updatedAt': '2026-09-17T10:00:00.000',
      };
      // Must not throw
      final wd = WorkDayModel.fromMap(map);
      expect(wd.status, WorkDayStatus.unmarked);
    });

    test('WorkObjectModel.fromMap handles unknown status gracefully', () {
      final map = <String, dynamic>{
        'id': 'test-id',
        'name': 'Test',
        'status': 'unknown_status',
        'createdAt': '2026-09-17T10:00:00.000',
      };
      final obj = WorkObjectModel.fromMap(map);
      expect(obj.status, WorkObjectStatus.active);
    });

    test(
      'empty state: no objects, no WorkDays, no payments returns zeros',
      () async {
        final svc = await _makeService();
        final total = svc.getTotalSalary();
        expect(total['earned'], 0.0);
        expect(total['received'], 0.0);
        expect(total['remaining'], 0.0);
        expect(svc.activeObjects, isEmpty);
        expect(svc.workDays, isEmpty);
        expect(svc.transactions, isEmpty);
      },
    );
  });

  // ── 19. WorkObjectModel.copyWith sentinel ─────────────────────────────────
  group('WorkObjectModel.copyWith', () {
    test('copyWith can clear completedAt to null', () {
      final obj = WorkObjectModel(
        id: 'test',
        name: 'Test',
        status: WorkObjectStatus.completed,
        createdAt: DateTime(2026, 9, 1),
        completedAt: DateTime(2026, 9, 17),
      );

      // Use sentinel to clear completedAt
      final cleared = obj.copyWith(completedAt: null);
      expect(
        cleared.completedAt,
        isNull,
        reason: 'copyWith must be able to clear completedAt',
      );
    });

    test('copyWith preserves completedAt when not specified', () {
      final completedAt = DateTime(2026, 9, 17);
      final obj = WorkObjectModel(
        id: 'test',
        name: 'Test',
        status: WorkObjectStatus.completed,
        createdAt: DateTime(2026, 9, 1),
        completedAt: completedAt,
      );

      final copy = obj.copyWith(name: 'New Name');
      expect(
        copy.completedAt,
        completedAt,
        reason: 'completedAt must be preserved when not specified',
      );
    });
  });

  // ── 20. Yesterday Object Suggestion ──────────────────────────────────────
  group('Yesterday object suggestion', () {
    test('getYesterdayObject returns null when no yesterday WorkDay', () async {
      final svc = await _makeService();
      expect(svc.getYesterdayObject(), isNull);
    });

    test('getYesterdayObject returns null for completed object', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      await svc.markWorked(
        date: yesterday,
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.completeObject(obj.id);

      // Completed object must not be suggested
      expect(
        svc.getYesterdayObject(),
        isNull,
        reason: 'Completed object must not be suggested as yesterday object',
      );
    });

    test('getYesterdayObject returns null for deleted object', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      await svc.markWorked(
        date: yesterday,
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.deleteObject(obj.id);

      // Deleted object must not be suggested
      expect(
        svc.getYesterdayObject(),
        isNull,
        reason: 'Deleted object must not be suggested as yesterday object',
      );
    });
  });

  // ── 21. Version 7 Audit Regression Tests ─────────────────────────────────

  // BUG-1 regression: completed object must not appear as active today-object
  group('V7 audit: completed object not selectable as today object', () {
    test('activeObjects excludes completed objects', () async {
      final svc = await _makeService();
      final obj = await svc.createObject(name: 'Test');
      expect(svc.activeObjects.length, 1);

      await svc.completeObject(obj.id);
      expect(
        svc.activeObjects,
        isEmpty,
        reason: 'Completed object must not appear in activeObjects',
      );
    });

    test(
      'completed object is still in objects list (history preserved)',
      () async {
        final svc = await _makeService();
        final obj = await svc.createObject(name: 'Test');
        await svc.completeObject(obj.id);

        expect(svc.objects.length, 1);
        expect(svc.objects.first.status, WorkObjectStatus.completed);
      },
    );

    test('completed object WorkDays are preserved after completion', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      final date = DateTime(2026, 9, 17);

      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);
      await svc.completeObject(obj.id);

      final days = svc.getWorkDaysForObject(obj.id);
      expect(days.length, 1, reason: 'WorkDays must survive object completion');
      expect(days.first.isWorked, isTrue);
    });

    test('salary is unchanged after object completion', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      final date = DateTime(2026, 9, 17);

      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);
      final earnedBefore = svc.getTotalSalary()['earned']!;

      await svc.completeObject(obj.id);

      expect(
        svc.getTotalSalary()['earned'],
        earnedBefore,
        reason: 'Completing object must not change earned salary',
      );
    });
  });

  // BUG-2 regression: object deletion preserves WorkDay history and salary
  group('V7 audit: object deletion preserves history', () {
    test('deleting object does not delete its WorkDays', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      final date = DateTime(2026, 9, 17);

      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);
      await svc.deleteObject(obj.id);

      // WorkDay must still exist
      final wd = svc.getWorkDayForDate(date);
      expect(wd, isNotNull, reason: 'WorkDay must survive object deletion');
      expect(wd!.isWorked, isTrue);
    });

    test('salary is unchanged after object deletion', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      final date = DateTime(2026, 9, 17);

      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);
      final earnedBefore = svc.getTotalSalary()['earned']!;

      await svc.deleteObject(obj.id);

      expect(
        svc.getTotalSalary()['earned'],
        earnedBefore,
        reason: 'Deleting object must not change earned salary',
      );
    });

    test('getObjectById returns null after deletion (no crash)', () async {
      final svc = await _makeService();
      final obj = await svc.createObject(name: 'Test');
      await svc.deleteObject(obj.id);

      expect(svc.getObjectById(obj.id), isNull);
    });
  });

  // BUG-3 regression: payment validation — amount > remaining rejected
  group('V7 audit: payment validation edge cases', () {
    test('payment exactly equal to remaining is accepted', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 17),
        objectId: obj.id,
        objectName: obj.name,
      );

      final remaining = svc.getTotalSalary()['remaining']!;
      final tx = await svc.addTransaction(amount: remaining);
      expect(tx, isNotNull, reason: 'Exact remaining amount must be accepted');
      expect(svc.getTotalSalary()['remaining'], closeTo(0.0, 0.001));
    });

    test('payment of 0 is rejected', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 17),
        objectId: obj.id,
        objectName: obj.name,
      );

      final tx = await svc.addTransaction(amount: 0);
      expect(tx, isNull, reason: 'Zero payment must be rejected');
    });

    test('payment of negative amount is rejected', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 17),
        objectId: obj.id,
        objectName: obj.name,
      );

      final tx = await svc.addTransaction(amount: -50);
      expect(tx, isNull, reason: 'Negative payment must be rejected');
    });

    test('payment exceeding remaining is rejected', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 17),
        objectId: obj.id,
        objectName: obj.name,
      );

      final tx = await svc.addTransaction(amount: 999);
      expect(tx, isNull, reason: 'Overpayment must be rejected');
    });

    test('payment when earned=0 is rejected', () async {
      final svc = await _makeService(wage: 80.0);
      // No work done — earned = 0, remaining = 0
      final tx = await svc.addTransaction(amount: 50);
      expect(
        tx,
        isNull,
        reason: 'Payment when nothing earned must be rejected',
      );
    });

    test('delete transaction recalculates remaining correctly', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 17),
        objectId: obj.id,
        objectName: obj.name,
      );

      final tx = await svc.addTransaction(amount: 40);
      expect(tx, isNotNull);
      expect(svc.getTotalSalary()['remaining'], closeTo(40.0, 0.001));

      await svc.deleteTransaction(tx!.id);
      expect(
        svc.getTotalSalary()['remaining'],
        closeTo(80.0, 0.001),
        reason: 'Remaining must be restored after transaction deletion',
      );
      expect(
        svc.getTotalSalary()['earned'],
        closeTo(80.0, 0.001),
        reason: 'Earned must be unchanged after transaction deletion',
      );
    });
  });

  // BUG-4 regression: historical wage immutability
  group('V7 audit: historical wage immutability', () {
    test('changing wage does not affect existing WorkDay dailyWage', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      final date = DateTime(2026, 9, 17);

      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);
      final wd = svc.getWorkDayForDate(date)!;
      expect(wd.dailyWage, 80.0);

      // Change wage
      await svc.updateDailyWage(120.0);

      // Existing WorkDay must still have 80
      final wdAfter = svc.getWorkDayForDate(date)!;
      expect(
        wdAfter.dailyWage,
        80.0,
        reason: 'Historical wage must not change when current wage changes',
      );
    });

    test('re-marking worked day does not overwrite historical wage', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      final date = DateTime(2026, 9, 17);

      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);
      await svc.updateDailyWage(120.0);

      // Re-mark same day (simulates rapid tap or reminder YES + Home YES)
      await svc.markWorked(date: date, objectId: obj.id, objectName: obj.name);

      final wd = svc.getWorkDayForDate(date)!;
      expect(
        wd.dailyWage,
        80.0,
        reason: 'Re-marking worked day must not overwrite historical wage',
      );
    });
  });

  // BUG-5 regression: object change updates existing WorkDay, no duplicate
  group('V7 audit: object change safety', () {
    test(
      'changing object on worked day updates WorkDay, no duplicate',
      () async {
        final svc = await _makeService(wage: 80.0);
        final objA = await svc.createObject(name: 'Object A');
        final objB = await svc.createObject(name: 'Object B');
        final date = DateTime(2026, 9, 17);

        await svc.markWorked(
          date: date,
          objectId: objA.id,
          objectName: objA.name,
        );

        // Simulate object change: update existing WorkDay
        final existing = svc.getWorkDayForDate(date)!;
        final updated = existing.copyWith(
          objectId: objB.id,
          objectName: objB.name,
          updatedAt: DateTime.now(),
        );
        await svc.updateWorkDay(updated);

        // Still only one WorkDay for this date
        final days = svc.workDays
            .where(
              (d) =>
                  d.date.year == date.year &&
                  d.date.month == date.month &&
                  d.date.day == date.day,
            )
            .toList();
        expect(
          days.length,
          1,
          reason: 'Object change must not create duplicate WorkDay',
        );
        expect(days.first.objectId, objB.id);
        expect(
          days.first.dailyWage,
          80.0,
          reason: 'Wage must be preserved after object change',
        );
      },
    );

    test('global earned salary unchanged after object change', () async {
      final svc = await _makeService(wage: 80.0);
      final objA = await svc.createObject(name: 'Object A');
      final objB = await svc.createObject(name: 'Object B');
      final date = DateTime(2026, 9, 17);

      await svc.markWorked(
        date: date,
        objectId: objA.id,
        objectName: objA.name,
      );
      final earnedBefore = svc.getTotalSalary()['earned']!;

      final existing = svc.getWorkDayForDate(date)!;
      await svc.updateWorkDay(
        existing.copyWith(objectId: objB.id, objectName: objB.name),
      );

      expect(
        svc.getTotalSalary()['earned'],
        earnedBefore,
        reason: 'Global earned must not change after object change',
      );
    });
  });

  // BUG-6 regression: multi-year month boundary
  group('V7 audit: multi-year month boundaries', () {
    test('December and January WorkDays are in separate groups', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');

      await svc.markWorked(
        date: DateTime(2026, 12, 31),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.markWorked(
        date: DateTime(2027, 1, 1),
        objectId: obj.id,
        objectName: obj.name,
      );

      final dec = svc.getWorkDaysForMonth(2026, 12);
      final jan = svc.getWorkDaysForMonth(2027, 1);

      expect(dec.length, 1, reason: 'December must have exactly 1 WorkDay');
      expect(jan.length, 1, reason: 'January must have exactly 1 WorkDay');
    });

    test('getSalaryForMonth does not mix December and January', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');

      await svc.markWorked(
        date: DateTime(2026, 12, 31),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.markWorked(
        date: DateTime(2027, 1, 1),
        objectId: obj.id,
        objectName: obj.name,
      );

      final decSalary = svc.getSalaryForMonth(2026, 12);
      final janSalary = svc.getSalaryForMonth(2027, 1);

      expect(
        decSalary['earned'],
        closeTo(80.0, 0.001),
        reason: 'December salary must only include December WorkDays',
      );
      expect(
        janSalary['earned'],
        closeTo(80.0, 0.001),
        reason: 'January salary must only include January WorkDays',
      );
    });
  });

  // ── Monthly Summary Tests (Version 9) ────────────────────────────────────
  group('getMonthlySummary — Version 9', () {
    test('1. 0 worked days → earned = 0', () async {
      final svc = await _makeService(wage: 80.0);
      final summary = svc.getMonthlySummary(2026, 9);
      expect(summary.earned, 0.0);
      expect(summary.workedDays, 0);
      expect(summary.isEmpty, isTrue);
    });

    test('2. 10 worked days × 80 ₾ → earned = 800', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'ობიექტი A');
      for (int d = 1; d <= 10; d++) {
        await svc.markWorked(
          date: DateTime(2026, 9, d),
          objectId: obj.id,
          objectName: obj.name,
        );
      }
      final summary = svc.getMonthlySummary(2026, 9);
      expect(summary.workedDays, 10);
      expect(summary.earned, closeTo(800.0, 0.001));
    });

    test('3. partial payment → remaining is correct', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'ობიექტი A');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      // earned = 80; pay 50
      await svc.addTransaction(amount: 50.0, dateTime: DateTime(2026, 9, 1));
      final summary = svc.getMonthlySummary(2026, 9);
      expect(summary.earned, closeTo(80.0, 0.001));
      expect(summary.received, closeTo(50.0, 0.001));
      expect(summary.remaining, closeTo(30.0, 0.001));
    });

    test('4. multiple payments → received sums correctly', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'ობიექტი A');
      for (int d = 1; d <= 5; d++) {
        await svc.markWorked(
          date: DateTime(2026, 9, d),
          objectId: obj.id,
          objectName: obj.name,
        );
      }
      // earned = 400
      await svc.addTransaction(amount: 100.0, dateTime: DateTime(2026, 9, 1));
      await svc.addTransaction(amount: 150.0, dateTime: DateTime(2026, 9, 2));
      await svc.addTransaction(amount: 50.0, dateTime: DateTime(2026, 9, 3));
      final summary = svc.getMonthlySummary(2026, 9);
      expect(summary.paymentCount, 3);
      expect(summary.received, closeTo(300.0, 0.001));
      expect(summary.remaining, closeTo(100.0, 0.001));
    });

    test('5. payment deletion → summary updates', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'ობიექტი A');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      final tx = await svc.addTransaction(
        amount: 80.0,
        dateTime: DateTime(2026, 9, 1),
      );
      expect(tx, isNotNull);
      // Before deletion
      var summary = svc.getMonthlySummary(2026, 9);
      expect(summary.received, closeTo(80.0, 0.001));
      expect(summary.remaining, closeTo(0.0, 0.001));
      // Delete payment
      await svc.deleteTransaction(tx!.id);
      summary = svc.getMonthlySummary(2026, 9);
      expect(summary.received, closeTo(0.0, 0.001));
      expect(summary.remaining, closeTo(80.0, 0.001));
      expect(summary.paymentCount, 0);
    });

    test('6. payment edit → summary updates', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'ობიექტი A');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      final tx = await svc.addTransaction(
        amount: 40.0,
        dateTime: DateTime(2026, 9, 1),
      );
      expect(tx, isNotNull);
      // Edit to 60
      await svc.updateTransaction(tx!.copyWith(amount: 60.0));
      final summary = svc.getMonthlySummary(2026, 9);
      expect(summary.received, closeTo(60.0, 0.001));
      expect(summary.remaining, closeTo(20.0, 0.001));
    });

    test('7. different months do not mix', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'ობიექტი A');
      // September: 2 days
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.markWorked(
        date: DateTime(2026, 9, 2),
        objectId: obj.id,
        objectName: obj.name,
      );
      // October: 3 days
      await svc.markWorked(
        date: DateTime(2026, 10, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.markWorked(
        date: DateTime(2026, 10, 2),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.markWorked(
        date: DateTime(2026, 10, 3),
        objectId: obj.id,
        objectName: obj.name,
      );
      final sep = svc.getMonthlySummary(2026, 9);
      final oct = svc.getMonthlySummary(2026, 10);
      expect(sep.workedDays, 2);
      expect(sep.earned, closeTo(160.0, 0.001));
      expect(oct.workedDays, 3);
      expect(oct.earned, closeTo(240.0, 0.001));
    });

    test('8. same month different years do not mix', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'ობიექტი A');
      await svc.markWorked(
        date: DateTime(2025, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      final sep2025 = svc.getMonthlySummary(2025, 9);
      final sep2026 = svc.getMonthlySummary(2026, 9);
      expect(sep2025.workedDays, 1);
      expect(sep2026.workedDays, 1);
      expect(sep2025.earned, closeTo(80.0, 0.001));
      expect(sep2026.earned, closeTo(80.0, 0.001));
    });

    test('9. historical daily wage is used correctly', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'ობიექტი A');
      // Work in September at 80
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      // Change wage to 100
      await svc.updateDailyWage(100.0);
      // September summary must still use 80
      final sep = svc.getMonthlySummary(2026, 9);
      expect(
        sep.earned,
        closeTo(80.0, 0.001),
        reason: 'Historical wage must not change when current wage changes',
      );
    });

    test('10. deleted/completed object WorkDays still count', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'ობიექტი A');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.markWorked(
        date: DateTime(2026, 9, 2),
        objectId: obj.id,
        objectName: obj.name,
      );
      // Complete the object
      await svc.completeObject(obj.id);
      final summary = svc.getMonthlySummary(2026, 9);
      expect(
        summary.workedDays,
        2,
        reason: 'Completed object WorkDays must still count',
      );
      expect(summary.earned, closeTo(160.0, 0.001));
      // Object breakdown must still include the completed object
      expect(summary.objectBreakdown.length, 1);
      expect(summary.objectBreakdown.first.workedDays, 2);
    });

    test('11. future month → empty state', () async {
      final svc = await _makeService(wage: 80.0);
      final now = DateTime.now();
      final futureYear = now.year + 1;
      final summary = svc.getMonthlySummary(futureYear, now.month);
      expect(summary.isEmpty, isTrue);
      expect(summary.workedDays, 0);
      expect(summary.earned, 0.0);
      expect(summary.received, 0.0);
      expect(summary.remaining, 0.0);
      expect(summary.paymentCount, 0);
    });

    test('12. current month calculations are correct', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'ობიექტი A');
      final now = DateTime.now();
      // Mark 3 days this month
      for (int d = 1; d <= 3; d++) {
        await svc.markWorked(
          date: DateTime(now.year, now.month, d),
          objectId: obj.id,
          objectName: obj.name,
        );
      }
      // Add a payment
      await svc.addTransaction(amount: 100.0);
      final summary = svc.getMonthlySummary(now.year, now.month);
      expect(summary.workedDays, 3);
      expect(summary.earned, closeTo(240.0, 0.001));
      expect(summary.received, closeTo(100.0, 0.001));
      expect(summary.remaining, closeTo(140.0, 0.001));
      expect(summary.paymentCount, 1);
      expect(summary.isEmpty, isFalse);
    });

    test('object breakdown shows correct per-object data', () async {
      final svc = await _makeService(wage: 80.0);
      final objA = await svc.createObject(name: 'ობიექტი A');
      final objB = await svc.createObject(name: 'ობიექტი B');
      // A: 3 days, B: 2 days
      for (int d = 1; d <= 3; d++) {
        await svc.markWorked(
          date: DateTime(2026, 9, d),
          objectId: objA.id,
          objectName: objA.name,
        );
      }
      for (int d = 4; d <= 5; d++) {
        await svc.markWorked(
          date: DateTime(2026, 9, d),
          objectId: objB.id,
          objectName: objB.name,
        );
      }
      final summary = svc.getMonthlySummary(2026, 9);
      expect(summary.objectBreakdown.length, 2);
      final a = summary.objectBreakdown.firstWhere(
        (o) => o.objectId == objA.id,
      );
      final b = summary.objectBreakdown.firstWhere(
        (o) => o.objectId == objB.id,
      );
      expect(a.workedDays, 3);
      expect(a.earned, closeTo(240.0, 0.001));
      expect(b.workedDays, 2);
      expect(b.earned, closeTo(160.0, 0.001));
    });

    test('deleted object shows fallback label in breakdown', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'ობიექტი A');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      // Delete the object
      await svc.deleteObject(obj.id);
      final summary = svc.getMonthlySummary(2026, 9);
      expect(summary.workedDays, 1);
      expect(summary.earned, closeTo(80.0, 0.001));
      expect(summary.objectBreakdown.length, 1);
      expect(summary.objectBreakdown.first.isDeleted, isTrue);
      // Fallback label: either snapshot name or 'წაშლილი ობიექტი'
      expect(
        summary.objectBreakdown.first.objectName.isNotEmpty,
        isTrue,
        reason: 'Deleted object must show a non-empty fallback label',
      );
    });
  });

  // ── Version 10 Regression Tests ───────────────────────────────────────────
  group('V10 regression: current daily wage display', () {
    test('getDailyWageForDate returns current period wage for today', () async {
      final svc = await _makeService(wage: 100.0);
      final today = DateTime.now();
      final wage = svc.getDailyWageForDate(today);
      expect(
        wage,
        closeTo(100.0, 0.001),
        reason: 'getDailyWageForDate must return current period wage',
      );
    });

    test('wage change updates current period wage for new workdays', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      final today = DateTime.now();
      // Work at 80
      await svc.markWorked(date: today, objectId: obj.id, objectName: obj.name);
      final wd1 = svc.getWorkDayForDate(today);
      expect(wd1?.dailyWage, closeTo(80.0, 0.001));
      // Change wage to 120 — existing workday must NOT change
      await svc.updateDailyWage(120.0);
      final wd2 = svc.getWorkDayForDate(today);
      expect(
        wd2?.dailyWage,
        closeTo(80.0, 0.001),
        reason: 'Existing WorkDay.dailyWage must not change after wage update',
      );
      // New workday on a different date uses new wage
      final newWage = svc.getDailyWageForDate(today);
      expect(
        newWage,
        closeTo(120.0, 0.001),
        reason: 'getDailyWageForDate must return new wage after update',
      );
    });
  });

  group('V10 regression: payment lifecycle consistency', () {
    test(
      'earned/received/remaining are consistent after full payment',
      () async {
        final svc = await _makeService(wage: 80.0);
        final obj = await svc.createObject(name: 'Test');
        for (int d = 1; d <= 5; d++) {
          await svc.markWorked(
            date: DateTime(2026, 9, d),
            objectId: obj.id,
            objectName: obj.name,
          );
        }
        // earned = 400
        await svc.addTransaction(amount: 200.0);
        await svc.addTransaction(amount: 200.0);
        final total = svc.getTotalSalary();
        expect(total['earned'], closeTo(400.0, 0.001));
        expect(total['received'], closeTo(400.0, 0.001));
        expect(total['remaining'], closeTo(0.0, 0.001));
        // Further payment must be rejected
        final rejected = await svc.addTransaction(amount: 1.0);
        expect(
          rejected,
          isNull,
          reason: 'Payment after full payment must be rejected',
        );
      },
    );

    test('zero payment is rejected', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      final result = await svc.addTransaction(amount: 0.0);
      expect(result, isNull, reason: 'Zero payment must be rejected');
    });

    test('negative payment is rejected', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      final result = await svc.addTransaction(amount: -50.0);
      expect(result, isNull, reason: 'Negative payment must be rejected');
    });

    test('payment equal to remaining is accepted', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      // earned = 80, remaining = 80
      final result = await svc.addTransaction(amount: 80.0);
      expect(
        result,
        isNotNull,
        reason: 'Payment equal to remaining must be accepted',
      );
      final total = svc.getTotalSalary();
      expect(total['remaining'], closeTo(0.0, 0.001));
    });

    test('payment greater than remaining is rejected', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      // earned = 80, try to pay 100
      final result = await svc.addTransaction(amount: 100.0);
      expect(result, isNull, reason: 'Payment > remaining must be rejected');
    });

    test('decimal payment is accepted and calculated correctly', () async {
      final svc = await _makeService(wage: 100.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      final result = await svc.addTransaction(amount: 40.50);
      expect(result, isNotNull, reason: 'Decimal payment must be accepted');
      final total = svc.getTotalSalary();
      expect(total['received'], closeTo(40.50, 0.001));
      expect(total['remaining'], closeTo(59.50, 0.001));
    });
  });

  group('V10 regression: object lifecycle', () {
    test('completed object no longer in activeObjects', () async {
      final svc = await _makeService();
      final obj = await svc.createObject(name: 'Test');
      expect(svc.activeObjects.any((o) => o.id == obj.id), isTrue);
      await svc.completeObject(obj.id);
      expect(
        svc.activeObjects.any((o) => o.id == obj.id),
        isFalse,
        reason: 'Completed object must not appear in activeObjects',
      );
      expect(
        svc.completedObjects.any((o) => o.id == obj.id),
        isTrue,
        reason: 'Completed object must appear in completedObjects',
      );
    });

    test('completed object WorkDays preserved in history', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.completeObject(obj.id);
      // WorkDay must still exist
      final wd = svc.getWorkDayForDate(DateTime(2026, 9, 1));
      expect(wd, isNotNull);
      expect(wd!.isWorked, isTrue);
      expect(wd.objectId, obj.id);
    });

    test('deleted object WorkDays preserved in history', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.deleteObject(obj.id);
      // WorkDay must still exist
      final wd = svc.getWorkDayForDate(DateTime(2026, 9, 1));
      expect(wd, isNotNull);
      expect(wd!.isWorked, isTrue);
      // getObjectById returns null for deleted object
      expect(svc.getObjectById(obj.id), isNull);
    });

    test('salary totals unchanged after object deletion', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      final beforeDelete = svc.getTotalSalary();
      await svc.deleteObject(obj.id);
      final afterDelete = svc.getTotalSalary();
      expect(
        afterDelete['earned'],
        closeTo(beforeDelete['earned']!, 0.001),
        reason: 'Deleting object must not change earned salary',
      );
    });

    test('object change updates existing WorkDay without duplicate', () async {
      final svc = await _makeService(wage: 80.0);
      final objA = await svc.createObject(name: 'Object A');
      final objB = await svc.createObject(name: 'Object B');
      final date = DateTime(2026, 9, 17);
      await svc.markWorked(
        date: date,
        objectId: objA.id,
        objectName: objA.name,
      );
      // Change object on existing worked day
      final existing = svc.getWorkDayForDate(date)!;
      final updated = existing.copyWith(
        objectId: objB.id,
        objectName: objB.name,
      );
      await svc.updateWorkDay(updated);
      // Must still be one WorkDay
      final days = svc.workDays
          .where(
            (d) => d.date.year == 2026 && d.date.month == 9 && d.date.day == 17,
          )
          .toList();
      expect(
        days.length,
        1,
        reason: 'Object change must not create duplicate WorkDay',
      );
      expect(days.first.objectId, objB.id);
      // Salary must not double
      final total = svc.getTotalSalary();
      expect(
        total['earned'],
        closeTo(80.0, 0.001),
        reason: 'Object change must not double-count salary',
      );
    });
  });

  group('V10 regression: monthly summary edge cases', () {
    test('December/January boundary — no cross-month mixing', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      await svc.markWorked(
        date: DateTime(2026, 12, 31),
        objectId: obj.id,
        objectName: obj.name,
      );
      await svc.markWorked(
        date: DateTime(2027, 1, 1),
        objectId: obj.id,
        objectName: obj.name,
      );
      final dec = svc.getMonthlySummary(2026, 12);
      final jan = svc.getMonthlySummary(2027, 1);
      expect(dec.workedDays, 1);
      expect(jan.workedDays, 1);
      expect(dec.earned, closeTo(80.0, 0.001));
      expect(jan.earned, closeTo(80.0, 0.001));
    });

    test('empty month returns isEmpty=true with all zeros', () async {
      final svc = await _makeService(wage: 80.0);
      final summary = svc.getMonthlySummary(2025, 3);
      expect(summary.isEmpty, isTrue);
      expect(summary.workedDays, 0);
      expect(summary.earned, 0.0);
      expect(summary.received, 0.0);
      expect(summary.remaining, 0.0);
      expect(summary.paymentCount, 0);
    });

    test('partial payments reflected correctly in monthly summary', () async {
      final svc = await _makeService(wage: 80.0);
      final obj = await svc.createObject(name: 'Test');
      for (int d = 1; d <= 3; d++) {
        await svc.markWorked(
          date: DateTime(2026, 9, d),
          objectId: obj.id,
          objectName: obj.name,
        );
      }
      // earned = 240, pay 100
      await svc.addTransaction(amount: 100.0, dateTime: DateTime(2026, 9, 1));
      final summary = svc.getMonthlySummary(2026, 9);
      expect(summary.earned, closeTo(240.0, 0.001));
      expect(summary.received, closeTo(100.0, 0.001));
      expect(summary.remaining, closeTo(140.0, 0.001));
    });
  });

  group('Object-bound advances', () {
    test('only future work at the selected object repays an advance', () async {
      final svc = await _makeService(wage: 80.0);
      final objectA = await svc.createObject(name: 'ობიექტი N2');
      final objectB = await svc.createObject(name: 'ობიექტი N1');
      final advance = await svc.addAdvance(
        amount: 1000,
        objectId: objectA.id,
        dateTime: DateTime(2026, 9, 1),
      );
      expect(advance, isNotNull);

      await svc.markWorked(
        date: DateTime(2026, 8, 31),
        objectId: objectA.id,
        objectName: objectA.name,
      );
      for (int day = 1; day <= 2; day++) {
        await svc.markWorked(
          date: DateTime(2026, 9, day),
          objectId: objectA.id,
          objectName: objectA.name,
        );
      }
      await svc.markWorked(
        date: DateTime(2026, 9, 3),
        objectId: objectB.id,
        objectName: objectB.name,
      );

      final balance = svc.getAdvanceBalances(includePaid: true).single;
      expect(balance.repaid, 160);
      expect(balance.remaining, 840);
      expect(svc.getTotalSalary()['advanceRepaid'], 160);
      expect(svc.getTotalSalary()['remaining'], 160);
    });

    test('partial final workday leaves its unused wage payable', () async {
      final svc = await _makeService(wage: 80.0);
      final object = await svc.createObject(name: 'ობიექტი N2');
      await svc.addAdvance(
        amount: 150,
        objectId: object.id,
        dateTime: DateTime(2026, 9, 1),
      );
      for (int day = 1; day <= 2; day++) {
        await svc.markWorked(
          date: DateTime(2026, 9, day),
          objectId: object.id,
          objectName: object.name,
        );
      }

      final balance = svc.getAdvanceBalances(includePaid: true).single;
      expect(balance.repaid, 150);
      expect(balance.remaining, 0);
      expect(svc.getTotalSalary()['remaining'], 10);
      final monthly = svc.getMonthlySummary(2026, 9);
      expect(monthly.advanceRepaid, 150);
      expect(monthly.remaining, 10);
    });

    test('deleting an advance restores the wage balance', () async {
      final svc = await _makeService(wage: 80.0);
      final object = await svc.createObject(name: 'ობიექტი N2');
      final advance = await svc.addAdvance(
        amount: 80,
        objectId: object.id,
        dateTime: DateTime(2026, 9, 1),
      );
      await svc.markWorked(
        date: DateTime(2026, 9, 1),
        objectId: object.id,
        objectName: object.name,
      );
      expect(svc.getTotalSalary()['remaining'], 0);

      await svc.deleteAdvance(advance!.id);

      expect(svc.getAdvanceBalances(includePaid: true), isEmpty);
      expect(svc.getTotalSalary()['advanceRepaid'], 0);
      expect(svc.getTotalSalary()['remaining'], 80);
    });

    test('advances persist when the service is reloaded', () async {
      final storage = _FakeStorage();
      final svc = DataService(storage);
      await svc.init();
      final object = await svc.createObject(name: 'ობიექტი N2');
      await svc.addAdvance(
        amount: 300,
        objectId: object.id,
        dateTime: DateTime(2026, 9, 1),
      );

      final reloaded = DataService(storage);
      await reloaded.init();

      expect(reloaded.getAdvanceBalances().single.remaining, 300);
      expect(
        reloaded.getAdvanceBalances().single.advance.objectName,
        'ობიექტი N2',
      );
    });
  });
}
