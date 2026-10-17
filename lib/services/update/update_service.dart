import 'dart:io';

import 'package:crypto/crypto.dart';

import 'github_release.dart';
import 'github_release_repository.dart';
import 'semantic_version.dart';
import 'update_installer.dart';
import 'update_transfer.dart';

final class UpdateCheckResult {
  final String installedVersion;
  final GitHubRelease release;

  const UpdateCheckResult({
    required this.installedVersion,
    required this.release,
  });

  SemanticVersion get installedSemanticVersion =>
      SemanticVersion.tryParse(installedVersion)!;

  bool get updateRequired =>
      release.version.compareTo(installedSemanticVersion) > 0;
}

abstract interface class MandatoryUpdateService {
  Future<UpdateCheckResult> checkForUpdate();
  Future<String> downloadAndVerify(
    GitHubRelease release, {
    required void Function(int received, int total) onProgress,
  });
  Future<InstallerResult> installVerifiedApk(String path);
  Future<void> openInstallPermissionSettings();
}

final class UpdateService implements MandatoryUpdateService {
  final ReleaseRepository _repository;
  final UpdateTransfer _transfer;
  final UpdateInstaller _installer;

  UpdateService({
    ReleaseRepository? repository,
    UpdateTransfer? transfer,
    UpdateInstaller? installer,
  }) : _repository = repository ?? GitHubReleaseRepository(),
       _transfer = transfer ?? DioUpdateTransfer(),
       _installer = installer ?? AndroidUpdateInstaller();

  @override
  Future<UpdateCheckResult> checkForUpdate() async {
    final installedVersion = await _installer.getInstalledVersion();
    final installed = SemanticVersion.tryParse(installedVersion);
    if (installed == null) {
      throw const UpdateException('დაინსტალირებული აპის ვერსია არასწორია.');
    }
    final release = await _repository.fetchLatestStableRelease();
    return UpdateCheckResult(
      installedVersion: installedVersion,
      release: release,
    );
  }

  @override
  Future<String> downloadAndVerify(
    GitHubRelease release, {
    required void Function(int received, int total) onProgress,
  }) async {
    final checksumText = await _transfer.getText(release.checksum.downloadUrl);
    final expectedChecksum = _readChecksum(
      checksumText,
      release.apk.name,
      release.checksum.name,
    );
    final directoryPath = await _installer.getUpdateDirectory();
    final directory = Directory(directoryPath);
    try {
      await directory.create(recursive: true);
      final apk = File(
        '${directory.path}${Platform.pathSeparator}payday-update.apk',
      );
      final partial = File('${apk.path}.part');
      if (await partial.exists()) await partial.delete();
      try {
        await _transfer.downloadToFile(
          release.apk.downloadUrl,
          partial,
          onProgress: onProgress,
        );
        if (!await partial.exists() || await partial.length() == 0) {
          throw const UpdateException('ჩამოტვირთული APK ცარიელია.');
        }
        final length = await partial.length();
        if (release.apk.size > 0 && length != release.apk.size) {
          throw const UpdateException(
            'ჩამოტვირთული APK-ის ზომა GitHub Release-ის მონაცემებს არ ემთხვევა.',
          );
        }
        final signature = await partial
            .openRead(0, 4)
            .fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
        if (signature.length != 4 ||
            signature[0] != 0x50 ||
            signature[1] != 0x4b ||
            signature[2] != 0x03 ||
            signature[3] != 0x04) {
          throw const UpdateException('ჩამოტვირთული ფაილი APK არ არის.');
        }
        final actualChecksum = (await sha256.bind(partial.openRead()).first)
            .toString();
        if (actualChecksum.toLowerCase() != expectedChecksum.toLowerCase()) {
          throw const UpdateException(
            'APK-ის SHA-256 checksum არ ემთხვევა. უსაფრთხოების მიზნით ფაილი არ დაინსტალირდება.',
          );
        }
        if (await apk.exists()) await apk.delete();
        return (await partial.rename(apk.path)).path;
      } catch (_) {
        if (await partial.exists()) await partial.delete();
        rethrow;
      }
    } on UpdateException {
      rethrow;
    } on FileSystemException {
      throw const UpdateException(
        'APK-ის შენახვა ვერ მოხერხდა. გაათავისუფლე მოწყობილობის მეხსიერება და სცადე თავიდან.',
      );
    }
  }

  @override
  Future<InstallerResult> installVerifiedApk(String path) async {
    if (!await _installer.canInstallUnknownApps()) {
      return InstallerResult.permissionRequired;
    }
    await _installer.installApk(path);
    return InstallerResult.launched;
  }

  @override
  Future<void> openInstallPermissionSettings() =>
      _installer.openInstallPermissionSettings();

  String _readChecksum(String text, String apkName, String checksumAssetName) {
    final lines = text.split(RegExp(r'\r?\n')).map((line) => line.trim());
    final checksumPattern = RegExp(r'^([a-fA-F0-9]{64})(?:\s+\*?(.+))?$');
    final checksumsForApk = <String>[];
    var nonEmptyLineCount = 0;
    var hasUnlabelledDigest = false;
    for (final line in lines) {
      if (line.isEmpty) continue;
      nonEmptyLineCount++;
      final match = checksumPattern.firstMatch(line);
      if (match == null) {
        throw const UpdateException('რელიზის SHA-256 checksum არასწორია.');
      }
      final fileName = match.group(2);
      if (fileName == apkName) {
        checksumsForApk.add(match.group(1)!);
      } else if (fileName == null) {
        hasUnlabelledDigest = true;
      }
    }
    final isSingleApkChecksum =
        checksumAssetName.toLowerCase() == '${apkName.toLowerCase()}.sha256' &&
        nonEmptyLineCount == 1 &&
        (checksumsForApk.length == 1 || hasUnlabelledDigest);
    final isChecksumManifest =
        checksumAssetName.toLowerCase() == 'sha256sums' &&
        checksumsForApk.length == 1 &&
        !hasUnlabelledDigest;
    if (!isSingleApkChecksum && !isChecksumManifest) {
      throw const UpdateException(
        'რელიზში APK-ის სანდო SHA-256 checksum ვერ მოიძებნა.',
      );
    }
    return checksumsForApk.isNotEmpty
        ? checksumsForApk.single
        : RegExp(r'^[a-fA-F0-9]{64}').firstMatch(text.trim())!.group(0)!;
  }
}
