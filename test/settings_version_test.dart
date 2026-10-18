import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:payday/presentation/settings_screen/settings_screen.dart';
import 'package:payday/services/update/github_release.dart';
import 'package:payday/services/update/semantic_version.dart';
import 'package:payday/services/update/update_installer.dart';
import 'package:payday/services/update/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('settings displays installed version without build suffix', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'PayDay',
      packageName: 'com.example.payday',
      version: '1.0.2',
      buildNumber: '4',
      buildSignature: '',
    );

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('ვერსია 1.0.2'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('ვერსია 1.0.2'), findsOneWidget);
    expect(find.text('ვერსია 1.0.2+4'), findsNothing);
    expect(find.text('ვერსია 1.0.0'), findsNothing);
  });

  testWidgets('update check runs only after tapping the settings button', (
    tester,
  ) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'PayDay',
        packageName: 'com.example.payday',
        version: '1.1.3',
        buildNumber: '10',
        buildSignature: '',
      );
      final updateService = _FakeUpdateService();

      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(updateService: updateService)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('განახლების შემოწმება'),
        400,
        scrollable: find.byType(Scrollable).first,
      );

      expect(updateService.checkCount, 0);
      await tester.tap(find.text('განახლების შემოწმება'));
      await tester.pumpAndSettle();

      expect(updateService.checkCount, 1);
      expect(find.text('PayDay განახლებულია'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });
}

class _FakeUpdateService implements MandatoryUpdateService {
  int checkCount = 0;

  @override
  Future<UpdateCheckResult> checkForUpdate() async {
    checkCount++;
    return UpdateCheckResult(
      installedVersion: '1.1.3+10',
      release: GitHubRelease(
        tagName: 'v1.1.3',
        version: SemanticVersion.tryParse('1.1.3')!,
        buildNumber: 10,
        notes: '',
        apk: GitHubReleaseAsset(
          name: 'app.apk',
          downloadUrl: Uri.https('github.com', '/owner/repo/app.apk'),
          size: 1,
        ),
        checksum: GitHubReleaseAsset(
          name: 'app.apk.sha256',
          downloadUrl: Uri.https('github.com', '/owner/repo/app.apk.sha256'),
          size: 64,
        ),
      ),
    );
  }

  @override
  Future<String> downloadAndVerify(
    GitHubRelease release, {
    required void Function(int received, int total) onProgress,
  }) async => throw UnimplementedError();

  @override
  Future<InstallerResult> installVerifiedApk(String path) async =>
      throw UnimplementedError();

  @override
  Future<void> openInstallPermissionSettings() async =>
      throw UnimplementedError();
}
