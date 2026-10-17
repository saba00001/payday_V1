import 'package:flutter/services.dart';

abstract interface class BackupPlatform {
  Future<String> getTransferDirectory();
  Future<String> getInternalBackupDirectory();
  Future<bool> saveBackupFile(String temporaryFilePath);
  Future<String?> selectBackupFile();
}

final class AndroidBackupPlatform implements BackupPlatform {
  static const _channel = MethodChannel('com.example.payday/backup');

  @override
  Future<String> getTransferDirectory() async => _requiredPath(
    await _channel.invokeMethod<String>('getTransferDirectory'),
  );

  @override
  Future<String> getInternalBackupDirectory() async => _requiredPath(
    await _channel.invokeMethod<String>('getInternalBackupDirectory'),
  );

  @override
  Future<bool> saveBackupFile(String temporaryFilePath) async =>
      await _channel.invokeMethod<bool>('saveBackupFile', {
        'path': temporaryFilePath,
      }) ??
      false;

  @override
  Future<String?> selectBackupFile() =>
      _channel.invokeMethod<String>('selectBackupFile');

  String _requiredPath(String? value) {
    if (value == null || value.isEmpty) {
      throw PlatformException(
        code: 'BACKUP_PATH_UNAVAILABLE',
        message: 'Backup საქაღალდის მომზადება ვერ მოხერხდა.',
      );
    }
    return value;
  }
}
