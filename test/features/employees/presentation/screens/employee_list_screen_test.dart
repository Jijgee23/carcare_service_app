import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/features/employees/domain/employee.dart';
import 'package:carcare_service/features/employees/presentation/screens/employee_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fake_employee_repository.dart';

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
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  group('permission gate (D-163)', () {
    testWidgets('gates the whole surface on employees.view', (tester) async {
      await pumpAt(
        tester,
        EmployeeListScreen(
          repository: FakeEmployeeRepository(),
          user: user(const []),
        ),
      );
      expect(
        find.text('Танд ажилтны жагсаалт харах эрх байхгүй байна.'),
        findsOneWidget,
      );
    });

    testWidgets('a user with employees.view sees the list', (tester) async {
      await pumpAt(
        tester,
        EmployeeListScreen(
          repository: FakeEmployeeRepository(
            seed: [FakeEmployeeRepository.seedEmployee(id: 'u-1')],
          ),
          user: user(const ['employees.view']),
        ),
      );
      expect(find.text('Дорж Бат'), findsOneWidget);
    });
  });

  group('search and filters', () {
    testWidgets('typing in the search box filters the list', (tester) async {
      await pumpAt(
        tester,
        EmployeeListScreen(
          repository: FakeEmployeeRepository(
            seed: [
              FakeEmployeeRepository.seedEmployee(
                id: 'u-1',
                firstName: 'Бат',
                lastName: 'Дорж',
              ),
              FakeEmployeeRepository.seedEmployee(
                id: 'u-2',
                firstName: 'Сараа',
                lastName: 'Пүрэв',
              ),
            ],
          ),
          user: user(const ['employees.view']),
        ),
      );
      expect(find.text('Дорж Бат'), findsOneWidget);
      expect(find.text('Пүрэв Сараа'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Сараа');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Дорж Бат'), findsNothing);
      expect(find.text('Пүрэв Сараа'), findsOneWidget);
    });

    testWidgets('branch chip counts render, including the unassigned chip', (
      tester,
    ) async {
      await pumpAt(
        tester,
        EmployeeListScreen(
          repository: FakeEmployeeRepository(
            seed: [
              FakeEmployeeRepository.seedEmployee(id: 'u-1', branchId: 'b-1'),
              FakeEmployeeRepository.seedEmployee(id: 'u-2', branchId: null),
            ],
          ),
          user: user(const ['employees.view']),
        ),
      );
      expect(find.textContaining('Хуваарилагдаагүй'), findsOneWidget);
      expect(find.textContaining('Салбар b-1'), findsOneWidget);
    });

    testWidgets(
      'the unassigned chip is count-only: tapping it never filters the list',
      (tester) async {
        await pumpAt(
          tester,
          EmployeeListScreen(
            repository: FakeEmployeeRepository(
              seed: [
                FakeEmployeeRepository.seedEmployee(
                  id: 'u-1',
                  branchId: 'b-1',
                ),
                FakeEmployeeRepository.seedEmployee(
                  id: 'u-2',
                  firstName: 'Сараа',
                  lastName: 'Пүрэв',
                  branchId: null,
                ),
              ],
            ),
            user: user(const ['employees.view']),
          ),
        );
        expect(find.text('Дорж Бат'), findsOneWidget);
        expect(find.text('Пүрэв Сараа'), findsOneWidget);

        await tester.ensureVisible(find.textContaining('Хуваарилагдаагүй'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Хуваарилагдаагүй'));
        await tester.pumpAndSettle();

        // Both rows are still visible — the tap did not filter anything,
        // proving the chip is not wired as a filter.
        expect(find.text('Дорж Бат'), findsOneWidget);
        expect(find.text('Пүрэв Сараа'), findsOneWidget);
      },
    );
  });

  group('row tap and create/bulk hooks', () {
    testWidgets('tapping a row invokes onTapRow with the employee', (
      tester,
    ) async {
      Employee? tapped;
      await pumpAt(
        tester,
        EmployeeListScreen(
          repository: FakeEmployeeRepository(
            seed: [FakeEmployeeRepository.seedEmployee(id: 'u-1')],
          ),
          user: user(const ['employees.view']),
          onTapRow: (e) => tapped = e,
        ),
      );
      await tester.tap(find.text('Дорж Бат'));
      expect(tapped?.id, 'u-1');
    });

    testWidgets('create FAB only renders with the hook and employees.create', (
      tester,
    ) async {
      await pumpAt(
        tester,
        EmployeeListScreen(
          repository: FakeEmployeeRepository(),
          user: user(const ['employees.view']),
          onCreate: () {},
        ),
      );
      expect(find.byIcon(Icons.person_add_alt_1), findsNothing);
    });

    testWidgets('create FAB renders for employees.create', (tester) async {
      await pumpAt(
        tester,
        EmployeeListScreen(
          repository: FakeEmployeeRepository(),
          user: user(const ['employees.view', 'employees.create']),
          onCreate: () {},
        ),
      );
      expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);
    });

    testWidgets('bulk edit action only renders with the hook', (tester) async {
      await pumpAt(
        tester,
        EmployeeListScreen(
          repository: FakeEmployeeRepository(),
          user: user(const ['employees.view', 'employees.edit']),
        ),
      );
      expect(find.byIcon(Icons.checklist_rtl), findsNothing);
    });
  });
}
