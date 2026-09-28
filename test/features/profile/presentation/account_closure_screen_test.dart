import 'package:carcare_service/features/profile/presentation/screens/account_closure_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_account_closure_repository.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('shows both closure options', (tester) async {
    await pumpAt(
      tester,
      AccountClosureScreen(
        repository: FakeAccountClosureRepository(),
        onClosed: () async {},
      ),
    );
    expect(find.text('Идэвхгүй болгох'), findsOneWidget);
    expect(find.text('Бүрмөсөн устгах'), findsOneWidget);
  });

  testWidgets('no horizontal overflow at 375dp', (tester) async {
    await pumpAt(
      tester,
      AccountClosureScreen(
        repository: FakeAccountClosureRepository(),
        onClosed: () async {},
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('deactivate: requesting an OTP shows the code step', (tester) async {
    await pumpAt(
      tester,
      AccountClosureScreen(
        repository: FakeAccountClosureRepository(),
        onClosed: () async {},
      ),
    );

    await tester.tap(find.byKey(const ValueKey('account_closure_deactivate_option')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account_closure_request_otp')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account_closure_request_otp')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('account_closure_code_field')), findsOneWidget);
    expect(find.textContaining('код илгээлээ'), findsOneWidget);
    expect(find.byKey(const ValueKey('account_closure_confirm')), findsOneWidget);
  });

  testWidgets('delete forever: shows an extra confirm dialog before submitting', (
    tester,
  ) async {
    final repo = FakeAccountClosureRepository();
    var loggedOut = false;
    await pumpAt(
      tester,
      AccountClosureScreen(
        repository: repo,
        onClosed: () async => loggedOut = true,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('account_closure_delete_option')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account_closure_request_otp')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('account_closure_code_field')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey('account_closure_confirm')));
    await tester.pumpAndSettle();

    // The dangerous-delete confirmation sheet appears and blocks submission
    // until confirmed.
    expect(find.text('Бүрмөсөн устгах уу?'), findsOneWidget);
    expect(repo.calls, isNot(contains('delete:123456')));
    expect(loggedOut, isFalse);

    await tester.tap(find.text('Устгах').last);
    await tester.pumpAndSettle();

    expect(repo.calls, contains('delete:123456'));
    expect(loggedOut, isTrue);
    // The success toast renders on the app's global navigator overlay (not
    // mounted in this harness); just let its auto-dismiss timer run out.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('LAST_OWNER failure shows the dedicated copy and does not log out', (
    tester,
  ) async {
    final repo = FakeAccountClosureRepository();
    var loggedOut = false;
    await pumpAt(
      tester,
      AccountClosureScreen(
        repository: repo,
        onClosed: () async => loggedOut = true,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('account_closure_deactivate_option')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account_closure_request_otp')));
    await tester.pumpAndSettle();
    // Only the submit call fails — the OTP request above already succeeded.
    repo.failWith = 'LAST_OWNER';
    await tester.enterText(
      find.byKey(const ValueKey('account_closure_code_field')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey('account_closure_confirm')));
    await tester.pumpAndSettle();

    expect(
      find.text('Та байгууллагын цорын ганц эзэмшигч тул эхлээд өөр эзэмшигч томилно уу.'),
      findsOneWidget,
    );
    expect(loggedOut, isFalse);
  });

  testWidgets('delete: a refused code request (OPEN_ORDERS) shows the error on the request step', (
    tester,
  ) async {
    final repo = FakeAccountClosureRepository()..failWith = 'OPEN_ORDERS';
    await pumpAt(
      tester,
      AccountClosureScreen(repository: repo, onClosed: () async {}),
    );

    await tester.tap(find.byKey(const ValueKey('account_closure_delete_option')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account_closure_request_otp')));
    await tester.pumpAndSettle();

    expect(repo.calls, ['requestOtp:delete']);
    expect(find.byKey(const ValueKey('account_closure_request_error')), findsOneWidget);
    expect(find.byKey(const ValueKey('account_closure_code_field')), findsNothing);
    expect(find.byKey(const ValueKey('account_closure_request_otp')), findsOneWidget);
  });
}
