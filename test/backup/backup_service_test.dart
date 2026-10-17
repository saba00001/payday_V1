import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:payday/services/backup/backup_document.dart';
import 'package:payday/services/backup/backup_platform.dart';
import 'package:payday/services/backup/backup_service.dart';
import 'package:payday/services/storage/local_storage_service.dart';
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
  });

  group('BackupService', () {
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
        SharedPreferences.setMockInitialValues({
          'payday_objects_v1': '{broken',
        });
        final storage = LocalStorageService();
        await storage.init();

        expect(
          () => storage.loadObjects(),
          throwsA(isA<LocalStorageException>()),
        );
      },
    );

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
