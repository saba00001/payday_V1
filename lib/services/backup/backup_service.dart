import 'dart:convert';
import 'dart:io';

import '../storage/local_storage_service.dart';
import 'backup_document.dart';
import 'backup_platform.dart';

final class BackupService {
  final LocalStorageService _storage;
  final BackupPlatform _platform;
  final DateTime Function() _now;

  BackupService(
    this._storage, {
    BackupPlatform? platform,
    DateTime Function()? now,
  }) : _platform = platform ?? AndroidBackupPlatform(),
       _now = now ?? DateTime.now;

  Future<DateTime?> createExternalBackup() async {
    final document = BackupDocument(
      createdAt: _now(),
      data: await _storage.exportBackupData(),
    );
    final directory = Directory(await _platform.getTransferDirectory());
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}${Platform.pathSeparator}payday-backup-transfer.json',
    );
    await file.writeAsString(document.encode(), flush: true);
    try {
      final saved = await _platform.saveBackupFile(file.path);
      if (!saved) return null;
      final createdAt = _now();
      await _storage.saveLastBackupAt(createdAt);
      return createdAt;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<BackupDocument?> selectBackup() async {
    final path = await _platform.selectBackupFile();
    if (path == null) return null;
    try {
      final contents = await File(path).readAsString();
      return BackupDocument.decode(contents);
    } finally {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> restore(BackupDocument document) async {
    BackupDocument.validateData(document.data);
    await createInternalSnapshot();
    await _storage.restoreBackupData(document.data);
  }

  Future<void> createInternalSnapshot() async {
    final directory = Directory(await _platform.getInternalBackupDirectory());
    await directory.create(recursive: true);
    final entries =
        directory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .toList()
          ..sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
          );
    for (final oldFile in entries.skip(4)) {
      await oldFile.delete();
    }
    final stamp = _now().toUtc().toIso8601String().replaceAll(':', '-');
    try {
      final document = BackupDocument(
        createdAt: _now(),
        data: await _storage.exportBackupData(),
      );
      await File(
        '${directory.path}${Platform.pathSeparator}payday-before-restore-$stamp.json',
      ).writeAsString(document.encode(), flush: true);
    } on LocalStorageException {
      final rawState = _storage.exportRawStorageState();
      await File(
        '${directory.path}${Platform.pathSeparator}payday-recovery-$stamp.json',
      ).writeAsString(
        jsonEncode({
          'format': 'payday-raw-recovery',
          'createdAt': _now().toUtc().toIso8601String(),
          'data': rawState,
        }),
        flush: true,
      );
    }
  }
}
