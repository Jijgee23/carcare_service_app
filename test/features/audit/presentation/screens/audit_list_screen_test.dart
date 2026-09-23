import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/features/audit/presentation/screens/audit_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_audit_repository.dart';

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

  group('permission gate', () {
    testWidgets('denies without audit.view', (tester) async {
      await pumpAt(
        tester,
        AuditListScreen(repository: FakeAuditRepository(), user: user(const [])),
      );
      expect(
        find.text('Танд аудит лог харах эрх байхгүй байна.'),
        findsOneWidget,
      );
    });

    testWidgets('a user with audit.view sees the list', (tester) async {
      await pumpAt(
        tester,
        AuditListScreen(
          repository: FakeAuditRepository(
            seed: [FakeAuditRepository.seedEntry(id: 'a-1', summary: 'Захиалга үүсгэсэн')],
          ),
          user: user(const ['audit.view']),
        ),
      );
      expect(find.text('Захиалга үүсгэсэн'), findsOneWidget);
    });

    testWidgets('the owner sees the list without an explicit permission', (tester) async {
      await pumpAt(
        tester,
        AuditListScreen(
          repository: FakeAuditRepository(
            seed: [FakeAuditRepository.seedEntry(id: 'a-1', summary: 'Захиалга үүсгэсэн')],
          ),
          user: user(const [], isOwner: true),
        ),
      );
      expect(find.text('Захиалга үүсгэсэн'), findsOneWidget);
    });
  });

  testWidgets('renders at 375dp without overflow', (tester) async {
    await pumpAt(
      tester,
      AuditListScreen(
        repository: FakeAuditRepository(
          seed: List.generate(5, (i) => FakeAuditRepository.seedEntry(id: 'a-$i')),
        ),
        user: user(const ['audit.view']),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an entry opens the detail sheet with before/after', (tester) async {
    await pumpAt(
      tester,
      AuditListScreen(
        repository: FakeAuditRepository(
          seed: [
            FakeAuditRepository.seedEntry(
              id: 'a-1',
              summary: 'Захиалга үүсгэсэн',
              before: const {'status': 'DRAFT'},
              after: const {'status': 'NEW'},
            ),
          ],
        ),
        user: user(const ['audit.view']),
      ),
    );
    await tester.tap(find.text('Захиалга үүсгэсэн'));
    await tester.pumpAndSettle();

    expect(find.textContaining('"status": "DRAFT"'), findsOneWidget);
    expect(find.textContaining('"status": "NEW"'), findsOneWidget);
  });

  testWidgets('search filters the list', (tester) async {
    await pumpAt(
      tester,
      AuditListScreen(
        repository: FakeAuditRepository(
          seed: [
            FakeAuditRepository.seedEntry(id: 'a-1', summary: 'Захиалга үүсгэсэн'),
            FakeAuditRepository.seedEntry(id: 'a-2', summary: 'Ажилтан устгасан'),
          ],
        ),
        user: user(const ['audit.view']),
      ),
    );
    expect(find.text('Захиалга үүсгэсэн'), findsOneWidget);
    expect(find.text('Ажилтан устгасан'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ажилтан');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Захиалга үүсгэсэн'), findsNothing);
    expect(find.text('Ажилтан устгасан'), findsOneWidget);
  });
}
