import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/features/appointments/domain/appointment.dart';
import 'package:carcare_service/features/appointments/presentation/widgets/calendar/calendar_block_tile.dart';

import 'calendar_test_fixtures.dart';

Future<void> _pump(WidgetTester tester, Widget child, {ThemeData? theme}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('CalendarBlockTile', () {
    testWidgets('exposes the full server accessible label even when dense', (
      tester,
    ) async {
      final block = knownFinishBlock(
        issue: const CalendarBlockIssue(
          reason: CalendarIssueReason.missingEstimate,
          label: 'Тооцоолсон хугацаа дутуу',
        ),
        capacityOverflow: true,
      );
      await _pump(tester, CalendarBlockTile(block: block, dense: true));

      // The dense rendering drops most visible text, but the accessible
      // label — the server's own `accessibleLabel` — must survive intact
      // as a single Semantics node, never rebuilt from parts here.
      final semantics = tester.getSemantics(find.byType(CalendarBlockTile));
      expect(semantics.label, block.accessibleLabel);
      expect(semantics.label, contains('Анхаарах'));
      expect(semantics.label, contains('Салбарын багтаамжаас хэтэрсэн'));
    });

    testWidgets('open-ended work shows a distinct marker from a known finish', (
      tester,
    ) async {
      await _pump(tester, CalendarBlockTile(block: openEndedBlock()));
      expect(find.byIcon(Icons.all_inclusive_rounded), findsOneWidget);
      expect(find.textContaining('тодорхойгүй'), findsOneWidget);
    });

    testWidgets('a known finish never shows the open-ended marker', (
      tester,
    ) async {
      await _pump(tester, CalendarBlockTile(block: knownFinishBlock()));
      expect(find.byIcon(Icons.all_inclusive_rounded), findsNothing);
    });

    testWidgets(
      'day-boundary finish renders as 24:00, not a raw midnight timestamp',
      (tester) async {
        await _pump(tester, CalendarBlockTile(block: dayBoundaryBlock()));
        expect(find.textContaining('24:00'), findsOneWidget);
      },
    );

    testWidgets('capacity overflow is visibly marked', (tester) async {
      await _pump(
        tester,
        CalendarBlockTile(block: knownFinishBlock(capacityOverflow: true)),
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('an issue block is visibly marked', (tester) async {
      const issue = CalendarBlockIssue(
        reason: CalendarIssueReason.missingOrder,
        label: 'Холбогдсон захиалга олдсонгүй',
      );
      await _pump(
        tester,
        CalendarBlockTile(block: knownFinishBlock(issue: issue)),
      );
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('renders without exception in both themes', (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await _pump(
          tester,
          CalendarBlockTile(block: knownFinishBlock()),
          theme: theme,
        );
        expect(tester.takeException(), isNull);
      }
    });
  });
}
