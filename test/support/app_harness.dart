import 'package:carcare_service/app/app.dart';
import 'package:carcare_service/app/router.dart';
import 'package:carcare_service/features/controllers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Wraps the REAL `buildRouter()` + `AppShell` (`lib/app/router.dart`) the
/// same way `Carcare` (`lib/app/app.dart`) wires them, minus the one-time
/// app bootstrap `Carcare`'s `initState` performs
/// (`_authController.loadUser()`, which reads Hive/`Authenticator` to decide
/// the starting auth state). A test drives [authController] directly via
/// `setAuthState(...)` instead — everything else (the provider list, the
/// router construction, `refreshListenable`) is exactly what production
/// uses, via the same `Configs.providers(...)` function `Carcare` calls, so
/// nothing a screen depends on (ThemeProvider, InspectionController,
/// BottomNavController) is missing from the tree.
///
/// This harness does NOT fake any network dependency — `FakeApiBackend`
/// (installed globally by `flutter_test_config.dart`) already makes
/// unscripted requests fail fast and safely; script specific endpoints from
/// the test itself when an assertion depends on the parsed result (e.g. a
/// locked subscription).
class RouterHarness {
  factory RouterHarness({AuthController? authController}) {
    final auth = authController ?? AuthController();
    return RouterHarness._(auth, buildRouter(auth));
  }

  RouterHarness._(this.authController, this.router);

  final AuthController authController;
  final GoRouter router;

  Widget build() {
    return MultiProvider(
      providers: Configs.providers(authController),
      child: MaterialApp.router(routerConfig: router),
    );
  }

  /// The path GoRouter currently believes it is showing — e.g. `/login`,
  /// `/overview`. Ignores the query string, which the tests that care about
  /// `?from=` assert on separately via [uri].
  String get location => router.routerDelegate.currentConfiguration.uri.path;

  Uri get uri => router.routerDelegate.currentConfiguration.uri;

  void dispose() {
    router.dispose();
    authController.dispose();
  }
}
