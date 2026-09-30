import 'dart:typed_data';

import 'package:carservice_business/app/router.dart';
import 'package:carservice_business/app/shell/app_shell.dart';
import 'package:carservice_business/features/feedback/presentation/screens/feedback_list_screen.dart';
import 'package:carservice_business/features/notifications/presentation/screens/notification_screen.dart';
import 'package:carservice_business/features/profile/presentation/screens/profile_screen.dart';
import 'package:carservice_business/features/settings/presentation/screens/about_screen.dart';
import 'package:carservice_business/features/settings/presentation/screens/help_screen.dart';
import 'package:carservice_business/core/domain/user.dart';
import 'package:carservice_business/core/navigation/app_nav.dart';
import 'package:carservice_business/core/services/auth_storage.dart';
import 'package:carservice_business/core/services/subscription_service.dart';
import 'package:carservice_business/features/controllers.dart';
import 'package:carservice_business/features/orders/presentation/screens/in_progress_screen.dart';
import 'package:carservice_business/features/today/presentation/screens/today_screen.dart';
import 'package:carservice_business/features/shell/presentation/screens/search_screen.dart';
import 'package:carservice_business/features/orders/presentation/screens/order_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
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
  // `AppShell` and `HomeScreen` read `Authenticator.user` directly
  // (a Hive-backed static) with no guard — see
  // `test/support/hive_test_setup.dart` for why this has to run in this
  // file's own `setUpAll` rather than `flutter_test_config.dart`.
  setUpAll(() async {
    await openTestHiveBoxes();
    // ProfileScreen watches ThemeProvider, which restores from this box.
    if (!Hive.isBoxOpen('settings')) {
      await Hive.openBox<String>('settings', bytes: Uint8List(0));
    }
  });

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
    // A real sign-in stores the user; SubscriptionService skips the API
    // while no user is stored.
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
      _seedOrder();
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

  testWidgets(
    'the order detail page opens by name full-screen above the tabs and '
    'back returns to the list',
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
      _seedOrder();
      final harness = RouterHarness();
      addTearDown(harness.dispose);
      harness.authController.setAuthState(AuthState.authorized);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      harness.router.go(AppRoutes.orders);
      await tester.pumpAndSettle();

      final result = AppNav.toNamed<void>(
        AppPages.orderDetail,
        arguments: 'order-1',
      );
      await tester.pumpAndSettle();

      // On the root navigator, above the shell and its bottom navigation;
      // the URL does not move.
      expect(find.text('#A-0001'), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.text('#A-0001'))),
        same(harness.router.routerDelegate.navigatorKey.currentState),
      );
      expect(find.byType(OrderListScreen), findsNothing);
      expect(harness.location, AppRoutes.orders);

      AppNav.back();
      await tester.pumpAndSettle();
      await result;
      expect(find.text('#A-0001'), findsNothing);
      expect(find.byType(OrderListScreen), findsOneWidget);
    },
  );

  testWidgets(
    'AppNav.go closes a full-screen named page so the new location shows',
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
      _seedOrder();
      final harness = RouterHarness();
      addTearDown(harness.dispose);
      harness.authController.setAuthState(AuthState.authorized);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      harness.router.go(AppRoutes.orders);
      await tester.pumpAndSettle();
      AppNav.toNamed<void>(AppPages.orderDetail, arguments: 'order-1');
      await tester.pumpAndSettle();
      expect(find.text('#A-0001'), findsOneWidget);

      // A notification tap, say: it must not land under the open page.
      AppNav.go(AppRoutes.ordersInProgress);
      await tester.pumpAndSettle();

      expect(find.text('#A-0001'), findsNothing);
      expect(find.byType(InProgressScreen), findsOneWidget);
      expect(harness.location, AppRoutes.ordersInProgress);
    },
  );

  testWidgets(
    'the Бусад profile card and Ерөнхий rows open full-screen named pages',
    (tester) async {
      Authenticator.user = User(
        accessToken: 'test-token',
        refreshToken: 'test-refresh',
        id: 'test-user',
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        phone: '',
        isOwner: true,
        role: null,
        tenant: UserTenant('test-tenant', 'Test tenant'),
      );
      addTearDown(() => Authenticator.user = null);
      FakeApiBackend.instance.onJson('GET', 'feedback', {
        'feedback': <dynamic>[],
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
      harness.router.go(AppRoutes.more);
      await tester.pumpAndSettle();

      final root = harness.router.routerDelegate.navigatorKey.currentState;
      final more = find.descendant(
        of: find.byType(MoreScreen),
        matching: find.byType(Scrollable),
      );
      for (final (label, page) in [
        (Authenticator.user!.fullName, ProfileScreen),
        ('Мэдэгдэл', NotificationScreen),
        ('Санал хүсэлт', FeedbackListScreen),
        ('Гарын авлага', HelpScreen),
        ('Тухай', AboutScreen),
      ]) {
        final row = find.descendant(
          of: find.byType(MoreScreen),
          matching: find.text(label),
        );
        await tester.scrollUntilVisible(row, 100, scrollable: more.first);
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();

        expect(find.byType(page), findsOneWidget, reason: label);
        expect(
          Navigator.of(tester.element(find.byType(page))),
          same(root),
          reason: '$label opens above the tabs',
        );
        expect(find.byType(MoreScreen), findsNothing, reason: label);
        expect(harness.location, AppRoutes.more);

        AppNav.back();
        await tester.pumpAndSettle();
        expect(find.byType(MoreScreen), findsOneWidget, reason: label);
      }
    },
  );
}

/// Serves `GET orders/order-1` from the fake backend.
void _seedOrder() {
  FakeApiBackend.instance.onJson('GET', 'orders/order-1', {
    'order': {
      'id': 'order-1',
      'number': 'A-0001',
      'status': 'SCHEDULED',
      'paymentStatus': 'UNPAID',
      'scheduledAt': '2026-01-10T09:00:00+08:00',
      'createdAt': '2026-01-09T09:00:00+08:00',
      'customer': {'id': 'customer-1', 'fullName': 'Customer', 'phone': '1'},
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
}
