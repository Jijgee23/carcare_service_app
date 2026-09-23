import 'package:carcare_service/features/profile/domain/account_session.dart';
import 'package:carcare_service/features/profile/presentation/screens/sessions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_account_repository.dart';

void main() {
  AccountSession session({
    required String id,
    AccountSessionSource source = AccountSessionSource.mobile,
    bool current = false,
    AccountSessionStatus status = AccountSessionStatus.active,
    String deviceLabel = 'iPhone 15',
  }) => AccountSession(
    id: id,
    source: source,
    deviceLabel: deviceLabel,
    status: status,
    current: current,
    ip: '10.0.0.1',
    createdAt: DateTime(2026, 9, 1),
    lastActivityAt: DateTime(2026, 9, 20),
  );

  Future<void> pumpAt(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the current-device badge and source tags', (tester) async {
    await pumpAt(
      tester,
      SessionsScreen(
        repository: FakeAccountRepository(
          sessions: [
            session(id: 's-cur', current: true, deviceLabel: 'Энэ утас'),
            session(id: 's-web', source: AccountSessionSource.web, deviceLabel: 'Chrome'),
          ],
        ),
      ),
    );

    expect(find.text('Энэ төхөөрөмж'), findsOneWidget);
    expect(find.text('Мобайл'), findsOneWidget);
    expect(find.text('Веб'), findsOneWidget);
  });

  testWidgets('active and ended sections both render', (tester) async {
    await pumpAt(
      tester,
      SessionsScreen(
        repository: FakeAccountRepository(
          sessions: [
            session(id: 's-cur', current: true),
            session(id: 's-ended', status: AccountSessionStatus.revoked),
          ],
        ),
      ),
    );

    expect(find.text('Идэвхтэй'), findsOneWidget);
    expect(find.text('Дууссан'), findsOneWidget);
  });

  testWidgets(
    'revoke-others is hidden when otherActiveCount is 0',
    (tester) async {
      await pumpAt(
        tester,
        SessionsScreen(
          repository: FakeAccountRepository(
            sessions: [session(id: 's-cur', current: true)],
          ),
        ),
      );

      expect(find.textContaining('Бусдыг гаргах'), findsNothing);
    },
  );

  testWidgets(
    'revoke-others is shown and confirms via ConfirmSheet',
    (tester) async {
      await pumpAt(
        tester,
        SessionsScreen(
          repository: FakeAccountRepository(
            sessions: [
              session(id: 's-cur', current: true),
              session(id: 's-other'),
            ],
          ),
        ),
      );

      expect(find.textContaining('Бусдыг гаргах'), findsOneWidget);
      await tester.tap(find.textContaining('Бусдыг гаргах'));
      await tester.pumpAndSettle();
      expect(find.text('Бусдыг гаргах уу?'), findsOneWidget);

      await tester.tap(find.text('Гаргах'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Бусдыг гаргах'), findsNothing);
    },
  );

  testWidgets('revoking one device asks to confirm first', (tester) async {
    await pumpAt(
      tester,
      SessionsScreen(
        repository: FakeAccountRepository(
          sessions: [
            session(id: 's-cur', current: true),
            session(id: 's-other', deviceLabel: 'Android'),
          ],
        ),
      ),
    );

    // Two active sessions here also draw the "revoke others" button, which
    // shares the same icon — the 2nd logout icon (index 1) is the
    // 's-other' tile's own revoke button, not the group action.
    await tester.tap(find.byIcon(Icons.logout_rounded).at(1));
    await tester.pumpAndSettle();

    expect(find.text('Гаргах уу?'), findsOneWidget);
  });

  testWidgets('renders at 375dp without overflow', (tester) async {
    await pumpAt(
      tester,
      SessionsScreen(
        repository: FakeAccountRepository(
          sessions: List.generate(
            4,
            (i) => session(
              id: 's-$i',
              current: i == 0,
              deviceLabel: 'Урт төхөөрөмжийн нэрийн жишээ бичвэр $i',
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('empty active list shows the empty state', (tester) async {
    await pumpAt(
      tester,
      SessionsScreen(repository: FakeAccountRepository(sessions: const [])),
    );

    expect(find.text('Идэвхтэй нэвтрэлт алга'), findsOneWidget);
  });
}
