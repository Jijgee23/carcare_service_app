import 'dart:async';

import 'package:carservice_business/core/domain/user.dart';
import 'package:carservice_business/core/services/auth_storage.dart';
import 'package:carservice_business/features/auth/presentation/controllers/auth_controller.dart';
import 'package:carservice_business/features/profile/presentation/controllers/account_closure_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_account_closure_repository.dart';
import '../../../support/hive_test_setup.dart';

void main() {
  setUpAll(openTestHiveBoxes);
  tearDown(() => Authenticator.user = null);

  test(
    'a remote account_closed push arriving mid-submit is a no-op: exactly '
    'one sign-out and one message (this device\'s own), no stale guard left '
    'behind',
    () async {
      // Reproduces the backend sending the account_closed push right after
      // its DB transaction commits but before the closure HTTP response
      // returns — the push can reach this device while `submit` is still
      // awaiting `deactivate`/`delete`.
      Authenticator.user = User(
        accessToken: 'test-token',
        refreshToken: 'test-refresh',
        id: 'test-user',
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        phone: '',
        isOwner: true,
        tenant: UserTenant('test-tenant', 'Test tenant'),
      );
      final auth = AuthController();
      addTearDown(auth.dispose);

      final repo = FakeAccountClosureRepository()..closureGate = Completer<void>();
      var loggedOut = false;
      final c = AccountClosureController(
        repo,
        onClosed: () async {
          loggedOut = true;
          await auth.logout(serverCleanup: false);
        },
      );

      final submitFuture = c.submit(deleteForever: true, code: '123456');
      // submit() is now awaiting the (gated) repository call — fire this
      // device's own account_closed push, exactly like the early delivery.
      await auth.handleRemoteAccountClosed(deleted: true);

      // The push must have been ignored: submit still owns the flow, and
      // the session must still be intact (a premature handler would have
      // cleared it here).
      expect(loggedOut, isFalse);
      expect(Authenticator.user, isNotNull);

      repo.closureGate!.complete();
      expect(await submitFuture, isTrue);

      expect(loggedOut, isTrue);
      expect(Authenticator.user, isNull);
      // The guard must not be left set, or every later account_closed push
      // (a different closure, another account on this device) would be
      // silently swallowed.
      expect(Authenticator.accountClosureInFlight, isFalse);

      // A later push (this device's own arriving very late) is still
      // correctly a no-op now — just because the session is already gone.
      await auth.handleRemoteAccountClosed(deleted: true);
      expect(Authenticator.user, isNull);
    },
  );

  test('LAST_OWNER is surfaced distinctly and does not log out', () async {
    final repo = FakeAccountClosureRepository()..failWith = 'LAST_OWNER';
    var loggedOut = false;
    final c = AccountClosureController(repo, onClosed: () async => loggedOut = true);
    expect(await c.submit(deleteForever: false, code: '123456'), isFalse);
    expect(c.lastOwnerBlocked, isTrue);
    expect(loggedOut, isFalse);
  });

  test('successful delete runs the app logout flow', () async {
    final repo = FakeAccountClosureRepository();
    var loggedOut = false;
    final c = AccountClosureController(repo, onClosed: () async => loggedOut = true);
    expect(await c.submit(deleteForever: true, code: '123456'), isTrue);
    expect(repo.calls, ['delete:123456']);
    expect(loggedOut, isTrue);
  });

  test('successful deactivate runs the app logout flow', () async {
    final repo = FakeAccountClosureRepository();
    var loggedOut = false;
    final c = AccountClosureController(repo, onClosed: () async => loggedOut = true);
    expect(await c.submit(deleteForever: false, code: '123456'), isTrue);
    expect(repo.calls, ['deactivate:123456']);
    expect(loggedOut, isTrue);
  });

  test('OTP_INVALID is surfaced as a distinct error and does not log out', () async {
    final repo = FakeAccountClosureRepository()..failWith = 'OTP_INVALID';
    var loggedOut = false;
    final c = AccountClosureController(repo, onClosed: () async => loggedOut = true);
    expect(await c.submit(deleteForever: true, code: '000000'), isFalse);
    expect(c.lastOwnerBlocked, isFalse);
    expect(c.error, isNotNull);
    expect(loggedOut, isFalse);
  });

  test('requestOtp stores the masked phone on success', () async {
    final repo = FakeAccountClosureRepository()..maskedPhoneToReturn = '9900**11';
    final c = AccountClosureController(repo, onClosed: () async {});
    expect(await c.requestOtp(), isTrue);
    expect(c.maskedPhone, '9900**11');
  });

  test('requestOtp surfaces a failure without a masked phone', () async {
    final repo = FakeAccountClosureRepository()..failWith = 'RATE_LIMITED';
    final c = AccountClosureController(repo, onClosed: () async {});
    expect(await c.requestOtp(), isFalse);
    expect(c.maskedPhone, isNull);
    expect(c.error, isNotNull);
  });

  test('requestOtp(forDelete) forwards the purpose and surfaces OPEN_ORDERS', () async {
    final repo = FakeAccountClosureRepository()..failWith = 'OPEN_ORDERS';
    final c = AccountClosureController(repo, onClosed: () async {});
    expect(await c.requestOtp(forDelete: true), isFalse);
    expect(repo.calls, ['requestOtp:delete']);
    expect(c.maskedPhone, isNull);
    expect(c.error, isNotNull);
  });
}
