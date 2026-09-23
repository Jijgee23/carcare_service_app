import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/features/appointments/domain/appointment.dart';
import 'package:carcare_service/features/appointments/presentation/controllers/calendar_controller.dart';
import 'package:carcare_service/features/appointments/presentation/screens/appointment_calendar_screen.dart';

import '../../../fakes/fake_appointment_repository.dart';
import 'calendar_test_fixtures.dart';

Future<void> _pumpScreen(
  WidgetTester tester,
  CalendarController controller,
) async {
  tester.view.physicalSize = const Size(375, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: AppointmentCalendarScreen(controller: controller),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('Calendar month-count dot', () {
    testWidgets('a day with appointments shows its count on the date nav', (
      tester,
    ) async {
      final repo = FakeAppointmentRepository(
        seed: [
          AppointmentSummary(
            id: 'appt-a',
            status: AppointmentStatus.PENDING,
            requestedAt: day(9),
            branch: const AppointmentBranchRef(
              id: 'branch-1',
              name: 'Толгойт салбар',
            ),
          ),
          AppointmentSummary(
            id: 'appt-b',
            status: AppointmentStatus.PENDING,
            requestedAt: day(15),
            branch: const AppointmentBranchRef(
              id: 'branch-1',
              name: 'Толгойт салбар',
            ),
          ),
        ],
      );
      final controller = CalendarController(
        repo: repo,
        branchId: 'branch-1',
        date: day(9),
      );

      await _pumpScreen(tester, controller);

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets(
      'a day absent from the month-counts map shows no dot (not a zero dot)',
      (tester) async {
        // No appointments requested on the selected day at all — the day
        // is entirely absent from `getMonthCounts`' map.
        final repo = FakeAppointmentRepository(
          seed: [
            AppointmentSummary(
              id: 'appt-elsewhere',
              status: AppointmentStatus.PENDING,
              requestedAt: DateTime(2026, 9, 2, 10),
              branch: const AppointmentBranchRef(
                id: 'branch-1',
                name: 'Толгойт салбар',
              ),
            ),
          ],
        );
        final controller = CalendarController(
          repo: repo,
          branchId: 'branch-1',
          date: day(9), // 2026-09-22 — no appointments that day
        );

        await _pumpScreen(tester, controller);

        expect(controller.countFor(controller.date), 0);
        expect(find.text('1'), findsNothing);
        expect(find.text('0'), findsNothing);
      },
    );
  });
}
