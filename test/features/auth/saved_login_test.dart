import 'dart:typed_data';

import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/services/saved_login_store.dart';
import 'package:carcare_service/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../support/hive_test_setup.dart';

void main() {
  setUpAll(() async {
    await openTestHiveBoxes();
    if (!Hive.isBoxOpen(HiveSavedLoginStore.boxName)) {
      await Hive.openBox<dynamic>(
        HiveSavedLoginStore.boxName,
        bytes: Uint8List(0),
      );
    }
  });

  setUp(() async {
    await Authenticator.clear();
    await Hive.box<dynamic>(HiveSavedLoginStore.boxName).clear();
    await Hive.box<dynamic>('device').clear();
  });

  const loginOk = AuthResponse(200, {
    'accessToken': 'access',
    'refreshToken': 'refresh',
    'user': {
      'id': 'u-1',
      'email': 'bat@example.mn',
      'firstName': 'Бат',
      'lastName': 'Болд',
      'phone': '99112233',
      'isOwner': false,
      'branchId': null,
      'role': null,
      'tenant': {'id': 't-1', 'name': 'Инфосистемс'},
    },
  });

  AuthController controller(SavedLoginStore store) => AuthController(
    savedLogins: store,
    onSignedIn: () async {},
    transport: (path, body) async => switch (path) {
      'auth/check-email' => const AuthResponse(200, {
        'status': 'password',
        'identifier': '99112233',
      }),
      'auth/login' => loginOk,
      _ => throw StateError(path),
    },
  );

  Future<void> signIn(AuthController auth, String typed) async {
    auth.identifierCtrl.text = typed;
    await auth.checkIdentifier();
    auth.passwordCtrl.text = 'secret-pass';
    await auth.login();
  }

  test('successful login saves who signed in — never the password', () async {
    final store = MemorySavedLoginStore();
    final auth = controller(store);
    addTearDown(auth.dispose);

    await signIn(auth, '9911-2233');

    expect(auth.authState, AuthState.authorized);
    final saved = await store.read();
    expect(saved, isNotNull);
    expect(saved!.identifier, '9911-2233'); // as typed
    expect(saved.email, 'bat@example.mn');
    expect(saved.phone, '99112233');
    expect(saved.displayName, 'Болд Бат');
    expect(saved.tenantName, 'Инфосистемс');
    final stored = saved.toMap().toString();
    expect(stored, isNot(contains('secret-pass')));
    expect(stored, isNot(contains('access')));
    expect(stored, isNot(contains('refresh')));
  });

  test('logout clears the session but prefills the identifier', () async {
    final store = MemorySavedLoginStore();
    final auth = controller(store);
    addTearDown(auth.dispose);
    await signIn(auth, 'bat@example.mn');
    expect(Authenticator.user, isNotNull);

    // Simulate the session already being gone (e.g. forced 401 logout) so
    // logout makes no network call in this test.
    await Authenticator.clear();
    auth.identifierCtrl.clear();
    await auth.logout();

    expect(auth.authState, AuthState.noLogged);
    expect(auth.step, LoginStep.identifier);
    expect(auth.identifierCtrl.text, 'bat@example.mn');
    expect(auth.passwordCtrl.text, isEmpty);
    expect(Authenticator.user, isNull);
    // The saved login outlives the session.
    expect((await store.read())?.identifier, 'bat@example.mn');
  });

  test('app start with no session prefills from the saved login', () async {
    final store = MemorySavedLoginStore(
      SavedLogin(identifier: '88001122', lastLoginAt: DateTime(2026, 9, 1)),
    );
    final auth = controller(store);
    addTearDown(auth.dispose);
    await auth.loadUser();
    expect(auth.authState, AuthState.noLogged);
    expect(auth.identifierCtrl.text, '88001122');
    expect(auth.savedLogin?.identifier, '88001122');
  });

  group('HiveSavedLoginStore', () {
    test(
      'round-trips through its own box, separate from Authenticator',
      () async {
        final store = HiveSavedLoginStore.instance;
        await store.write(
          SavedLogin(
            identifier: 'bat@example.mn',
            firstName: 'Бат',
            lastLoginAt: DateTime(2026, 9, 25, 10),
          ),
        );
        final read = await store.read();
        expect(read?.identifier, 'bat@example.mn');
        expect(read?.firstName, 'Бат');
        expect(read?.lastLoginAt, DateTime(2026, 9, 25, 10));
        // Clearing the session leaves it alone.
        await Authenticator.clear();
        expect((await store.read())?.identifier, 'bat@example.mn');
      },
    );

    test('falls back to the legacy identifier key once', () async {
      await Hive.box<dynamic>('device').put('last_email', 'old@example.mn');
      expect(
        (await HiveSavedLoginStore.instance.read())?.identifier,
        'old@example.mn',
      );
    });

    test('a corrupt entry reads as nothing, not a crash', () async {
      await Hive.box<dynamic>(HiveSavedLoginStore.boxName)
          .put('last', 'garbage');
      expect(await HiveSavedLoginStore.instance.read(), isNull);
    });
  });
}
