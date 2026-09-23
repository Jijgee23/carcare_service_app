import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/features/appointments/domain/appointment.dart';
import 'package:carcare_service/features/appointments/presentation/widgets/calendar/calendar_legend.dart';

void main() {
  testWidgets('renders only the entries the server sent, nothing more', (
    tester,
  ) async {
    const entries = [
      CalendarLegendStatus(
        status: AppointmentStatus.CONFIRMED,
        label: 'Баталгаажсан',
      ),
      CalendarLegendIssue(
        reason: CalendarIssueReason.missingEstimate,
        label: 'Тооцоолсон хугацаа дутуу',
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: CalendarLegend(entries: entries)),
      ),
    );

    expect(find.text('Баталгаажсан'), findsOneWidget);
    expect(find.text('Тооцоолсон хугацаа дутуу'), findsOneWidget);
    // Statuses/issues that were NOT included in the model's legend must not
    // appear just because they exist in the enum.
    expect(find.text('Хүлээгдэж буй'), findsNothing);
    expect(find.text('Татгалзсан'), findsNothing);
  });

  testWidgets('renders nothing for an empty legend', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: CalendarLegend(entries: [])),
      ),
    );
    expect(find.byType(Wrap), findsNothing);
  });

  testWidgets('renders without exception in both themes', (tester) async {
    const entries = [
      CalendarLegendStatus(
        status: AppointmentStatus.PENDING,
        label: 'Хүлээгдэж буй',
      ),
    ];
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: CalendarLegend(entries: entries)),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
