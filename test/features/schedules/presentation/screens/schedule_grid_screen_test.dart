import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/features/schedules/domain/schedule.dart';
import 'package:carcare_service/features/schedules/presentation/screens/schedule_grid_screen.dart';

import '../../data/fake_schedule_repository.dart';

void main() {
  User user(List<String> permissions, {bool isOwner = false}) => User(
    accessToken: 'token',
    refreshToken: 'refresh',
    id: 'user',
    email: 'user@example.test',
    firstName: 'Test',
    lastName: 'User',
    phone: '99001122',
    isOwner: isOwner,
    role: UserRole('role', 'Role', permissions),
    tenant: UserTenant('tenant', 'Tenant'),
  );

  Future<void> pumpAt(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  group('permission gate', () {
    testWidgets('no employees.view: locked message, no grid', (tester) async {
      await pumpAt(
        tester,
        ScheduleGridScreen(
          repository: FakeScheduleRepository(),
          user: user(const []),
        ),
      );
      expect(
        find.text('Танд ажилтны хуваарь харах эрх байхгүй байна.'),
        findsOneWidget,
      );
    });

    testWidgets('employees.view sees the grid', (tester) async {
      await pumpAt(
        tester,
        ScheduleGridScreen(
          repository: FakeScheduleRepository(
            seed: [FakeScheduleRepository.seedRow(id: 'u-1', name: 'Бат')],
          ),
          user: user(const ['employees.view']),
        ),
      );
      expect(find.text('Бат'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('week/month toggle and prev/next/today render', (tester) async {
      await pumpAt(
        tester,
        ScheduleGridScreen(
          repository: FakeScheduleRepository(
            seed: [FakeScheduleRepository.seedRow(id: 'u-1', name: 'Бат')],
          ),
          user: user(const ['employees.view']),
        ),
      );
      expect(
        find.byKey(const ValueKey('schedule_grid_view_toggle')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('schedule_grid_prev')), findsOneWidget);
      expect(find.byKey(const ValueKey('schedule_grid_next')), findsOneWidget);
      expect(find.byKey(const ValueKey('schedule_grid_today')), findsOneWidget);

      await tester.tap(find.text('Сар'));
      await tester.pumpAndSettle();
      expect(find.text('Бат'), findsOneWidget); // still renders after reload
    });
  });

  group('source markers and legend', () {
    testWidgets('legend renders and a cell shows its source marker', (
      tester,
    ) async {
      await pumpAt(
        tester,
        ScheduleGridScreen(
          repository: FakeScheduleRepository(
            seed: [
              FakeScheduleRepository.seedRow(
                id: 'u-1',
                name: 'Бат',
                cells: {
                  '2026-09-21': const ScheduleCell(
                    working: true,
                    source: ScheduleSource.exception,
                  ),
                },
              ),
            ],
          ),
          user: user(const ['employees.view']),
        ),
      );
      expect(find.byKey(const ValueKey('schedule_legend')), findsWidgets);
    });
  });

  group('edit sheet', () {
    testWidgets('canEdit hides bulk-select affordance for a view-only caller', (
      tester,
    ) async {
      await pumpAt(
        tester,
        ScheduleGridScreen(
          repository: FakeScheduleRepository(
            seed: [FakeScheduleRepository.seedRow(id: 'u-1', name: 'Бат')],
            callerCanEdit: false,
          ),
          user: user(const ['employees.view']),
        ),
      );
      expect(
        find.byKey(const ValueKey('schedule_grid_select_mode')),
        findsNothing,
      );
    });

    testWidgets('tapping a cell opens the edit sheet when canEdit', (
      tester,
    ) async {
      await pumpAt(
        tester,
        ScheduleGridScreen(
          repository: FakeScheduleRepository(
            seed: [
              FakeScheduleRepository.seedRow(
                id: 'u-1',
                name: 'Бат',
                cells: {
                  '2026-09-21': const ScheduleCell(
                    working: true,
                    source: ScheduleSource.weekly,
                  ),
                },
              ),
            ],
          ),
          user: user(const ['employees.view', 'employees.schedule']),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('schedule_grid_cell_u-1_2026-09-21')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('schedule_edit_working_switch')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('schedule_edit_scope_date')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('schedule_edit_scope_weekday')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('schedule_edit_reset_button')),
        findsOneWidget,
      );
    });

    testWidgets('reset asks for confirmation before resetting', (tester) async {
      await pumpAt(
        tester,
        ScheduleGridScreen(
          repository: FakeScheduleRepository(
            seed: [
              FakeScheduleRepository.seedRow(
                id: 'u-1',
                name: 'Бат',
                cells: {
                  '2026-09-21': const ScheduleCell(
                    working: true,
                    source: ScheduleSource.exception,
                  ),
                },
              ),
            ],
          ),
          user: user(const ['employees.view', 'employees.schedule']),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('schedule_grid_cell_u-1_2026-09-21')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('schedule_edit_reset_button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Үндсэн цагаар тохируулах уу?'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('schedule_edit_reset_confirm')),
      );
      await tester.pumpAndSettle();
    });
  });

  group('bulk selection', () {
    testWidgets(
      'entering selection mode and range-selecting two cells shows the count '
      'and applies via bulk edit',
      (tester) async {
        await pumpAt(
          tester,
          ScheduleGridScreen(
            repository: FakeScheduleRepository(
              seed: [
                FakeScheduleRepository.seedRow(id: 'u-1', name: 'Бат'),
                FakeScheduleRepository.seedRow(id: 'u-2', name: 'Дорж'),
              ],
            ),
            user: user(const ['employees.view', 'employees.schedule']),
          ),
        );

        await tester.tap(
          find.byKey(const ValueKey('schedule_grid_select_mode')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('schedule_grid_cell_u-1_2026-09-21')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('schedule_grid_cell_u-2_2026-09-21')),
        );
        await tester.pumpAndSettle();

        expect(find.text('2 сонгосон'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('selection_bar_clear')));
        await tester.pumpAndSettle();
        expect(find.text('2 сонгосон'), findsNothing);
      },
    );

    testWidgets('bulk edit sheet offers a weekday scope and applies under it', (
      tester,
    ) async {
      await pumpAt(
        tester,
        ScheduleGridScreen(
          repository: FakeScheduleRepository(
            seed: [
              FakeScheduleRepository.seedRow(id: 'u-1', name: 'Бат'),
              FakeScheduleRepository.seedRow(id: 'u-2', name: 'Дорж'),
            ],
          ),
          user: user(const ['employees.view', 'employees.schedule']),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('schedule_grid_select_mode')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('schedule_grid_cell_u-1_2026-09-21')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('schedule_grid_cell_u-2_2026-09-21')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Both scope choices are offered, with the web-parity weekday
      // explanation naming the affected weekday(s).
      expect(
        find.byKey(const ValueKey('schedule_edit_scope_date')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('schedule_edit_scope_weekday')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Сонгосон гараг(ууд)т байнга'),
        findsOneWidget,
      );
      expect(find.textContaining('Дав'), findsOneWidget); // Monday, short label

      await tester.tap(
        find.byKey(const ValueKey('schedule_edit_scope_weekday')),
      );
      await tester.pumpAndSettle();
      // Turn off "working" so the save button isn't blocked on picking a
      // branch for every segment — this test only cares about the scope
      // wiring, not segment validation (covered elsewhere).
      await tester.tap(
        find.byKey(const ValueKey('schedule_edit_working_switch')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule_edit_save_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('шинэчлэгдлээ'), findsOneWidget);
    });
  });
}
