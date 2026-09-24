import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/widgets/adaptive/adaptive.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child, {double width = 375}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: Size(width, 800)),
    child: SizedBox(
      width: width,
      height: 800,
      child: Scaffold(body: child),
    ),
  ),
);

List<AdaptiveNavigationDestination> _destinations() => const [
  AdaptiveNavigationDestination(label: 'Нүүр', icon: Icons.home_outlined),
  AdaptiveNavigationDestination(
    label: 'Захиалга',
    icon: Icons.receipt_long_outlined,
  ),
  AdaptiveNavigationDestination(label: 'Цаг', icon: Icons.event_outlined),
  AdaptiveNavigationDestination(label: 'Хайлт', icon: Icons.search_outlined),
  AdaptiveNavigationDestination(label: 'Бусад', icon: Icons.more_horiz_rounded),
];

void _setViewport(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test('breakpoints are strict at 600 and 840', () {
    expect(AdaptiveBreakpoints.ofWidth(599.99), AdaptiveSize.phone);
    expect(AdaptiveBreakpoints.ofWidth(600), AdaptiveSize.compactTablet);
    expect(AdaptiveBreakpoints.ofWidth(839.99), AdaptiveSize.compactTablet);
    expect(AdaptiveBreakpoints.ofWidth(840), AdaptiveSize.tablet);
  });

  testWidgets('375dp uses five-item bottom navigation', (tester) async {
    _setViewport(tester, 375);
    await tester.pumpWidget(
      _harness(
        AdaptiveScaffold(
          body: const Text('body'),
          destinations: _destinations(),
          selectedIndex: 0,
          onDestinationSelected: (_) {},
        ),
      ),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Бусад'), findsOneWidget);
  });

  testWidgets(
    'phone keeps branch and notification actions in persistent header',
    (tester) async {
      _setViewport(tester, 375);
      await tester.pumpWidget(
        _harness(
          AdaptiveScaffold(
            body: const Text('body'),
            destinations: _destinations(),
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            branchSwitcher: IconButton(
              tooltip: 'branch',
              onPressed: () {},
              icon: const Icon(Icons.store_outlined),
            ),
            notificationAction: IconButton(
              tooltip: 'notifications',
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ),
        ),
      );
      expect(find.byTooltip('branch'), findsOneWidget);
      expect(find.byTooltip('notifications'), findsOneWidget);
    },
  );

  testWidgets('700dp uses a collapsed navigation rail', (tester) async {
    _setViewport(tester, 700);
    await tester.pumpWidget(
      _harness(
        AdaptiveScaffold(
          body: const Text('body'),
          destinations: _destinations(),
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          branchSwitcher: IconButton(
            tooltip: 'branch-700',
            onPressed: () {},
            icon: const Icon(Icons.store_outlined),
          ),
          notificationAction: IconButton(
            tooltip: 'notifications-700',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ),
        width: 700,
      ),
    );
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isFalse,
    );
    expect(find.byTooltip('branch-700'), findsOneWidget);
    expect(find.byTooltip('notifications-700'), findsOneWidget);
  });

  testWidgets('1024dp uses a compact navigation rail', (tester) async {
    _setViewport(tester, 1024);
    await tester.pumpWidget(
      _harness(
        AdaptiveScaffold(
          body: const Text('body'),
          destinations: _destinations(),
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          branchSwitcher: IconButton(
            tooltip: 'branch-1024',
            onPressed: () {},
            icon: const Icon(Icons.store_outlined),
          ),
          notificationAction: IconButton(
            tooltip: 'notifications-1024',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ),
        width: 1024,
      ),
    );
    expect(find.byType(NavigationRail), findsOneWidget);
    // Tablet landscape keeps the compact rail so the work panes get room;
    // labels appear only from AdaptiveBreakpoints.extendedRail (1200dp).
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isFalse,
    );
    expect(find.byTooltip('branch-1024'), findsOneWidget);
    expect(find.byTooltip('notifications-1024'), findsOneWidget);
  });

  testWidgets('1280dp uses an extended rail with header actions', (
    tester,
  ) async {
    _setViewport(tester, 1280);
    await tester.pumpWidget(
      _harness(
        AdaptiveScaffold(
          body: const Text('body'),
          destinations: _destinations(),
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          leadingAction: IconButton(
            tooltip: 'menu-1280',
            onPressed: () {},
            icon: const Icon(Icons.menu_rounded),
          ),
          searchAction: IconButton(
            tooltip: 'search-1280',
            onPressed: () {},
            icon: const Icon(Icons.search_rounded),
          ),
        ),
        width: 1280,
      ),
    );
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );
    expect(find.byTooltip('menu-1280'), findsOneWidget);
    expect(find.byTooltip('search-1280'), findsOneWidget);
  });

  testWidgets('TwoPaneScaffold shows detail only at tablet width', (
    tester,
  ) async {
    Widget pane(double width) => _harness(
      TwoPaneScaffold<String>(
        list: const Text('list'),
        detail: const Text('detail'),
      ),
      width: width,
    );
    _setViewport(tester, 700);
    await tester.pumpWidget(pane(700));
    expect(find.text('list'), findsOneWidget);
    expect(find.text('detail'), findsNothing);
    tester.view.physicalSize = const Size(1024, 800);
    await tester.pumpWidget(pane(1024));
    expect(find.text('list'), findsOneWidget);
    expect(find.text('detail'), findsOneWidget);
  });

  testWidgets(
    'TwoPaneScaffold alwaysSplit:false keeps the list full width until a '
    'detail is selected',
    (tester) async {
      Widget pane({Widget? detail}) => _harness(
        TwoPaneScaffold<String>(
          alwaysSplit: false,
          list: const Text('list'),
          detail: detail,
        ),
        width: 1024,
      );
      _setViewport(tester, 1024);
      await tester.pumpWidget(pane());
      expect(find.text('list'), findsOneWidget);
      expect(find.text('detail'), findsNothing);

      await tester.pumpWidget(pane(detail: const Text('detail')));
      expect(find.text('list'), findsOneWidget);
      expect(find.text('detail'), findsOneWidget);
    },
  );

  testWidgets('AsyncStateView distinguishes empty and stale data', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        AsyncStateView<List<String>>(
          state: const AsyncData([]),
          isEmpty: (value) => value.isEmpty,
          builder: (_, value) => Text(value.join(',')),
          empty: const Text('empty'),
        ),
      ),
    );
    expect(find.text('empty'), findsOneWidget);

    await tester.pumpWidget(
      _harness(
        AsyncStateView<List<String>>(
          state: const AsyncData(['one']),
          stale: true,
          builder: (_, value) => Text(value.single),
        ),
      ),
    );
    expect(find.text('one'), findsOneWidget);
    expect(find.text('Шинэчлэгдээгүй мэдээлэл'), findsOneWidget);
  });

  test('canSeeView follows web permission semantics', () {
    User user({bool owner = false, List<String> permissions = const []}) =>
        User(
          accessToken: 'token',
          refreshToken: 'refresh',
          id: 'user',
          email: 'user@example.com',
          firstName: 'Test',
          lastName: 'User',
          phone: '',
          isOwner: owner,
          tenant: UserTenant('tenant', 'Tenant'),
          role: UserRole('role', 'Role', permissions),
        );

    expect(canSeeView(null, null), isTrue);
    expect(canSeeView(user(), null), isTrue);
    expect(canSeeView(user(owner: true), 'anything'), isTrue);
    expect(canSeeView(user(), 'owner'), isFalse);
    expect(canSeeView(user(permissions: ['orders.view']), 'orders'), isTrue);
    expect(canSeeView(user(permissions: ['audit.view']), 'audit'), isTrue);
    expect(
      canSeeView(user(permissions: ['orders.view']), 'orders.edit'),
      isFalse,
    );
    expect(
      canSeeView(user(permissions: ['orders.edit']), 'orders.edit'),
      isTrue,
    );
  });

  testWidgets('FilterSheet saves edited draft state', (tester) async {
    FilterState? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: FilterSheet(
          state: const FilterState(),
          definitions: [
            FilterDefinition(
              key: 'status',
              label: 'Төлөв',
              builder: (context, draft, onChanged) => TextButton(
                onPressed: () => onChanged('OPEN'),
                child: Text(draft['status']?.toString() ?? 'unset'),
              ),
            ),
          ],
          onChanged: (value) => saved = value,
        ),
      ),
    );
    await tester.tap(find.text('unset'));
    await tester.pump();
    expect(find.text('OPEN'), findsOneWidget);
    await tester.tap(find.text('Хадгалах'));
    expect(saved?['status'], 'OPEN');
  });
}
