import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payday/widgets/app_lock_gate.dart';

void main() {
  testWidgets('keeps app content hidden until device authentication succeeds', (
    tester,
  ) async {
    final authentication = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          authenticate: () => authentication.future,
          child: const Text('private data'),
        ),
      ),
    );

    expect(find.text('private data'), findsNothing);
    expect(find.text('PayDay დაცულია'), findsOneWidget);

    authentication.complete(true);
    await tester.pumpAndSettle();

    expect(find.text('private data'), findsOneWidget);
    expect(find.text('PayDay დაცულია'), findsNothing);
  });

  testWidgets('does not expose app content when authentication is rejected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          authenticate: () async => false,
          child: const Text('private data'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('private data'), findsNothing);
    expect(find.text('PayDay დაცულია'), findsOneWidget);
  });
}
