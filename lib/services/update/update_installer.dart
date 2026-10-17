import 'package:flutter/services.dart';

import 'github_release.dart';

enum InstallerResult { launched, permissionRequired }

abstract interface class UpdateInstaller {
  Future<String> getInstalledVersion();
  Future<String> getUpdateDirectory();
  Future<bool> canInstallUnknownApps();
  Future<void> openInstallPermissionSettings();
  Future<void> installApk(String path);
}

final class AndroidUpdateInstaller implements UpdateInstaller {
  static const MethodChannel _channel = MethodChannel(
    'com.example.payday/updater',
  );

  @override
  Future<String> getInstalledVersion() async {
    final version = await _channel.invokeMethod<String>('getInstalledVersion');
    if (version == null || version.isEmpty) {
      throw const UpdateException('აპის დაინსტალირებული ვერსიის წაკითხვა ვერ მოხერხდა.');
    }
    return version;
  }

  @override
  Future<String> getUpdateDirectory() async {
    final path = await _channel.invokeMethod<String>('getUpdateDirectory');
    if (path == null || path.isEmpty) {
      throw const UpdateException('განახლების ფაილის ადგილი ვერ მომზადდა.');
    }
    return path;
  }

  @override
  Future<bool> canInstallUnknownApps() async =>
      await _channel.invokeMethod<bool>('canInstallUnknownApps') ?? false;

  @override
  Future<void> openInstallPermissionSettings() async {
    await _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  @override
  Future<void> installApk(String path) async {
    await _channel.invokeMethod<void>('installApk', {'path': path});
  }
}
