import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/features/employees/domain/employee.dart';
import 'package:carcare_service/features/employees/presentation/screens/employee_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fake_employee_repository.dart';
import '../../../roles/data/fake_role_repository.dart';

Employee _employeeWithActiveUntil({
  required String id,
  DateTime? activeUntil,
}) => Employee(
  id: id,
  firstName: 'Бат',
  lastName: 'Дорж',
  email: '$id@example.com',
  phone: '99001234',
  roleId: 'role-1',
  roleName: 'Механик',
  branchId: 'b-1',
  isActive: true,
  activeUntil: activeUntil,
  verified: true,
);

void main() {
  User user({bool isOwner = false}) => User(
    accessToken: 'token',
    refreshToken: 'refresh',
    id: 'user',
    email: 'user@example.test',
    firstName: 'Test',
    lastName: 'User',
    phone: '99001122',
    isOwner: isOwner,
    role: UserRole('role', 'Role', const ['employees.view', 'employees.edit']),
    tenant: UserTenant('tenant', 'Tenant'),
  );

  Future<void> pumpAt(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('owner toggle is hidden for a non-owner caller (create)', (
    tester,
  ) async {
    await pumpAt(
      tester,
      EmployeeFormScreen(
        repo: FakeEmployeeRepository(),
        rolesRepo: FakeRoleRepository(),
        user: user(isOwner: false),
      ),
    );
    expect(
      find.byKey(const ValueKey('employee_form_owner_switch')),
      findsNothing,
    );
  });

  testWidgets('owner toggle is visible for an owner caller (create)', (
    tester,
  ) async {
    await pumpAt(
      tester,
      EmployeeFormScreen(
        repo: FakeEmployeeRepository(),
        rolesRepo: FakeRoleRepository(),
        user: user(isOwner: true),
      ),
    );
    expect(
      find.byKey(const ValueKey('employee_form_owner_switch')),
      findsOneWidget,
    );
  });

  testWidgets('owner toggle never shows on edit, even for an owner caller', (
    tester,
  ) async {
    await pumpAt(
      tester,
      EmployeeFormScreen(
        employee: FakeEmployeeRepository.seedEmployee(id: 'u-1'),
        repo: FakeEmployeeRepository(),
        rolesRepo: FakeRoleRepository(),
        user: user(isOwner: true),
      ),
    );
    expect(
      find.byKey(const ValueKey('employee_form_owner_switch')),
      findsNothing,
    );
  });

  testWidgets('create sends every field and reports the created employee', (
    tester,
  ) async {
    Employee? saved;
    await pumpAt(
      tester,
      EmployeeFormScreen(
        repo: FakeEmployeeRepository(),
        rolesRepo: FakeRoleRepository(),
        user: user(),
        onSaved: (e) => saved = e,
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Овог'), 'Батаа');
    await tester.enterText(find.widgetWithText(TextField, 'Нэр'), 'Оюунаа');
    await tester.enterText(
      find.widgetWithText(TextField, 'Имэйл'),
      'oyunaa@example.test',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Утас'), '99112233');
    await tester.tap(find.text('Хадгалах'));
    await tester.pumpAndSettle();

    expect(saved?.firstName, 'Оюунаа');
    expect(saved?.lastName, 'Батаа');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('DUPLICATE surfaces as an inline field error, not a crash', (
    tester,
  ) async {
    await pumpAt(
      tester,
      EmployeeFormScreen(
        repo: FakeEmployeeRepository(),
        rolesRepo: FakeRoleRepository(),
        user: user(),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Овог'), 'Дорж');
    await tester.enterText(find.widgetWithText(TextField, 'Нэр'), 'Бат');
    await tester.enterText(
      find.widgetWithText(TextField, 'Имэйл'),
      'u-1@example.com',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Утас'), '90009000');
    await tester.tap(find.text('Хадгалах'));
    await tester.pumpAndSettle();

    expect(find.text('Давхардсан утга.'), findsOneWidget);
  });

  testWidgets(
    'edit is a whole-record PATCH: role tile is locked for an owner target',
    (tester) async {
      await pumpAt(
        tester,
        EmployeeFormScreen(
          employee: FakeEmployeeRepository.seedOwner(id: 'u-self'),
          repo: FakeEmployeeRepository(),
          rolesRepo: FakeRoleRepository(),
          user: user(isOwner: true),
        ),
      );
      final roleTile = tester.widget<ListTile>(
        find.byKey(const ValueKey('employee_form_role_tile')),
      );
      expect(roleTile.enabled, isFalse);
      expect(
        find.text('Эзэмшигчийн үүргийг өөрчлөх боломжгүй'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'activeUntil is prefilled from the existing employee and re-sent '
    'unchanged when only the name is edited (whole-record PATCH must not '
    'wipe it)',
    (tester) async {
      final existingExpiry = DateTime.utc(2027, 3, 15);
      final employee = _employeeWithActiveUntil(
        id: 'u-1',
        activeUntil: existingExpiry,
      );
      final repo = FakeEmployeeRepository(seed: [employee]);
      Employee? saved;
      await pumpAt(
        tester,
        EmployeeFormScreen(
          employee: employee,
          repo: repo,
          rolesRepo: FakeRoleRepository(),
          user: user(),
          onSaved: (e) => saved = e,
        ),
      );

      // Prefilled display — no picker interaction needed to prove this.
      expect(find.text('2027-03-15'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('employee_form_active_until_clear')),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Нэр'),
        'Шинэ нэр',
      );
      await tester.tap(find.text('Хадгалах'));
      await tester.pumpAndSettle();

      expect(saved?.firstName, 'Шинэ нэр');
      expect(saved?.activeUntil, existingExpiry);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'clearing activeUntil via the ✕ button sends null on save',
    (tester) async {
      final existingExpiry = DateTime.utc(2027, 3, 15);
      final employee = _employeeWithActiveUntil(
        id: 'u-1',
        activeUntil: existingExpiry,
      );
      final repo = FakeEmployeeRepository(seed: [employee]);
      Employee? saved;
      await pumpAt(
        tester,
        EmployeeFormScreen(
          employee: employee,
          repo: repo,
          rolesRepo: FakeRoleRepository(),
          user: user(),
          onSaved: (e) => saved = e,
        ),
      );

      expect(find.text('2027-03-15'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('employee_form_active_until_clear')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Байнгын (огноо тавиагүй)'), findsOneWidget);

      await tester.tap(find.text('Хадгалах'));
      await tester.pumpAndSettle();

      expect(saved?.activeUntil, isNull);
      await tester.pump(const Duration(seconds: 3));
    },
  );
}
