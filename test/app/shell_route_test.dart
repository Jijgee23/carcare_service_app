import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// Proves the specific reason P0-F2 adopted go_router: a plain `ShellRoute`
// resets each tab's navigation stack when you switch away and back;
// `StatefulShellRoute.indexedStack` (as wired up in lib/app/router.dart) must
// not. This uses a minimal two-branch router rather than the production one
// in lib/app/router.dart, because the real router's branches are gated by
// AuthController/SubscriptionService/Hive/Firebase — wiring all of that just
// to exercise the shell mechanism is test-infrastructure work owned by
// P0-F4, not this slice. What's under test here is the exact same
// `StatefulShellRoute.indexedStack` + `navigationShell.goBranch` API that
// lib/app/router.dart's `AppShell` uses.
void main() {
  testWidgets(
    'StatefulShellRoute.indexedStack keeps a pushed route on one destination '
    'after switching to another destination and back',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/a',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) => _TestShell(navigationShell: navigationShell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/a',
                    builder: (context, state) => _RootScreen(
                      label: 'A root',
                      onPush: () => context.push('/a/detail'),
                    ),
                    routes: [
                      GoRoute(path: 'detail', builder: (context, state) => const _DetailScreen()),
                    ],
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(path: '/b', builder: (context, state) => const _RootScreen(label: 'B root')),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Start on destination A, at its root.
      expect(find.text('A root'), findsOneWidget);

      // Push a route within destination A's own stack.
      await tester.tap(find.byKey(const ValueKey('push-detail')));
      await tester.pumpAndSettle();
      expect(find.text('A detail'), findsOneWidget);

      // Switch to destination B.
      await tester.tap(find.byKey(const ValueKey('nav-b')));
      await tester.pumpAndSettle();
      expect(find.text('B root'), findsOneWidget);

      // Switch back to destination A: the pushed route must still be on
      // top, not reset to A's root. This is the behavior a plain ShellRoute
      // does not provide.
      await tester.tap(find.byKey(const ValueKey('nav-a')));
      await tester.pumpAndSettle();
      expect(find.text('A detail'), findsOneWidget);
    },
  );
}

class _TestShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const _TestShell({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Row(
        children: [
          IconButton(
            key: const ValueKey('nav-a'),
            icon: const Icon(Icons.looks_one),
            onPressed: () => navigationShell.goBranch(0),
          ),
          IconButton(
            key: const ValueKey('nav-b'),
            icon: const Icon(Icons.looks_two),
            onPressed: () => navigationShell.goBranch(1),
          ),
        ],
      ),
    );
  }
}

class _RootScreen extends StatelessWidget {
  final String label;
  final VoidCallback? onPush;
  const _RootScreen({required this.label, this.onPush});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (onPush != null)
              TextButton(
                key: const ValueKey('push-detail'),
                onPressed: onPush,
                child: const Text('Push detail'),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailScreen extends StatelessWidget {
  const _DetailScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('A detail')));
  }
}
