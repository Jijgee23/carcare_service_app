import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/features/employees/presentation/screens/employee_detail_screen.dart';
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

  testWidgets(
    'renders the employee info and hides actions without permission',
    (tester) async {
      await pumpAt(
        tester,
        EmployeeDetailScreen(
          employeeId: 'u-1',
          repo: FakeEmployeeRepository(),
          user: user(const ['employees.view']),
        ),
      );
      expect(find.text('Дорж Бат'), findsWidgets);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.text('Нууц үг дахин тохируулах'), findsNothing);
    },
  );

  testWidgets('shows edit/delete/reset actions with employees.edit/.delete', (
    tester,
  ) async {
    await pumpAt(
      tester,
      EmployeeDetailScreen(
        employeeId: 'u-1',
        repo: FakeEmployeeRepository(),
        user: user(const [
          'employees.view',
          'employees.edit',
          'employees.delete',
        ]),
        onEdit: (_) {},
      ),
    );
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
    expect(find.text('Нууц үг дахин тохируулах'), findsOneWidget);
  });

  testWidgets(
    'reset-password confirmation explains OTP re-activation and never '
    'shows a password',
    (tester) async {
      await pumpAt(
        tester,
        EmployeeDetailScreen(
          employeeId: 'u-1',
          repo: FakeEmployeeRepository(),
          user: user(const ['employees.view', 'employees.edit']),
        ),
      );
      await tester.tap(find.text('Нууц үг дахин тохируулах'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('баталгаажуулж (OTP) шинээр идэвхжүүлэх'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Шинэ нууц үг энд харагдахгүй'),
        findsOneWidget,
      );
      // Dismiss the sheet without confirming to avoid the pending toast timer.
      await tester.tap(find.text('Болих'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('toggling active still confirms and submits when the server will '
      'reject it (LAST_OWNER) — the surfaced message itself is covered by '
      'EmployeeDetailController\'s own unit test, since the toast requires a '
      'GlobalKeys.navigator-wired app shell no widget test constructs', (
    tester,
  ) async {
    final repo = FakeEmployeeRepository(
      seed: [FakeEmployeeRepository.seedOwner(id: 'owner-1')],
      currentUserId: 'someone-else',
    );
    await pumpAt(
      tester,
      EmployeeDetailScreen(
        employeeId: 'owner-1',
        repo: repo,
        user: user(const ['employees.view', 'employees.edit']),
      ),
    );
    await tester.tap(find.text('Идэвхгүй болгох'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Тийм'));
    await tester.pumpAndSettle();

    // The record must not have flipped to inactive — the screen still
    // offers "Идэвхгүй болгох" (not "Идэвхжүүлэх"), proving the rejected
    // toggle never mutated local state either.
    expect(find.text('Идэвхгүй болгох'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('delete confirmation then success pops the screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('root')),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => EmployeeDetailScreen(
          employeeId: 'u-1',
          repo: FakeEmployeeRepository(),
          user: user(const ['employees.view', 'employees.delete']),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Устгах'));
    await tester.pumpAndSettle();

    expect(find.byType(EmployeeDetailScreen), findsNothing);
    // Flush the toast's pending dismiss timer before the test tears down.
    await tester.pump(const Duration(seconds: 3));
  });
}
