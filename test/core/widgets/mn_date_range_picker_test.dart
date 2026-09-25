import 'package:carcare_service/core/widgets/mn_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping two days confirms a range', (tester) async {
    DateTimeRange? result;
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              capturedContext = context;
              return ElevatedButton(
                onPressed: () async {
                  result = await showMnDateRangePicker(
                    context,
                    initialRange: DateTimeRange(
                      start: DateTime(2026, 6, 10),
                      end: DateTime(2026, 6, 10),
                    ),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Confirm should be disabled until an end date is chosen (initialRange
    // starts and ends the same day, so tap two distinct days from scratch).
    expect(find.text('Огноо сонгоно уу'), findsNothing);

    // Tap day 5 then day 15 of the shown month.
    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();
    expect(find.text('Огноо сонгоно уу'), findsOneWidget);

    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle();
    expect(find.text('Сонгох'), findsOneWidget);

    await tester.tap(find.text('Сонгох'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.start.day, 5);
    expect(result!.end.day, 15);
    expect(capturedContext.mounted, isTrue);
  });

  testWidgets('same day tapped twice yields a single-day range', (
    tester,
  ) async {
    DateTimeRange? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showMnDateRangePicker(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('12').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('12').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сонгох'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.start, result!.end);
  });

  testWidgets('days outside first/last bounds are disabled', (tester) async {
    DateTimeRange? result;
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(now.year, now.month, now.day + 2);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showMnDateRangePicker(
                  context,
                  firstDate: firstDate,
                  lastDate: lastDate,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // A day well before firstDate should not be tappable — the picker must
    // still show "no start selected" after tapping it.
    final beforeFirst = DateTime(now.year, now.month, now.day - 10);
    if (beforeFirst.month == now.month) {
      await tester.tap(find.text('${beforeFirst.day}').first);
      await tester.pumpAndSettle();
      expect(find.text('Эхлэх өдрөө сонгоно уу'), findsOneWidget);
    }

    // A day within bounds is tappable.
    await tester.tap(find.text('${firstDate.day}').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('→'), findsOneWidget);

    // Cancel to avoid leaving a pending route.
    await tester.tap(find.text('Болих'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
