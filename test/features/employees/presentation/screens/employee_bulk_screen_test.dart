import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/features/employees/presentation/screens/employee_bulk_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fake_employee_repository.dart';
import '../../../roles/data/fake_role_repository.dart';

void main() {
  User user(List<String> permissions) => User(
    accessToken: 'token',
    refreshToken: 'refresh',
    id: 'user',
    email: 'user@example.test',
    firstName: 'Test',
    lastName: 'User',
    phone: '99001122',
    isOwner: false,
    role: UserRole('role', 'Role', permissions),
    tenant: UserTenant('tenant', 'Tenant'),
  );

  Future<void> pumpAt(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('gates the whole surface on employees.edit', (tester) async {
    await pumpAt(
      tester,
      EmployeeBulkScreen(
        repo: FakeEmployeeRepository(),
        rolesRepo: FakeRoleRepository(),
        user: user(const ['employees.view']),
      ),
    );
    expect(find.text('Энэ үйлдэлд эрх байхгүй байна'), findsOneWidget);
  });

  testWidgets(
    'selecting rows shows the action bar with the count, and select-all '
    'toggles every visible row',
    (tester) async {
      await pumpAt(
        tester,
        EmployeeBulkScreen(
          repo: FakeEmployeeRepository(
            seed: [
              FakeEmployeeRepository.seedEmployee(id: 'u-1'),
              FakeEmployeeRepository.seedEmployee(id: 'u-2'),
            ],
          ),
          rolesRepo: FakeRoleRepository(),
          user: user(const ['employees.view', 'employees.edit']),
        ),
      );

      expect(find.byType(Checkbox), findsNothing);
      await tester.longPress(find.text('Дорж Бат').first);
      await tester.pumpAndSettle();
      expect(find.text('1 сонгосон'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.indeterminate_check_box_outlined));
      await tester.pumpAndSettle();
      expect(find.text('2 сонгосон'), findsOneWidget);
    },
  );

  testWidgets(
    'apply is per-row: a partial failure renders the result banner without '
    'throwing',
    (tester) async {
      await pumpAt(
        tester,
        EmployeeBulkScreen(
          repo: FakeEmployeeRepository(
            seed: [
              FakeEmployeeRepository.seedEmployee(id: 'u-1'),
              FakeEmployeeRepository.seedOwner(id: 'owner-1'),
            ],
          ),
          rolesRepo: FakeRoleRepository(),
          user: user(const ['employees.view', 'employees.edit']),
        ),
      );

      await tester.tap(find.byIcon(Icons.check_box_outline_blank));
      await tester.pumpAndSettle();
      expect(find.text('2 сонгосон'), findsOneWidget);

      await tester.tap(find.text('Үүрэг'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Механик'));
      await tester.pumpAndSettle();

      expect(find.text('1 амжилттай, 1 амжилтгүй'), findsOneWidget);
    },
  );

  testWidgets('clear empties the selection and hides the action bar', (
    tester,
  ) async {
    await pumpAt(
      tester,
      EmployeeBulkScreen(
        repo: FakeEmployeeRepository(
          seed: [FakeEmployeeRepository.seedEmployee(id: 'u-1')],
        ),
        rolesRepo: FakeRoleRepository(),
        user: user(const ['employees.view', 'employees.edit']),
      ),
    );
    await tester.longPress(find.text('Дорж Бат'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('selection_bar_clear')));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
  });
}
