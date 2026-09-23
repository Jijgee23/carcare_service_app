import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/features/roles/presentation/screens/role_list_screen.dart';

import '../data/fake_role_repository.dart';

/// Widget coverage for `RoleListScreen` — P6-F3.
void main() {
  User user({required bool isOwner}) => User(
    accessToken: 'token',
    refreshToken: 'refresh',
    id: 'user',
    email: 'user@example.test',
    firstName: 'Test',
    lastName: 'User',
    phone: '99001122',
    isOwner: isOwner,
    role: UserRole('role', 'Role', const []),
    tenant: UserTenant('tenant', 'Tenant'),
  );

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  group('owner gate (D-171)', () {
    testWidgets('a non-owner sees a refusal state, not the list', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        RoleListScreen(
          repository: FakeRoleRepository(),
          user: user(isOwner: false),
        ),
      );

      expect(find.text('Механик'), findsNothing);
      expect(
        find.text('Зөвхөн эзэмшигч энэ хэсгийг удирдана.'),
        findsOneWidget,
      );
    });

    testWidgets('an owner sees the role list', (tester) async {
      await pumpScreen(
        tester,
        RoleListScreen(
          repository: FakeRoleRepository(),
          user: user(isOwner: true),
        ),
      );

      expect(find.text('Механик'), findsOneWidget);
    });
  });

  group('delete', () {
    testWidgets('confirming delete removes the role from the list', (
      tester,
    ) async {
      final repo = FakeRoleRepository(
        seed: [FakeRoleRepository.seedRole(id: 'r1', name: 'Механик')],
      );
      await pumpScreen(
        tester,
        RoleListScreen(repository: repo, user: user(isOwner: true)),
      );
      expect(find.text('Механик'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Үүрэг устгах'), findsOneWidget);

      await tester.tap(find.text('Устгах'));
      await tester.pumpAndSettle();

      expect(find.text('Механик'), findsNothing);
    });

    testWidgets('canceling delete keeps the role', (tester) async {
      final repo = FakeRoleRepository(
        seed: [FakeRoleRepository.seedRole(id: 'r1', name: 'Механик')],
      );
      await pumpScreen(
        tester,
        RoleListScreen(repository: repo, user: user(isOwner: true)),
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Болих'));
      await tester.pumpAndSettle();

      expect(find.text('Механик'), findsOneWidget);
    });

    testWidgets('ROLE_IN_USE surfaces via a snackbar and keeps the role', (
      tester,
    ) async {
      final repo = FakeRoleRepository(
        seed: [FakeRoleRepository.seedRole(id: 'r1', name: 'Механик')],
      );
      repo.userCountByRole['r1'] = 3;
      await pumpScreen(
        tester,
        RoleListScreen(repository: repo, user: user(isOwner: true)),
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Устгах'));
      await tester.pumpAndSettle();

      expect(find.text('Механик'), findsOneWidget);
      expect(
        find.text('Энэ үүрэг хэрэглэгдэж байгаа тул устгах боломжгүй.'),
        findsOneWidget,
      );
    });
  });
}
