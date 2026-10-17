import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payday/presentation/settings_screen/recovery_confirmation_dialog.dart';

void main() {
  testWidgets('fresh-start dialog requires an explicit affirmative action', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showStartFreshConfirmation(context);
              },
              child: const Text('Open confirmation'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();
    expect(find.text('ახალი მონაცემებით დაწყება?'), findsOneWidget);
    await tester.tap(find.text('გაუქმება'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('დადასტურება და დაწყება'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
