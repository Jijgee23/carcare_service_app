import 'package:carcare_service/app/router.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/services/subscription_service.dart';
import 'package:carcare_service/features/controllers.dart';
import 'package:carcare_service/features/orders/presentation/screens/in_progress_screen.dart';
import 'package:carcare_service/features/today/presentation/screens/today_screen.dart';
import 'package:carcare_service/features/shell/presentation/screens/search_screen.dart';
import 'package:carcare_service/features/orders/presentation/screens/order_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../fakes/fake_api_backend.dart';
import '../support/app_harness.dart';
import '../support/hive_test_setup.dart';

/// Exercises the REAL `buildRouter(...)` / `AppShell` from
/// `lib/app/router.dart` — unlike `shell_route_test.dart` (P0-F2), which
/// deliberately builds a minimal replica of `StatefulShellRoute.indexedStack`
/// and never imports `lib/app/router.dart` at all. That test proves go_router
/// works; it proves nothing about this app's wiring — the redirect guard,
/// the provider tree the real screens depend on, or that a signed-in user
/// actually reaches the shell. This file closes that gap.
///
/// `SubscriptionService` and `ApiService` are true process-wide singletons
/// with no constructor-injection seam (see the P0-F4 report), so every test
/// resets them — otherwise a locked/unlocked result cached by one test would
/// leak into the next test in this file.
void main() {
  // `AppShell`'s drawer and `HomeScreen` read `Authenticator.user` directly
  // (a Hive-backed static) with no guard — see
  // `test/support/hive_test_setup.dart` for why this has to run in this
  // file's own `setUpAll` rather than `flutter_test_config.dart`.
  setUpAll(openTestHiveBoxes);

  setUp(() {
    FakeApiBackend.instance.reset();
    SubscriptionService.instance.invalidate();
  });

  testWidgets('redirects a signed-out user to /login', (tester) async {
    final harness = RouterHarness();
    addTearDown(harness.dispose);
    harness.authController.setAuthState(AuthState.noLogged);

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();

    expect(harness.location, AppRoutes.login);
    expect(find.text('Гарах'), findsNothing); // sanity: not the shell/drawer
  });

  testWidgets('preserves the intended destination through a login redirect and '
      'resumes it after sign-in', (tester) async {
    final harness = RouterHarness();
    addTearDown(harness.dispose);
    harness.authController.setAuthState(AuthState.noLogged);

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    expect(harness.location, AppRoutes.login); // baseline redirect from splash

    // The user (or a deep link) tries to reach a destination while signed
    // out — must be bounced to /login with the destination preserved.
    harness.router.go(AppRoutes.more);
    await tester.pumpAndSettle();
    expect(harness.location, AppRoutes.login);
    expect(harness.uri.queryParameters['from'], AppRoutes.more);

    // Signing in must resume exactly that destination, not the default
    // Overview landing.
    harness.authController.setAuthState(AuthState.authorized);
    await tester.pumpAndSettle();

    expect(harness.location, AppRoutes.more);
  });

  testWidgets('sends a subscription-locked signed-in user to /locked', (
    tester,
  ) async {
    FakeApiBackend.instance.onJson('GET', 'subscription', {
      'locked': true,
      'status': 'expired',
    });
    final harness = RouterHarness();
    addTearDown(harness.dispose);
    harness.authController.setAuthState(AuthState.authorized);

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();

    expect(harness.location, AppRoutes.locked);
    expect(find.text('Захиалга идэвхгүй байна'), findsOneWidget);
  });

  testWidgets(
    'an unlocked signed-in user reaches the shell instead of /locked',
    (tester) async {
      // No script for `subscription` — FakeApiBackend's default-deny
      // (connectionError) is exactly equivalent to `SubscriptionService`
      // failing open: `getStatus()` returns null, `status?.locked == true`
      // is false, so the guard does not block the shell. This is the same
      // best-effort behaviour the real service already documents.
      final harness = RouterHarness();
      addTearDown(harness.dispose);
      harness.authController.setAuthState(AuthState.authorized);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      expect(harness.location, AppRoutes.overview);
      expect(find.text('Захиалга идэвхгүй байна'), findsNothing);
    },
  );

  testWidgets('a destination keeps its own state after switching away and back '
      '(StatefulShellRoute.indexedStack, on the production AppShell)', (
    tester,
  ) async {
    final harness = RouterHarness();
    addTearDown(harness.dispose);
    // The production shell permission-gates Search. This test drives the
    // auth controller directly, so seed the same signed-in identity that a
    // real login would have placed in Authenticator before testing branch
    // state retention.
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
    addTearDown(() => Authenticator.user = null);
    harness.authController.setAuthState(AuthState.authorized);

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    expect(harness.location, AppRoutes.overview);

    // Capture the Today (home) branch's State object before leaving it.
    final homeState = tester.state(find.byType(TodayScreen));

    // Switch to another destination...
    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pumpAndSettle();
    expect(harness.location, AppRoutes.more);

    // ...and back. A plain `ShellRoute` would have disposed and rebuilt
    // the Home branch; the production AppShell is wired on
    // `StatefulShellRoute.indexedStack` specifically so it does not.
    await tester.tap(find.byIcon(Icons.today_outlined).first);
    await tester.pumpAndSettle();

    expect(harness.location, AppRoutes.overview);
    expect(tester.state(find.byType(TodayScreen)), same(homeState));
  });

  testWidgets('search is a top-bar action that opens above the shell', (
    tester,
  ) async {
    final harness = RouterHarness();
    addTearDown(harness.dispose);
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
    addTearDown(() => Authenticator.user = null);
    harness.authController.setAuthState(AuthState.authorized);

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Хайлт'), findsOneWidget);
    await tester.tap(find.byTooltip('Хайлт'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
  });

  testWidgets('orders child routes are reachable and isolate list state', (
    tester,
  ) async {
    Authenticator.user = User(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      id: 'test-user',
      email: 'test@example.com',
      firstName: 'Test',
      lastName: 'User',
      phone: '',
      isOwner: false,
      role: UserRole('test-role', 'Test role', const ['orders.viewOwn']),
      tenant: UserTenant('test-tenant', 'Test tenant'),
    );
    addTearDown(() => Authenticator.user = null);

    final harness = RouterHarness();
    addTearDown(harness.dispose);
    harness.authController.setAuthState(AuthState.authorized);

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();

    harness.router.go(AppRoutes.orders);
    await tester.pumpAndSettle();
    final mainList = Provider.of<OrderController>(
      tester.element(find.byType(OrderListScreen)),
      listen: false,
    );

    harness.router.go(AppRoutes.ordersInProgress);
    await tester.pumpAndSettle();
    expect(harness.location, AppRoutes.ordersInProgress);
    expect(find.byType(InProgressScreen), findsOneWidget);
    final progress = Provider.of<OrderController>(
      tester.element(find.byType(InProgressScreen)),
      listen: false,
    );
    expect(identical(progress, mainList), isFalse);

    harness.router.go(AppRoutes.ordersPostpaid);
    await tester.pumpAndSettle();
    expect(harness.location, AppRoutes.ordersPostpaid);
    expect(find.text('Төлбөрийн үлдэгдэл'), findsOneWidget);
  });

  testWidgets(
    'direct order deep link opens detail and back returns to orders',
    (tester) async {
      Authenticator.user = User(
        accessToken: 'test-token',
        refreshToken: 'test-refresh',
        id: 'test-user',
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        phone: '',
        isOwner: false,
        role: UserRole('test-role', 'Test role', const ['orders.view']),
        tenant: UserTenant('test-tenant', 'Test tenant'),
      );
      addTearDown(() => Authenticator.user = null);
      FakeApiBackend.instance.onJson('GET', 'orders/order-1', {
        'order': {
          'id': 'order-1',
          'number': 'A-0001',
          'status': 'SCHEDULED',
          'paymentStatus': 'UNPAID',
          'scheduledAt': '2026-01-10T09:00:00+08:00',
          'createdAt': '2026-01-09T09:00:00+08:00',
          'customer': {
            'id': 'customer-1',
            'fullName': 'Customer',
            'phone': '1',
          },
          'vehicle': {
            'id': 'vehicle-1',
            'plate': '1234ABC',
            'make': 'Toyota',
            'model': 'Prius',
          },
          'branch': {'id': 'branch-1', 'name': 'Branch'},
          'items': <dynamic>[],
          'reports': <dynamic>[],
        },
      });
      final harness = RouterHarness();
      addTearDown(harness.dispose);
      harness.authController.setAuthState(AuthState.authorized);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      harness.router.go('/orders/order-1');
      await tester.pumpAndSettle();

      expect(harness.location, '/orders/order-1');
      expect(find.text('#A-0001'), findsOneWidget);
      harness.router.pop();
      await tester.pumpAndSettle();
      expect(harness.location, AppRoutes.orders);
    },
  );
}
