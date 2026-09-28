import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/hive_test_setup.dart';

/// Covers `AuthController.handleRemoteAccountClosed` (the silent
/// `account_closed` FCM data push — deactivation/deletion, including from
/// the website): local-only sign-out, no server call
/// (`logout(serverCleanup: false)`), and idempotent when already signed out.
void main() {
  setUpAll(openTestHiveBoxes);

  User signedInUser() => User(
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

  tearDown(() => Authenticator.user = null);

  test(
    'signs out locally when signed in, without any server-cleanup call',
    () async {
      Authenticator.user = signedInUser();
      var onSignedInCalls = 0;
      final auth = AuthController(onSignedIn: () async => onSignedInCalls++);
      addTearDown(auth.dispose);

      await auth.handleRemoteAccountClosed(deleted: true);

      expect(Authenticator.user, isNull);
      expect(auth.authState, AuthState.noLogged);
      // `onSignedIn` is a post-*login* hook — must never fire on a closure.
      expect(onSignedInCalls, 0);
    },
  );

  test('is a no-op when already signed out', () async {
    Authenticator.user = null;
    final auth = AuthController();
    addTearDown(auth.dispose);

    // Would throw/attempt network if it fell through to logout()'s
    // serverCleanup branch with no scripted transport — a no-op proves the
    // idempotency guard runs first.
    await auth.handleRemoteAccountClosed(deleted: false);

    expect(Authenticator.user, isNull);
  });

  test('deleted vs deactivated both clear the session', () async {
    for (final deleted in [true, false]) {
      Authenticator.user = signedInUser();
      final auth = AuthController();
      addTearDown(auth.dispose);

      await auth.handleRemoteAccountClosed(deleted: deleted);

      expect(Authenticator.user, isNull);
    }
  });
}
