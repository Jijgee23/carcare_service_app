import 'package:carcare_service/core/widgets/date_picker/app_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDateSelection (range)', () {
    const empty = AppDateSelection.range();
    final d10 = DateTime(2026, 9, 10);
    final d15 = DateTime(2026, 9, 15);
    final d5 = DateTime(2026, 9, 5);

    test('first tap sets start and waits for the end', () {
      final s = empty.tap(d10);
      expect(s.start, d10);
      expect(s.end, isNull);
      expect(s.nextEdge, AppRangeEdge.end);
      expect(s.isComplete, isFalse);
    });

    test('second tap after start completes the range', () {
      final s = empty.tap(d10).tap(d15);
      expect(s.start, d10);
      expect(s.end, d15);
      expect(s.dayCount, 6);
    });

    test('tapping before the start moves the start, never inverts', () {
      final s = empty.tap(d10).tap(d5);
      expect(s.start, d5);
      expect(s.end, isNull);
    });

    test('same day twice is a valid one-day range', () {
      final s = empty.tap(d10).tap(d10);
      expect(s.isComplete, isTrue);
      expect(s.dayCount, 1);
    });

    test('a tap on a finished range starts a new one', () {
      final s = empty.tap(d10).tap(d15).tap(d5);
      expect(s.start, d5);
      expect(s.end, isNull);
    });

    test('time components are stripped', () {
      final s = empty.tap(DateTime(2026, 9, 10, 23, 59));
      expect(s.start, d10);
    });

    test('dayCount is exact across month and DST-ish boundaries', () {
      final s = empty.tap(DateTime(2026, 3, 1)).tap(DateTime(2026, 3, 31));
      expect(s.dayCount, 31);
    });
  });

  group('AppDateSelection (end first / edges)', () {
    const empty = AppDateSelection.range();
    final d5 = DateTime(2026, 9, 5);
    final d10 = DateTime(2026, 9, 10);
    final d15 = DateTime(2026, 9, 15);
    final d20 = DateTime(2026, 9, 20);

    test('end can be picked first, then the start', () {
      var s = empty.focus(AppRangeEdge.end);
      expect(s.nextEdge, AppRangeEdge.end);
      s = s.tap(d15);
      expect(s.end, d15);
      expect(s.start, isNull);
      expect(s.nextEdge, AppRangeEdge.start);
      s = s.tap(d10);
      expect(s.start, d10);
      expect(s.end, d15);
      expect(s.isComplete, isTrue);
      expect(s.nextEdge, isNull);
    });

    test('a start after a chosen end drops that end, never inverts', () {
      final s = empty.focus(AppRangeEdge.end).tap(d10).tap(d15);
      expect(s.start, d15);
      expect(s.end, isNull);
      expect(s.nextEdge, AppRangeEdge.end);
    });

    test('editing only the end of a finished range keeps the start', () {
      final s = empty.tap(d10).tap(d15).focus(AppRangeEdge.end).tap(d20);
      expect(s.start, d10);
      expect(s.end, d20);
    });

    test('editing only the start of a finished range keeps the end', () {
      final s = empty.tap(d10).tap(d15).focus(AppRangeEdge.start).tap(d5);
      expect(s.start, d5);
      expect(s.end, d15);
    });

    test('an end before the start drops the start', () {
      final s = empty.tap(d10).tap(d15).focus(AppRangeEdge.end).tap(d5);
      expect(s.start, isNull);
      expect(s.end, d5);
      expect(s.nextEdge, AppRangeEdge.start);
    });

    test('span orders the ends whichever way the finger moved', () {
      expect(empty.span(d15, d10).start, d10);
      expect(empty.span(d15, d10).end, d15);
      expect(empty.span(d10, d15).start, d10);
      expect(empty.span(d10, d10).dayCount, 1);
    });
  });

  test('single mode replaces the day on every tap', () {
    final s = const AppDateSelection.single(null)
        .tap(DateTime(2026, 9, 1))
        .tap(DateTime(2026, 9, 3));
    expect(s.start, DateTime(2026, 9, 3));
    expect(s.end, isNull);
    expect(s.isComplete, isTrue);
  });

  test('mondayOf', () {
    expect(mondayOf(DateTime(2026, 9, 25)), DateTime(2026, 9, 21)); // Fri
    expect(mondayOf(DateTime(2026, 9, 21)), DateTime(2026, 9, 21)); // Mon
    expect(mondayOf(DateTime(2026, 9, 27)), DateTime(2026, 9, 21)); // Sun
    expect(
      mondayOf(DateTime(2026, 10, 1)),
      DateTime(2026, 9, 28),
    ); // crosses month
  });

  group('sheet', () {
    Future<void> open(
      WidgetTester tester,
      Future<Object?> Function(BuildContext) show,
      List<Object?> out, {
      double width = 400,
    }) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => out.add(await show(context)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Finder day(String ymd) => find.byKey(ValueKey('app_date_picker_day_$ymd'));
    final confirm = find.byKey(const ValueKey('app_date_picker_confirm'));

    ElevatedButton confirmButton(WidgetTester tester) =>
        tester.widget<ElevatedButton>(confirm);

    testWidgets('range: confirm is disabled until both ends are picked', (
      tester,
    ) async {
      final out = <Object?>[];
      await open(
        tester,
        (c) => AppDatePicker.range(
          c,
          initial: null,
          firstDate: DateTime(2026, 1, 1),
          lastDate: DateTime(2026, 12, 31),
        ),
        out,
      );
      // Opens on "today" clamped into bounds — navigate to a known month.
      await tester.tap(find.textContaining('оны'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('9-р сар'));
      await tester.pumpAndSettle();

      expect(confirmButton(tester).onPressed, isNull);
      await tester.tap(day('2026/09/10'));
      await tester.pump();
      expect(confirmButton(tester).onPressed, isNull);
      expect(find.text('Дуусах огноо сонгоно уу'), findsOneWidget);

      await tester.tap(day('2026/09/14'));
      await tester.pump();
      expect(find.text('Сонгох · 5 хоног'), findsOneWidget);

      await tester.tap(confirm);
      await tester.pumpAndSettle();
      final range = out.single as DateTimeRange;
      expect(range.start, DateTime(2026, 9, 10));
      expect(range.end, DateTime(2026, 9, 14));
    });

    testWidgets(
      'range: out-of-bounds days cannot be picked; initial is clamped',
      (tester) async {
        final out = <Object?>[];
        await open(
          tester,
          (c) => AppDatePicker.range(
            c,
            initial: DateTimeRange(
              start: DateTime(2026, 9, 1),
              end: DateTime(2026, 9, 30),
            ),
            firstDate: DateTime(2026, 9, 1),
            lastDate: DateTime(2026, 9, 20),
          ),
          out,
        );
        expect(
          find.text('2026/09/20'),
          findsWidgets,
        ); // end clamped to lastDate
        // Previous/next are disabled at the bounds.
        expect(
          tester
              .widget<IconButton>(
                find.byKey(const ValueKey('app_date_picker_prev')),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<IconButton>(
                find.byKey(const ValueKey('app_date_picker_next')),
              )
              .onPressed,
          isNull,
        );

        await tester.tap(day('2026/09/25'), warnIfMissed: false);
        await tester.pump();
        // Tap ignored: range still complete and unchanged.
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        final range = out.single as DateTimeRange;
        expect(range.start, DateTime(2026, 9, 1));
        expect(range.end, DateTime(2026, 9, 20));
      },
    );

    testWidgets('single, week view: picks a day and returns midnight', (
      tester,
    ) async {
      final out = <Object?>[];
      await open(
        tester,
        (c) => AppDatePicker.single(
          c,
          initial: DateTime(2026, 9, 25, 15, 30),
          view: AppDatePickerView.week,
        ),
        out,
      );
      expect(find.text('2026  09/21 – 09/27'), findsOneWidget);
      await tester.tap(day('2026/09/23'));
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(out.single, DateTime(2026, 9, 23));
    });

    testWidgets('switching view keeps the selection in sight', (tester) async {
      final out = <Object?>[];
      await open(
        tester,
        (c) => AppDatePicker.single(c, initial: DateTime(2026, 9, 25)),
        out,
      );
      expect(find.text('2026 оны 9-р сар'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('app_date_picker_view_week')));
      await tester.pumpAndSettle();
      expect(find.text('2026  09/21 – 09/27'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('app_date_picker_next')));
      await tester.pumpAndSettle();
      expect(find.text('2026  09/28 – 10/04'), findsOneWidget);
    });

    testWidgets('range: tap the end box to pick the end date first', (
      tester,
    ) async {
      final out = <Object?>[];
      await open(
        tester,
        (c) => AppDatePicker.range(
          c,
          initial: DateTimeRange(
            start: DateTime(2026, 9, 1),
            end: DateTime(2026, 9, 2),
          ),
          firstDate: DateTime(2026, 1, 1),
          lastDate: DateTime(2026, 12, 31),
        ),
        out,
      );
      // Start a fresh range, end first.
      await tester.tap(day('2026/09/20'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('app_date_picker_edge_end')));
      await tester.pump();
      await tester.tap(day('2026/09/25'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('app_date_picker_edge_end')));
      await tester.pump();
      await tester.tap(day('2026/09/22'));
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      final range = out.single as DateTimeRange;
      expect(range.start, DateTime(2026, 9, 20));
      expect(range.end, DateTime(2026, 9, 22));
    });

    testWidgets('range: press and drag selects the span immediately', (
      tester,
    ) async {
      final out = <Object?>[];
      await open(
        tester,
        (c) => AppDatePicker.range(
          c,
          initial: DateTimeRange(
            start: DateTime(2026, 9, 1),
            end: DateTime(2026, 9, 1),
          ),
          firstDate: DateTime(2026, 1, 1),
          lastDate: DateTime(2026, 12, 31),
        ),
        out,
      );
      final from = tester.getCenter(day('2026/09/16'));
      final to = tester.getCenter(day('2026/09/08'));
      final g = await tester.startGesture(from);
      await g.moveTo(Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2));
      await tester.pump();
      await g.moveTo(to);
      await tester.pump();
      await g.up();
      await tester.pump();
      expect(find.text('Сонгох · 9 хоног'), findsOneWidget);

      await tester.tap(confirm);
      await tester.pumpAndSettle();
      final range = out.single as DateTimeRange;
      expect(range.start, DateTime(2026, 9, 8));
      expect(range.end, DateTime(2026, 9, 16));
    });

    testWidgets('range: dragging down selects instead of closing the sheet', (
      tester,
    ) async {
      final out = <Object?>[];
      await open(
        tester,
        (c) => AppDatePicker.range(
          c,
          initial: DateTimeRange(
            start: DateTime(2026, 9, 1),
            end: DateTime(2026, 9, 1),
          ),
          firstDate: DateTime(2026, 1, 1),
          lastDate: DateTime(2026, 12, 31),
        ),
        out,
      );
      await tester.dragFrom(
        tester.getCenter(day('2026/09/02')),
        tester.getCenter(day('2026/09/30')) -
            tester.getCenter(day('2026/09/02')),
      );
      await tester.pumpAndSettle();
      expect(confirm, findsOneWidget); // sheet still open
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      final range = out.single as DateTimeRange;
      expect(range.start, DateTime(2026, 9, 2));
      expect(range.end, DateTime(2026, 9, 30));
    });

    testWidgets('range: drag past the bounds snaps to the last allowed day', (
      tester,
    ) async {
      final out = <Object?>[];
      await open(
        tester,
        (c) => AppDatePicker.range(
          c,
          initial: DateTimeRange(
            start: DateTime(2026, 9, 1),
            end: DateTime(2026, 9, 1),
          ),
          firstDate: DateTime(2026, 9, 1),
          lastDate: DateTime(2026, 9, 20),
        ),
        out,
      );
      final g = await tester.startGesture(tester.getCenter(day('2026/09/15')));
      await g.moveTo(tester.getCenter(day('2026/09/30')));
      await tester.pump();
      await g.up();
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      final range = out.single as DateTimeRange;
      expect(range.start, DateTime(2026, 9, 15));
      expect(range.end, DateTime(2026, 9, 20));
    });

    testWidgets('no overflow at 320dp in either view', (tester) async {
      final out = <Object?>[];
      await open(
        tester,
        (c) => AppDatePicker.range(
          c,
          initial: DateTimeRange(
            start: DateTime(2026, 12, 28),
            end: DateTime(2027, 1, 3),
          ),
        ),
        out,
        width: 320,
      );
      await tester.tap(find.byKey(const ValueKey('app_date_picker_view_week')));
      await tester.pumpAndSettle();
      expect(find.text('2026/12/28 – 2027/01/03'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancel returns null', (tester) async {
      final out = <Object?>[];
      await open(
        tester,
        (c) => AppDatePicker.single(c, initial: DateTime(2026, 9, 25)),
        out,
      );
      await tester.tap(find.text('Болих'));
      await tester.pumpAndSettle();
      expect(out.single, isNull);
    });
  });
}
