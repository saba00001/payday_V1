import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:payday/services/backup/backup_document.dart';
import 'package:payday/services/backup/backup_platform.dart';
import 'package:payday/services/backup/backup_service.dart';
import 'package:payday/services/storage/local_storage_service.dart';
import 'package:payday/services/data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupDocument', () {
    test('round-trips and verifies the checksum', () {
      final document = BackupDocument(
        createdAt: DateTime.utc(2026, 10, 17, 12),
        data: _validData(),
      );
      final decoded = BackupDocument.decode(document.encode());

      expect(decoded.createdAt, document.createdAt);
      expect(decoded.data, document.data);
    });

    test('rejects tampered or unknown-format backup documents', () {
      final encoded =
          jsonDecode(
                BackupDocument(
                  createdAt: DateTime.utc(2026),
                  data: _validData(),
                ).encode(),
              )
              as Map<String, dynamic>;
      encoded['data']['dailyWage'] = 999;

      expect(
        () => BackupDocument.decode(jsonEncode(encoded)),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BackupDocument.decode('{"format":"unknown","version":4}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects duplicate identifiers and invalid financial records', () {
      final invalid = _validData();
      invalid['advances'] = [_advance(), _advance()];

      expect(
        () => BackupDocument.validateData(invalid),
        throwsA(isA<FormatException>()),
      );
      invalid['advances'] = [
        {..._advance(), 'amount': -1},
      ];
      expect(
        () => BackupDocument.validateData(invalid),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'accepts compatible legacy records with defaulted optional fields',
      () {
        final legacyData = _validData()
          ..['objects'] = [
            {'id': 'old-object', 'name': 'ძველი ობიექტი'},
          ]
          ..['workDays'] = [
            {
              'id': 'old-day',
              'date': '2026-09-17T00:00:00.000',
              'status': 'worked',
            },
          ]
          ..['periods'] = [<String, Object?>{}];

        final decoded = BackupDocument.decode(
          BackupDocument(
            createdAt: DateTime.utc(2026),
            data: legacyData,
          ).encode(),
        );

        expect(decoded.data['objects'], legacyData['objects']);
        expect(decoded.data['workDays'], legacyData['workDays']);
        expect(decoded.data['periods'], legacyData['periods']);
      },
    );
  });

  group('BackupService', () {
    test(
      'first launch with empty storage initializes without data loss',
      () async {
        SharedPreferences.setMockInitialValues({});
        final storage = LocalStorageService();
        final service = DataService(storage);

        await service.init();

        expect(storage.hadExistingDataAtInitialization, isFalse);
        expect(service.objects, isEmpty);
        expect(service.workDays, isEmpty);
        expect(service.transactions, isEmpty);
        expect(service.advances, isEmpty);
        expect(service.getTotalSalary()['remaining'], 0);

        final nextLaunchStorage = LocalStorageService();
        await nextLaunchStorage.init();
        expect(nextLaunchStorage.hadExistingDataAtInitialization, isTrue);
      },
    );

    test(
      'older stored records load and remain in preferences unchanged',
      () async {
        final oldObject = jsonEncode([
          {'id': 'site-old', 'name': 'ძველი ობიექტი'},
        ]);
        final oldAdvance = jsonEncode([
          {
            'id': 'advance-old',
            'amount': 120.0,
            'dateTime': '2026-09-01T09:00:00.000',
          },
        ]);
        final oldWorkDay = jsonEncode([
          {
            'id': 'work-old',
            'date': '2026-09-02T00:00:00.000',
            'status': 'worked',
            'dailyWage': 80.0,
          },
        ]);
        SharedPreferences.setMockInitialValues({
          'payday_objects_v1': oldObject,
          'payday_advances_v1': oldAdvance,
          'payday_workdays_v1': oldWorkDay,
        });
        final storage = LocalStorageService();
        final service = DataService(storage);

        await service.init();

        expect(storage.hadExistingDataAtInitialization, isTrue);
        expect(service.objects.single.name, 'ძველი ობიექტი');
        expect(service.advances.single.objectId, isEmpty);
        expect(service.workDays.single.dailyWage, 80);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('payday_objects_v1'), oldObject);
        expect(prefs.getString('payday_advances_v1'), oldAdvance);
        expect(prefs.getString('payday_workdays_v1'), oldWorkDay);
        expect(prefs.getString('payday_pre_migration_backup_v1'), isNotNull);
      },
    );

    test(
      'restores validated data and preserves a private pre-restore copy',
      () async {
        SharedPreferences.setMockInitialValues({
          'payday_objects_v1': '[]',
          'payday_daily_wage_v1': 80.0,
        });
        final directory = await Directory.systemTemp.createTemp(
          'payday-backup',
        );
        addTearDown(() => directory.delete(recursive: true));
        final storage = LocalStorageService();
        await storage.init();
        final platform = _FakeBackupPlatform(directory.path);
        final service = BackupService(storage, platform: platform);
        final backup = BackupDocument(
          createdAt: DateTime.utc(2026, 1),
          data: _validData()..['dailyWage'] = 120.0,
        );

        await service.restore(backup);

        expect(storage.loadDailyWage(), 120);
        expect(
          Directory(
            '${directory.path}${Platform.pathSeparator}snapshots',
          ).listSync().whereType<File>().length,
          1,
        );
      },
    );

    test(
      'a corrupt existing collection is not treated as empty data',
      () async {
        const corrupt = '{broken';
        SharedPreferences.setMockInitialValues({'payday_objects_v1': corrupt});
        final storage = LocalStorageService();
        await storage.init();

        expect(storage.hadExistingDataAtInitialization, isTrue);
        expect(
          () => storage.loadObjects(),
          throwsA(isA<LocalStorageException>()),
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('payday_objects_v1'), corrupt);
      },
    );

    test('invalid restore data leaves current user data unchanged', () async {
      SharedPreferences.setMockInitialValues({
        'payday_objects_v1': '[{"id":"current","name":"Current"}]',
        'payday_daily_wage_v1': 80.0,
      });
      final directory = await Directory.systemTemp.createTemp('payday-backup');
      addTearDown(() => directory.delete(recursive: true));
      final storage = LocalStorageService();
      await storage.init();
      final service = BackupService(
        storage,
        platform: _FakeBackupPlatform(directory.path),
      );
      final invalidData = _validData()..['dailyWage'] = -1.0;

      await expectLater(
        service.restore(
          BackupDocument(createdAt: DateTime.utc(2026), data: invalidData),
        ),
        throwsA(isA<FormatException>()),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('payday_objects_v1'),
        '[{"id":"current","name":"Current"}]',
      );
      expect(storage.loadDailyWage(), 80);
      expect(
        Directory(
          '${directory.path}${Platform.pathSeparator}snapshots',
        ).existsSync(),
        isFalse,
      );
    });

    test(
      'a valid backup can recover corrupt local data without losing its raw snapshot',
      () async {
        SharedPreferences.setMockInitialValues({
          'payday_objects_v1': '{broken',
        });
        final directory = await Directory.systemTemp.createTemp(
          'payday-backup',
        );
        addTearDown(() => directory.delete(recursive: true));
        final storage = LocalStorageService();
        await storage.init();
        final service = BackupService(
          storage,
          platform: _FakeBackupPlatform(directory.path),
        );

        await service.restore(
          BackupDocument(createdAt: DateTime.utc(2026), data: _validData()),
        );

        expect(storage.loadObjects(), isEmpty);
        final rawSnapshots = Directory(
          '${directory.path}${Platform.pathSeparator}snapshots',
        ).listSync().whereType<File>();
        expect(rawSnapshots.single.path, contains('payday-recovery-'));
        expect(await rawSnapshots.single.readAsString(), contains('{broken'));
      },
    );

    test(
      'invalid selected backup leaves current preferences unchanged',
      () async {
        SharedPreferences.setMockInitialValues({'payday_daily_wage_v1': 80.0});
        final directory = await Directory.systemTemp.createTemp(
          'payday-backup',
        );
        addTearDown(() => directory.delete(recursive: true));
        final storage = LocalStorageService();
        await storage.init();
        final selected = File(
          '${directory.path}${Platform.pathSeparator}bad.json',
        )..writeAsStringSync('{"format":"bad"}');
        final service = BackupService(
          storage,
          platform: _FakeBackupPlatform(directory.path, selected.path),
        );

        await expectLater(
          service.selectBackup(),
          throwsA(isA<FormatException>()),
        );
        expect(storage.loadDailyWage(), 80);
      },
    );

    test(
      'unavailable selected backup leaves current preferences unchanged',
      () async {
        SharedPreferences.setMockInitialValues({'payday_daily_wage_v1': 80.0});
        final directory = await Directory.systemTemp.createTemp(
          'payday-backup',
        );
        addTearDown(() => directory.delete(recursive: true));
        final storage = LocalStorageService();
        await storage.init();
        final service = BackupService(
          storage,
          platform: _FakeBackupPlatform(
            directory.path,
            '${directory.path}${Platform.pathSeparator}missing.json',
          ),
        );

        await expectLater(
          service.selectBackup(),
          throwsA(isA<FileSystemException>()),
        );
        expect(storage.loadDailyWage(), 80);
      },
    );

    test('internal backup discovery returns only valid backups', () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp('payday-backup');
      addTearDown(() => directory.delete(recursive: true));
      final storage = LocalStorageService();
      await storage.init();
      final service = BackupService(
        storage,
        platform: _FakeBackupPlatform(directory.path),
      );
      final snapshots = Directory(
        '${directory.path}${Platform.pathSeparator}snapshots',
      );
      await snapshots.create(recursive: true);
      await File(
        '${snapshots.path}${Platform.pathSeparator}valid.json',
      ).writeAsString(
        BackupDocument(
          createdAt: DateTime.utc(2026),
          data: _validData(),
        ).encode(),
      );
      await File(
        '${snapshots.path}${Platform.pathSeparator}broken.json',
      ).writeAsString('{broken');

      final inventory = await service.discoverInternalBackups();

      expect(inventory.backups, hasLength(1));
      expect(inventory.invalidFiles, 1);
    });
  });
}

Map<String, Object?> _validData() => {
  'objects': <Map<String, Object?>>[],
  'workDays': <Map<String, Object?>>[],
  'transactions': <Map<String, Object?>>[],
  'advances': <Map<String, Object?>>[],
  'periods': <Map<String, Object?>>[],
  'dailyWage': 80.0,
  'reminderEnabled': false,
  'reminderHour': 9,
  'reminderMinute': 0,
  'workSchedule': [1, 2, 3, 4, 5],
};

Map<String, Object?> _advance() => {
  'id': 'advance-1',
  'amount': 25.0,
  'dateTime': '2026-01-01T00:00:00.000Z',
  'objectId': 'object-1',
  'objectName': 'Object 1',
};

class _FakeBackupPlatform implements BackupPlatform {
  final String root;
  final String? selectedPath;

  _FakeBackupPlatform(this.root, [this.selectedPath]);

  @override
  Future<String> getInternalBackupDirectory() async =>
      '$root${Platform.pathSeparator}snapshots';

  @override
  Future<String> getTransferDirectory() async =>
      '$root${Platform.pathSeparator}transfer';

  @override
  Future<bool> saveBackupFile(String temporaryFilePath) async => true;

  @override
  Future<String?> selectBackupFile() async => selectedPath;
}
