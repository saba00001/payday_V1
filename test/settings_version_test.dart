import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:payday/presentation/settings_screen/settings_screen.dart';
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
}
