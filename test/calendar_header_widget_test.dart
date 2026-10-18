import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payday/core/georgian_date_utils.dart';
import 'package:payday/presentation/calendar_screen/widgets/calendar_header_widget.dart';

void main() {
  testWidgets('month navigation stays visible on a narrow screen', (
    tester,
  ) async {
    var previousMonthTaps = 0;
    var nextMonthTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: CalendarHeaderWidget(
              year: 2026,
              month: 10,
              onPrev: () => previousMonthTaps++,
              onNext: () => nextMonthTaps++,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.text(GeorgianDateUtils.formatMonthYear(2026, 10)),
      findsOneWidget,
    );
    expect(find.byTooltip('წინა თვე'), findsOneWidget);
    expect(find.byTooltip('შემდეგი თვე'), findsOneWidget);

    await tester.tap(find.byTooltip('წინა თვე'));
    await tester.tap(find.byTooltip('შემდეგი თვე'));

    expect(previousMonthTaps, 1);
    expect(nextMonthTaps, 1);
  });
}
