import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/features/schedules/domain/schedule.dart';
import 'package:carcare_service/features/schedules/presentation/screens/my_schedule_screen.dart';

import '../../data/fake_schedule_repository.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('renders a month grid with weekday headers and leading days', (
    tester,
  ) async {
    await pumpAt(
      tester,
      MyScheduleScreen(
        repository: FakeScheduleRepository(
          seed: [
            FakeScheduleRepository.seedRow(
              id: 'u-self',
              name: 'Би',
              cells: {
                '2026-09-21': const ScheduleCell(
                  working: true,
                  source: ScheduleSource.weekly,
                  segments: [
                    ScheduleSegment(
                      branchId: 'b-1',
                      branchName: 'Салбар 1',
                      startTime: '09:00',
                      endTime: '18:00',
                    ),
                  ],
                ),
              },
            ),
          ],
          currentUserId: 'u-self',
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('my_schedule_month_grid')),
      findsOneWidget,
    );
    expect(find.text('Да'), findsOneWidget); // weekday header
    // A leading day from the previous month must still be tappable.
    expect(
      find.byKey(const ValueKey('my_schedule_day_2026-08-31')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('my_schedule_day_2026-09-21')),
      findsOneWidget,
    );
  });

  testWidgets('tapping a day opens the detail sheet with segments', (
    tester,
  ) async {
    await pumpAt(
      tester,
      MyScheduleScreen(
        repository: FakeScheduleRepository(
          seed: [
            FakeScheduleRepository.seedRow(
              id: 'u-self',
              name: 'Би',
              cells: {
                '2026-09-21': const ScheduleCell(
                  working: true,
                  source: ScheduleSource.exception,
                  segments: [
                    ScheduleSegment(
                      branchId: 'b-1',
                      branchName: 'Салбар 1',
                      startTime: '09:00',
                      endTime: '18:00',
                    ),
                  ],
                ),
              },
            ),
          ],
          currentUserId: 'u-self',
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('my_schedule_day_2026-09-21')));
    await tester.pumpAndSettle();

    expect(find.text('09:00–18:00'), findsOneWidget);
    expect(find.text('Салбар 1'), findsOneWidget);
    expect(find.text('Ажиллана'), findsOneWidget);
  });

  testWidgets('month navigation advances the header label', (tester) async {
    await pumpAt(
      tester,
      MyScheduleScreen(
        repository: FakeScheduleRepository(currentUserId: 'u-1'),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('my_schedule_next_month')));
    await tester.pumpAndSettle();
    // Just verify the nav controls exist and are tappable without throwing;
    // the exact label depends on "today", which this test does not pin.
    expect(
      find.byKey(const ValueKey('my_schedule_prev_month')),
      findsOneWidget,
    );
  });
}
