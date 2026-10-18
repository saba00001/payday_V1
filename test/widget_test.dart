// This is a basic Flutter widget test.
//
// To perform an interaction with a widget, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap
// and scroll gestures. You can also use WidgetTester to find child widgets
// in the widget tree, read text, and verify that the values of widgets
// are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:payday/main.dart';
import 'package:payday/presentation/home_screen/home_screen.dart';
import 'package:payday/presentation/home_screen/recovery_start_screen.dart';
import 'package:payday/widgets/app_navigation.dart';

void main() {
  testWidgets('first launch offers recovery or new data', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 900));
    for (
      var attempt = 0;
      attempt < 20 && find.byType(RecoveryStartScreen).evaluate().isEmpty;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(RecoveryStartScreen), findsOneWidget);
    expect(find.byType(AppNavigation), findsNothing);
    expect(find.text('მონაცემების აღდგენა'), findsOneWidget);
    expect(find.text('ახალი მონაცემების შექმნა'), findsOneWidget);

    await tester.tap(find.text('ახალი მონაცემების შექმნა'));
    for (
      var attempt = 0;
      attempt < 30 &&
          find.text('ავანსები ობიექტების მიხედვით').evaluate().isEmpty;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('ავანსები ობიექტების მიხედვით'), findsOneWidget);
    expect(find.byType(AppNavigation), findsOneWidget);
  });
}
