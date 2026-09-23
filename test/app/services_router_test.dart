import 'package:carcare_service/app/router.dart';
import 'package:carcare_service/app/shell/app_shell.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/services/subscription_service.dart';
import 'package:carcare_service/features/controllers.dart';
import 'package:carcare_service/features/services/presentation/screens/create_service_screen.dart';
import 'package:carcare_service/features/services/presentation/screens/service_detail_screen.dart';
import 'package:carcare_service/features/services/presentation/screens/service_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_api_backend.dart';
import '../support/app_harness.dart';
import '../support/hive_test_setup.dart';

/// `P4-F4` — the first real `GoRoute`s for `/services`, `/services/:id` and
/// `/services/new`, exercised the same way
/// `test/app/customers_vehicles_router_test.dart` exercises
/// `/customers`/`/vehicles` (`P3-F6`): through the REAL `buildRouter`, not a
/// replica.
///
/// `Map<String,dynamic>` JSON fixtures: only `id` is structurally required
/// by `Service.fromJson`/`ServicePageDto.fromJson` (see
/// `service_dto.dart`/`service.dart`), so fixtures below carry just enough
/// fields for the assertion each test makes.
///
/// A cold-start `go()` into a nested route also builds every ancestor page
/// on the Navigator stack (`_ServiceListRoute` under `/services/:id` or
/// `/services/new`), so most tests register a `GET services` (list) fixture
/// alongside the more specific one even when the assertion only cares about
/// the child screen. `FakeApiBackend` matches the FIRST registered script
/// whose `pathContains` substring-matches, so the more specific path
/// (`services/svc-1`) must be registered before the general one
/// (`services`) — otherwise the general script would swallow the specific
/// request too, since `'.../services/svc-1'.contains('services')`.
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

  Map<String, dynamic> emptyServicePage() => {
    'services': <dynamic>[],
    'pagination': {
      'page': 1,
      'pageSize': 50,
      'total': 0,
      'totalPages': 1,
      'hasPrev': false,
      'hasNext': false,
    },
  };

  testWidgets(
    'cold-start deep link into /services/:id opens the detail screen',
    (tester) async {
      Authenticator.user = signedInUser();
      addTearDown(() => Authenticator.user = null);
      FakeApiBackend.instance.onJson('GET', 'services/svc-1', {
        'service': {
          'id': 'svc-1',
          'name': 'Тос солих',
          'type': 'LABOR',
          'price': '25000',
          'isActive': true,
        },
      });
      FakeApiBackend.instance.onJson('GET', 'services', emptyServicePage());

      final harness = RouterHarness();
      addTearDown(harness.dispose);
      harness.authController.setAuthState(AuthState.authorized);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      harness.router.go('/services/svc-1');
      await tester.pumpAndSettle();

      expect(harness.location, '/services/svc-1');
      expect(find.byType(ServiceDetailScreen), findsOneWidget);
      expect(find.text('Тос солих'), findsWidgets);
    },
  );

  testWidgets('an empty /services/:id id renders the list route, not a crash', (
    tester,
  ) async {
    Authenticator.user = signedInUser();
    addTearDown(() => Authenticator.user = null);
    FakeApiBackend.instance.onJson('GET', 'services', emptyServicePage());

    final harness = RouterHarness();
    addTearDown(harness.dispose);
    harness.authController.setAuthState(AuthState.authorized);

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();

    // `/services/` normalises to `/services` in go_router (no `:id`
    // segment at all), so this exercises the list route rather than the
    // fallback — the fallback path is defensive, matching
    // `_MissingCustomerRoute`/`_MissingVehicleRoute` exactly.
    harness.router.go('/services');
    await tester.pumpAndSettle();

    expect(harness.location, '/services');
    expect(find.text('Үйлчилгээний каталог'), findsWidgets);
  });

  testWidgets(
    'back from /services/:id returns to /services, not the shell root',
    (tester) async {
      Authenticator.user = signedInUser();
      addTearDown(() => Authenticator.user = null);
      FakeApiBackend.instance.onJson('GET', 'services/svc-1', {
        'service': {'id': 'svc-1', 'name': 'Тос солих', 'type': 'LABOR'},
      });
      FakeApiBackend.instance.onJson('GET', 'services', emptyServicePage());

      final harness = RouterHarness();
      addTearDown(harness.dispose);
      harness.authController.setAuthState(AuthState.authorized);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      harness.router.go('/services/svc-1');
      await tester.pumpAndSettle();
      expect(harness.location, '/services/svc-1');

      harness.router.pop();
      await tester.pumpAndSettle();
      expect(harness.location, '/services');
    },
  );

  testWidgets(
    '/services list route renders and is reachable from a cold start',
    (tester) async {
      Authenticator.user = signedInUser();
      addTearDown(() => Authenticator.user = null);
      FakeApiBackend.instance.onJson('GET', 'services', emptyServicePage());

      final harness = RouterHarness();
      addTearDown(harness.dispose);
      harness.authController.setAuthState(AuthState.authorized);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      harness.router.go('/services');
      await tester.pumpAndSettle();

      expect(harness.location, '/services');
      expect(find.text('Үйлчилгээний каталог'), findsWidgets);
    },
  );

  testWidgets(
    'cold-start deep link into /services/new?type=goods opens the create '
    'screen seeded with the GOODS kind',
    (tester) async {
      Authenticator.user = signedInUser();
      addTearDown(() => Authenticator.user = null);
      FakeApiBackend.instance.onJson('GET', 'services', emptyServicePage());

      final harness = RouterHarness();
      addTearDown(harness.dispose);
      harness.authController.setAuthState(AuthState.authorized);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      harness.router.go('/services/new?type=goods');
      await tester.pumpAndSettle();

      expect(find.byType(CreateServiceScreen), findsOneWidget);
      // `showCostAndStock` (only true for GOODS) renders the stock field —
      // this proves the `?type=` query param actually reached
      // `CreateServiceScreen.initialType`, not just that the route matched.
      expect(find.text('Нөөц тоо ширхэг'), findsOneWidget);
    },
  );

  testWidgets(
    'cold-start deep link into /services/new with no ?type= defaults to LABOR',
    (tester) async {
      Authenticator.user = signedInUser();
      addTearDown(() => Authenticator.user = null);
      FakeApiBackend.instance.onJson('GET', 'services', emptyServicePage());

      final harness = RouterHarness();
      addTearDown(harness.dispose);
      harness.authController.setAuthState(AuthState.authorized);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      harness.router.go('/services/new');
      await tester.pumpAndSettle();

      expect(find.byType(CreateServiceScreen), findsOneWidget);
      // LABOR shows duration, not the GOODS-only stock field.
      expect(find.text('Нөөц тоо ширхэг'), findsNothing);
    },
  );

  testWidgets(
    'a signed-out user deep-linking into /services/:id is redirected to '
    '/login with the destination preserved',
    (tester) async {
      final harness = RouterHarness();
      addTearDown(harness.dispose);
      harness.authController.setAuthState(AuthState.noLogged);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      harness.router.go('/services/svc-1');
      await tester.pumpAndSettle();

      expect(harness.location, AppRoutes.login);
      expect(harness.uri.queryParameters['from'], '/services/svc-1');
    },
  );

  testWidgets(
    'MoreScreen\'s "Хөдөлмөр" catalogue entry pushes /services seeded with '
    'the LABOR kind (D-164 drawer wiring)',
    (tester) async {
      Authenticator.user = signedInUser();
      addTearDown(() => Authenticator.user = null);
      FakeApiBackend.instance.onJson('GET', 'services', emptyServicePage());

      final harness = RouterHarness();
      addTearDown(harness.dispose);
      harness.authController.setAuthState(AuthState.authorized);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      harness.router.go(AppRoutes.more);
      await tester.pumpAndSettle();
      expect(find.byType(MoreScreen), findsOneWidget);

      // The Каталог group sits below the fold at the default test viewport
      // size — scroll it into view before tapping, same as any other
      // off-screen ListTile in this ListView.
      await tester.ensureVisible(find.text('Хөдөлмөр'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Хөдөлмөр'));
      await tester.pumpAndSettle();

      // `RouterHarness.location`/`.uri` read `currentConfiguration.uri`,
      // which (measured directly) does not reflect an imperatively `push`ed
      // route the way it reflects a `go()`-navigated one — every existing
      // router test in this file/`customers_vehicles_router_test.dart` only
      // exercises `go()`. The actually-rendered screen and the real
      // server-bound request are the two truths that matter for a push, and
      // both confirm the drawer entry worked: `ServiceListScreen` replaced
      // `MoreScreen`, and its controller's first fetch carried `type=LABOR`.
      expect(find.byType(MoreScreen), findsNothing);
      expect(find.byType(ServiceListScreen), findsOneWidget);
      final lastServicesRequest = FakeApiBackend.instance.requests.lastWhere(
        (r) => r.method == 'GET' && r.path.contains('services'),
      );
      expect(lastServicesRequest.queryParameters['type'], 'LABOR');
    },
  );

  testWidgets(
    'MoreScreen\'s "Бараа" catalogue entry pushes /services seeded with the '
    'GOODS kind, and Ангилал/Нэгж are gone (D-164)',
    (tester) async {
      Authenticator.user = signedInUser();
      addTearDown(() => Authenticator.user = null);
      FakeApiBackend.instance.onJson('GET', 'services', emptyServicePage());

      final harness = RouterHarness();
      addTearDown(harness.dispose);
      harness.authController.setAuthState(AuthState.authorized);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      harness.router.go(AppRoutes.more);
      await tester.pumpAndSettle();

      // D-164 — Units/Categories management is out of mobile scope; these
      // rows must not reappear in the Каталог group.
      expect(find.text('Ангилал'), findsNothing);
      expect(find.text('Нэгж'), findsNothing);

      await tester.ensureVisible(find.text('Бараа'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Бараа'));
      await tester.pumpAndSettle();

      expect(find.byType(MoreScreen), findsNothing);
      expect(find.byType(ServiceListScreen), findsOneWidget);
      final lastServicesRequest = FakeApiBackend.instance.requests.lastWhere(
        (r) => r.method == 'GET' && r.path.contains('services'),
      );
      expect(lastServicesRequest.queryParameters['type'], 'GOODS');
    },
  );
}
