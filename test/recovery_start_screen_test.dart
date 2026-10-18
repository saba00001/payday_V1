import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payday/presentation/home_screen/recovery_start_screen.dart';

void main() {
  testWidgets('offers restore and new data actions on first launch', (
    tester,
  ) async {
    var restorePressed = false;
    var createPressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: RecoveryStartScreen(
          recovering: false,
          busy: false,
          error: null,
          backupInventory: null,
          onRestore: () => restorePressed = true,
          onRestoreLocal: (_) {},
          onCreateNew: () => createPressed = true,
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('მონაცემების აღდგენა'), findsOneWidget);
    expect(find.text('ახალი მონაცემების შექმნა'), findsOneWidget);
    expect(
      find.text('ლოკალური მონაცემების წაკითხვა ვერ მოხერხდა.'),
      findsNothing,
    );

    await tester.tap(find.text('მონაცემების აღდგენა'));
    await tester.tap(find.text('ახალი მონაცემების შექმნა'));
    expect(restorePressed, isTrue);
    expect(createPressed, isTrue);
  });

  testWidgets('recovery state warns data is not automatically deleted', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecoveryStartScreen(
          recovering: true,
          busy: false,
          error: null,
          backupInventory: null,
          onRestore: () {},
          onRestoreLocal: (_) {},
          onCreateNew: () {},
          onRetry: () {},
        ),
      ),
    );

    expect(find.textContaining('მონაცემები არ წაშლილა'), findsOneWidget);
    expect(find.text('ხელახლა ცდა'), findsOneWidget);
  });
}
