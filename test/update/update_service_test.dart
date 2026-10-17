import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payday/presentation/update/mandatory_update_gate.dart';
import 'package:payday/services/update/github_release.dart';
import 'package:payday/services/update/github_release_repository.dart';
import 'package:payday/services/update/semantic_version.dart';
import 'package:payday/services/update/update_installer.dart';
import 'package:payday/services/update/update_service.dart';
import 'package:payday/services/update/update_transfer.dart';

void main() {
  group('SemanticVersion', () {
    test('compares patch and multi-digit minor versions semantically', () {
      final v100 = SemanticVersion.tryParse('1.0.0')!;
      final v101 = SemanticVersion.tryParse('v1.0.1')!;
      final v110 = SemanticVersion.tryParse('1.10.0')!;
      final v190 = SemanticVersion.tryParse('1.9.0')!;

      expect(v100.compareTo(v101), lessThan(0));
      expect(v110.compareTo(v190), greaterThan(0));
      expect(v100.compareTo(SemanticVersion.tryParse('1.0.0')!), 0);
    });

    test('build metadata does not change semantic version precedence', () {
      final first = SemanticVersion.tryParse('1.0.0+1')!;
      final second = SemanticVersion.tryParse('v1.0.0+28')!;

      expect(first.compareTo(second), 0);
    });

    test('older and malformed versions are distinguished safely', () {
      expect(
        SemanticVersion.tryParse(
          '0.9.9',
        )!.compareTo(SemanticVersion.tryParse('1.0.0')!),
        lessThan(0),
      );
      expect(SemanticVersion.tryParse('latest'), isNull);
      expect(SemanticVersion.tryParse('1.02.0'), isNull);
      expect(SemanticVersion.tryParse('1.0'), isNull);
      expect(SemanticVersion.tryParse('1.0.0-01'), isNull);
    });
  });

  group('GitHub release validation', () {
    test('ignores draft and prerelease releases', () {
      for (final flags in [
        {'draft': true, 'prerelease': false},
        {'draft': false, 'prerelease': true},
      ]) {
        expect(
          () => GitHubRelease.fromJson(
            _releaseJson()..addAll(flags),
            owner: 'payday-owner',
            repository: 'payday-app',
          ),
          throwsA(isA<UpdateException>()),
        );
      }
    });

    test('rejects malformed tags and a missing APK asset', () {
      expect(
        () => GitHubRelease.fromJson(
          _releaseJson(tag: 'release-1'),
          owner: 'payday-owner',
          repository: 'payday-app',
        ),
        throwsA(isA<UpdateException>()),
      );
      expect(
        () => GitHubRelease.fromJson(
          _releaseJson(assets: [_checksumAsset()]),
          owner: 'payday-owner',
          repository: 'payday-app',
        ),
        throwsA(isA<UpdateException>()),
      );
    });

    test('rejects invalid or foreign APK and checksum URLs', () {
      final invalidAssets = [
        [
          _apkAsset(
            url:
                'http://github.com/payday-owner/payday-app/releases/download/v1.0.1/app.apk',
          ),
          _checksumAsset(),
        ],
        [
          _apkAsset(
            url:
                'https://evil.example/payday-owner/payday-app/releases/download/v1.0.1/app.apk',
          ),
          _checksumAsset(),
        ],
        [
          _apkAsset(),
          _checksumAsset(url: 'https://evil.example/app.apk.sha256'),
        ],
      ];

      for (final assets in invalidAssets) {
        expect(
          () => GitHubRelease.fromJson(
            _releaseJson(assets: assets),
            owner: 'payday-owner',
            repository: 'payday-app',
          ),
          throwsA(isA<UpdateException>()),
        );
      }
    });

    test('requires a checksum asset matching the APK', () {
      expect(
        () => GitHubRelease.fromJson(
          _releaseJson(assets: [_apkAsset()]),
          owner: 'payday-owner',
          repository: 'payday-app',
        ),
        throwsA(isA<UpdateException>()),
      );
    });

    test('failed GitHub HTTP requests report an explicit failure', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException.connectionError(
              requestOptions: options,
              reason: 'offline',
            ),
          ),
        ),
      );
      final repository = GitHubReleaseRepository(
        dio: dio,
        repository: 'payday-owner/payday-app',
      );

      await expectLater(
        repository.fetchLatestStableRelease(),
        throwsA(
          isA<UpdateException>().having(
            (error) => error.message,
            'message',
            contains('ინტერნეტთან'),
          ),
        ),
      );
    });

    test(
      'GitHub rate limits are reported without accepting a release',
      () async {
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.reject(
              DioException.badResponse(
                statusCode: 403,
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 403,
                  data: {'message': 'API rate limit exceeded'},
                ),
              ),
            ),
          ),
        );

        await expectLater(
          GitHubReleaseRepository(
            dio: dio,
            repository: 'payday-owner/payday-app',
          ).fetchLatestStableRelease(),
          throwsA(
            isA<UpdateException>().having(
              (error) => error.message,
              'message',
              contains('ლიმიტი'),
            ),
          ),
        );
      },
    );
  });

  group('UpdateService', () {
    test('same installed version does not require an update', () async {
      final service = _service(
        installedVersion: '1.0.0+1',
        release: _release(tag: 'v1.0.0'),
      );
      final result = await service.checkForUpdate();

      expect(result.updateRequired, isFalse);
    });

    test('newer stable release requires a mandatory update', () async {
      final service = _service(installedVersion: '1.0.0', release: _release());
      final result = await service.checkForUpdate();

      expect(result.updateRequired, isTrue);
      expect(result.release.tagName, 'v1.0.1');
    });

    test('an older stable release does not request a downgrade', () async {
      final service = _service(
        installedVersion: '1.0.1',
        release: _release(tag: 'v1.0.0'),
      );

      expect((await service.checkForUpdate()).updateRequired, isFalse);
    });

    test(
      'valid checksum APK is saved and passed to Android installer',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'payday-update',
        );
        addTearDown(() => directory.delete(recursive: true));
        final transfer = _MemoryTransfer();
        final installer = _FakeInstaller(directory.path);
        final service = _service(transfer: transfer, installer: installer);

        final path = await service.downloadAndVerify(
          _release(),
          onProgress: (_, _) {},
        );
        expect(await File(path).readAsBytes(), transfer.apkBytes);
        expect(
          await service.installVerifiedApk(path),
          InstallerResult.launched,
        );
        expect(installer.installedPath, path);
      },
    );

    test('malformed installed version fails closed', () async {
      final service = _service(installedVersion: 'not-a-version');

      await expectLater(
        service.checkForUpdate(),
        throwsA(isA<UpdateException>()),
      );
    });

    test('invalid checksum prevents download and install', () async {
      final directory = await Directory.systemTemp.createTemp('payday-update');
      addTearDown(() => directory.delete(recursive: true));
      final transfer = _MemoryTransfer(checksumText: 'not-a-sha256');
      final service = _service(
        transfer: transfer,
        installer: _FakeInstaller(directory.path),
      );

      await expectLater(
        service.downloadAndVerify(_release(), onProgress: (_, _) {}),
        throwsA(isA<UpdateException>()),
      );
      expect(transfer.downloadCalls, 0);
    });

    test('mismatching APK checksum prevents installation', () async {
      final directory = await Directory.systemTemp.createTemp('payday-update');
      addTearDown(() => directory.delete(recursive: true));
      final transfer = _MemoryTransfer(
        checksumText: '${List.filled(64, '0').join()} app.apk',
        apkBytes: [0x50, 0x4b, 0x03, 0x04, 0x01],
      );
      final service = _service(
        transfer: transfer,
        installer: _FakeInstaller(directory.path),
      );

      await expectLater(
        service.downloadAndVerify(_release(), onProgress: (_, _) {}),
        throwsA(isA<UpdateException>()),
      );
    });

    test('malformed APK is rejected even when checksum matches', () async {
      final directory = await Directory.systemTemp.createTemp('payday-update');
      addTearDown(() => directory.delete(recursive: true));
      final transfer = _MemoryTransfer(
        apkBytes: const [0x00, 0x01, 0x02, 0x03, 0x04],
      );
      final installer = _FakeInstaller(directory.path);
      final service = _service(transfer: transfer, installer: installer);

      await expectLater(
        service.downloadAndVerify(_release(), onProgress: (_, _) {}),
        throwsA(
          isA<UpdateException>().having(
            (error) => error.message,
            'message',
            contains('APK არ არის'),
          ),
        ),
      );
      expect(installer.installedPath, isNull);
    });

    test(
      'download interruption is surfaced and partial file is removed',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'payday-update',
        );
        addTearDown(() => directory.delete(recursive: true));
        final transfer = _MemoryTransfer(
          checksumText: '${List.filled(64, 'a').join()} app.apk',
          downloadError: const UpdateException('download interrupted'),
        );
        final service = _service(
          transfer: transfer,
          installer: _FakeInstaller(directory.path),
        );

        await expectLater(
          service.downloadAndVerify(_release(), onProgress: (_, _) {}),
          throwsA(
            isA<UpdateException>().having(
              (error) => error.message,
              'message',
              'download interrupted',
            ),
          ),
        );
        expect(
          await File('${directory.path}/payday-update.apk.part').exists(),
          isFalse,
        );
      },
    );
  });

  group('Mandatory update gate', () {
    testWidgets('offline check keeps app usable and retries when resumed', (
      tester,
    ) async {
      final service = _FakeMandatoryService()..checkFailuresRemaining = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: MandatoryUpdateGate(
            enabled: true,
            updateService: service,
            child: const Text('normal app'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('normal app'), findsOneWidget);
      expect(find.text('განახლება ვერ შემოწმდა'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(find.text('normal app'), findsOneWidget);
      expect(find.text('ჩამოტვირთვა და განახლება'), findsOneWidget);
    });

    testWidgets('shows the app only when the installed release is current', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MandatoryUpdateGate(
            enabled: true,
            updateService: _FakeMandatoryService(installedVersion: '1.0.1'),
            child: const Text('normal app'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('normal app'), findsOneWidget);
      expect(find.text('ჩამოტვირთვა და განახლება'), findsNothing);
    });
  });
}

Map<String, dynamic> _releaseJson({
  String tag = 'v1.0.1',
  List<Map<String, dynamic>>? assets,
}) => {
  'tag_name': tag,
  'draft': false,
  'prerelease': false,
  'body': 'Bug fixes',
  'assets': assets ?? [_apkAsset(), _checksumAsset()],
};

Map<String, dynamic> _apkAsset({
  String url =
      'https://github.com/payday-owner/payday-app/releases/download/v1.0.1/app.apk',
}) => {'name': 'app.apk', 'browser_download_url': url, 'size': 5};

Map<String, dynamic> _checksumAsset({
  String url =
      'https://github.com/payday-owner/payday-app/releases/download/v1.0.1/app.apk.sha256',
}) => {'name': 'app.apk.sha256', 'browser_download_url': url, 'size': 70};

GitHubRelease _release({String tag = 'v1.0.1'}) => GitHubRelease.fromJson(
  _releaseJson(tag: tag),
  owner: 'payday-owner',
  repository: 'payday-app',
);

UpdateService _service({
  String installedVersion = '1.0.0',
  GitHubRelease? release,
  UpdateTransfer? transfer,
  UpdateInstaller? installer,
}) => UpdateService(
  repository: _FakeRepository(release ?? _release()),
  transfer: transfer ?? _MemoryTransfer(),
  installer: installer ?? _FakeInstaller('', version: installedVersion),
);

class _FakeRepository implements ReleaseRepository {
  final GitHubRelease release;

  _FakeRepository(this.release);

  @override
  Future<GitHubRelease> fetchLatestStableRelease() async => release;
}

class _FakeInstaller implements UpdateInstaller {
  final String directory;
  final String version;
  String? installedPath;

  _FakeInstaller(this.directory, {this.version = '1.0.0'});

  @override
  Future<bool> canInstallUnknownApps() async => true;

  @override
  Future<String> getInstalledVersion() async => version;

  @override
  Future<String> getUpdateDirectory() async => directory;

  @override
  Future<void> installApk(String path) async {
    installedPath = path;
  }

  @override
  Future<void> openInstallPermissionSettings() async {}
}

class _MemoryTransfer implements UpdateTransfer {
  final String checksumText;
  final List<int> apkBytes;
  final Object? downloadError;
  var downloadCalls = 0;

  _MemoryTransfer({
    String? checksumText,
    this.apkBytes = const [0x50, 0x4b, 0x03, 0x04, 0x01],
    this.downloadError,
  }) : checksumText =
           checksumText ??
           '${sha256.convert(const [0x50, 0x4b, 0x03, 0x04, 0x01])} app.apk';

  @override
  Future<void> downloadToFile(
    Uri url,
    File destination, {
    required void Function(int received, int total) onProgress,
  }) async {
    downloadCalls++;
    if (downloadError case final error?) throw error;
    await destination.writeAsBytes(apkBytes);
    onProgress(apkBytes.length, apkBytes.length);
  }

  @override
  Future<String> getText(Uri url) async => checksumText;
}

class _FakeMandatoryService implements MandatoryUpdateService {
  final String installedVersion;
  var checkFailuresRemaining = 0;

  _FakeMandatoryService({this.installedVersion = '1.0.0'});

  @override
  Future<UpdateCheckResult> checkForUpdate() async {
    if (checkFailuresRemaining > 0) {
      checkFailuresRemaining--;
      throw const UpdateException('network unavailable');
    }
    return UpdateCheckResult(
      installedVersion: installedVersion,
      release: _release(),
    );
  }

  @override
  Future<String> downloadAndVerify(
    GitHubRelease release, {
    required void Function(int received, int total) onProgress,
  }) async => '/verified.apk';

  @override
  Future<InstallerResult> installVerifiedApk(String path) async =>
      InstallerResult.launched;

  @override
  Future<void> openInstallPermissionSettings() async {}
}
