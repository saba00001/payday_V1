import 'dart:convert';
import 'dart:io';

import '../storage/local_storage_service.dart';
import 'backup_document.dart';
import 'backup_platform.dart';

final class LocalBackupEntry {
  final String path;
  final BackupDocument document;

  const LocalBackupEntry({required this.path, required this.document});
}

final class LocalBackupInventory {
  final List<LocalBackupEntry> backups;
  final int invalidFiles;

  const LocalBackupInventory({
    required this.backups,
    required this.invalidFiles,
  });
}

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
      '${directory.path}${Platform.pathSeparator}'
      'payday-backup-transfer-${_now().microsecondsSinceEpoch}.json',
    );
    await _writeAtomically(file, document.encode());
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
    final stamp = _now().toUtc().microsecondsSinceEpoch.toString();
    final destination = File(
      '${directory.path}${Platform.pathSeparator}'
      'payday-before-restore-$stamp.json',
    );
    try {
      final document = BackupDocument(
        createdAt: _now(),
        data: await _storage.exportBackupData(),
      );
      await _writeAtomically(destination, document.encode());
    } on LocalStorageException {
      final rawState = _storage.exportRawStorageState();
      await _writeAtomically(
        File(
          '${directory.path}${Platform.pathSeparator}'
          'payday-recovery-$stamp.json',
        ),
        jsonEncode({
          'format': 'payday-raw-recovery',
          'createdAt': _now().toUtc().toIso8601String(),
          'data': rawState,
        }),
      );
    }
    final entries =
        directory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .toList()
          ..sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
          );
    for (final oldFile in entries.skip(5)) {
      await oldFile.delete();
    }
  }

  Future<LocalBackupInventory> discoverInternalBackups() async {
    final directory = Directory(await _platform.getInternalBackupDirectory());
    if (!await directory.exists()) {
      return const LocalBackupInventory(backups: [], invalidFiles: 0);
    }
    final files = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final backups = <LocalBackupEntry>[];
    var invalidFiles = 0;
    for (final file in files) {
      try {
        final document = BackupDocument.decode(await file.readAsString());
        backups.add(LocalBackupEntry(path: file.path, document: document));
      } on Object {
        invalidFiles++;
      }
    }
    return LocalBackupInventory(
      backups: List.unmodifiable(backups),
      invalidFiles: invalidFiles,
    );
  }

  Future<void> _writeAtomically(File destination, String contents) async {
    final temporary = File(
      '${destination.path}.tmp-${_now().microsecondsSinceEpoch}',
    );
    try {
      await temporary.writeAsString(contents, flush: true);
      await temporary.rename(destination.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
