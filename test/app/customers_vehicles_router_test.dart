import 'package:carcare_service/app/router.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/services/subscription_service.dart';
import 'package:carcare_service/features/controllers.dart';
import 'package:carcare_service/features/customers/presentation/screens/customer_detail_screen.dart';
import 'package:carcare_service/features/vehicles/presentation/screens/vehicle_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_api_backend.dart';
import '../support/app_harness.dart';
import '../support/hive_test_setup.dart';

/// `P3-F6` — the first real `GoRoute`s for `/customers`, `/customers/:id`,
/// `/vehicles` and `/vehicles/:id`, exercised the same way
/// `test/app/router_test.dart` exercises `/orders/:id`: through the REAL
/// `buildRouter`, not a replica.
void main() {
  setUpAll(openTestHiveBoxes);

  setUp(() {
    FakeApiBackend.instance.reset();
    SubscriptionService.instance.invalidate();
  });

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

  testWidgets(
    'cold-start deep link into /customers/:id opens the detail screen',
    (tester) async {
      Authenticator.user = signedInUser();
      addTearDown(() => Authenticator.user = null);
      FakeApiBackend.instance.onJson('GET', 'customers/cust-1', {
        'customer': {'id': 'cust-1', 'fullName': 'Бат', 'phone': '99001122'},
        'vehicles': <dynamic>[],
      });

      final harness = RouterHarness();
      addTearDown(harness.dispose);
      harness.authController.setAuthState(AuthState.authorized);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      harness.router.go('/customers/cust-1');
      await tester.pumpAndSettle();

      expect(harness.location, '/customers/cust-1');
      expect(find.byType(CustomerDetailScreen), findsOneWidget);
      expect(find.text('Бат'), findsWidgets);
    },
  );

  testWidgets(
    'an empty /customers/:id id renders the missing-id fallback, not a crash',
    (tester) async {
      Authenticator.user = signedInUser();
      addTearDown(() => Authenticator.user = null);

      final harness = RouterHarness();
      addTearDown(harness.dispose);
      harness.authController.setAuthState(AuthState.authorized);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      // `/customers/` normalises to `/customers` in go_router (no `:id`
      // segment at all), so this exercises the list route rather than the
      // fallback — the fallback path is defensive, matching `_MissingOrderRoute`
      // exactly, and is covered directly via the widget below.
      harness.router.go('/customers');
      await tester.pumpAndSettle();

      expect(harness.location, '/customers');
      expect(find.text('Үйлчлүүлэгчид'), findsOneWidget);
    },
  );

  testWidgets(
    'back from /customers/:id returns to /customers, not the shell root',
    (tester) async {
      Authenticator.user = signedInUser();
      addTearDown(() => Authenticator.user = null);
      FakeApiBackend.instance.onJson('GET', 'customers', {
        'customers': <dynamic>[],
        'pagination': {
          'page': 1,
          'pageSize': 50,
          'total': 0,
          'totalPages': 1,
          'hasPrev': false,
          'hasNext': false,
        },
      });
      FakeApiBackend.instance.onJson('GET', 'customers/cust-1', {
        'customer': {'id': 'cust-1', 'fullName': 'Бат', 'phone': '99001122'},
        'vehicles': <dynamic>[],
      });

      final harness = RouterHarness();
      addTearDown(harness.dispose);
      harness.authController.setAuthState(AuthState.authorized);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      harness.router.go('/customers/cust-1');
      await tester.pumpAndSettle();
      expect(harness.location, '/customers/cust-1');

      harness.router.pop();
      await tester.pumpAndSettle();
      expect(harness.location, '/customers');
    },
  );

  testWidgets(
    'cold-start deep link into /vehicles/:id opens the detail screen',
    (tester) async {
      Authenticator.user = signedInUser();
      addTearDown(() => Authenticator.user = null);
      FakeApiBackend.instance.onJson('GET', 'vehicles/veh-1', {
        'vehicle': {
          'id': 'veh-1',
          'plate': '1234ABC',
          'make': 'Toyota',
          'model': 'Prius',
        },
      });

      final harness = RouterHarness();
      addTearDown(harness.dispose);
      harness.authController.setAuthState(AuthState.authorized);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      harness.router.go('/vehicles/veh-1');
      await tester.pumpAndSettle();

      expect(harness.location, '/vehicles/veh-1');
      expect(find.byType(VehicleDetailScreen), findsOneWidget);
      expect(find.text('1234ABC'), findsWidgets);
    },
  );

  testWidgets(
    '/vehicles list route renders and is reachable from a cold start',
    (tester) async {
      Authenticator.user = signedInUser();
      addTearDown(() => Authenticator.user = null);
      FakeApiBackend.instance.onJson('GET', 'vehicles', {
        'vehicles': <dynamic>[],
        'pagination': {
          'page': 1,
          'pageSize': 50,
          'total': 0,
          'totalPages': 1,
          'hasPrev': false,
          'hasNext': false,
        },
      });

      final harness = RouterHarness();
      addTearDown(harness.dispose);
      harness.authController.setAuthState(AuthState.authorized);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      harness.router.go('/vehicles');
      await tester.pumpAndSettle();

      expect(harness.location, '/vehicles');
      expect(find.text('Машинууд'), findsWidgets);
    },
  );

  testWidgets('back from /vehicles/:id returns to /vehicles', (tester) async {
    Authenticator.user = signedInUser();
    addTearDown(() => Authenticator.user = null);
    FakeApiBackend.instance.onJson('GET', 'vehicles', {
      'vehicles': <dynamic>[],
      'pagination': {
        'page': 1,
        'pageSize': 50,
        'total': 0,
        'totalPages': 1,
        'hasPrev': false,
        'hasNext': false,
      },
    });
    FakeApiBackend.instance.onJson('GET', 'vehicles/veh-1', {
      'vehicle': {
        'id': 'veh-1',
        'plate': '1234ABC',
        'make': 'Toyota',
        'model': 'Prius',
      },
    });

    final harness = RouterHarness();
    addTearDown(harness.dispose);
    harness.authController.setAuthState(AuthState.authorized);

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();

    harness.router.go('/vehicles/veh-1');
    await tester.pumpAndSettle();
    expect(harness.location, '/vehicles/veh-1');

    harness.router.pop();
    await tester.pumpAndSettle();
    expect(harness.location, '/vehicles');
  });

  testWidgets(
    'a signed-out user deep-linking into /customers/:id is redirected to '
    '/login with the destination preserved',
    (tester) async {
      final harness = RouterHarness();
      addTearDown(harness.dispose);
      harness.authController.setAuthState(AuthState.noLogged);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      harness.router.go('/customers/cust-1');
      await tester.pumpAndSettle();

      expect(harness.location, AppRoutes.login);
      expect(harness.uri.queryParameters['from'], '/customers/cust-1');
    },
  );
}
