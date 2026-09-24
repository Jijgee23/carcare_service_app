import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/domain/diagnostic.dart';
import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/domain/orders_repository.dart';
import 'package:carcare_service/features/orders/presentation/controllers/order_controller.dart';
import 'package:carcare_service/features/orders/presentation/screens/order_filter_sheet.dart'
    show DatePreset;
import 'package:carcare_service/features/orders/presentation/screens/order_list_screen.dart';
import 'package:carcare_service/features/orders/presentation/widgets/list/order_list_widgets.dart';

import '../../fakes/fake_order_repository.dart';
import '../../support/hive_test_setup.dart';

ServiceOrderDetail _secondOrder() => ServiceOrderDetail(
  id: 'order-2',
  number: 'A-0002',
  status: OrderStatus.SCHEDULED,
  paymentStatus: PaymentStatus.UNPAID,
  createdAt: DateTime(2026, 1, 2),
  customer: CustomerSummary(
    id: 'customer-2',
    fullName: 'Second Customer',
    phone: '99002233',
  ),
  vehicle: VehicleSummary(
    id: 'vehicle-2',
    plate: '5678DEF',
    make: 'Honda',
    model: 'Fit',
  ),
  branch: BranchSummary(id: 'branch-1', name: 'Branch'),
  items: [],
  reports: [],
);

User _user(List<String> permissions) => User(
  accessToken: 'token',
  refreshToken: 'refresh',
  id: 'user',
  email: 'user@example.test',
  firstName: 'Test',
  lastName: 'User',
  phone: '99001122',
  isOwner: false,
  role: UserRole('role', 'role', permissions),
  tenant: UserTenant('tenant', 'Tenant'),
);

Future<OrderController> _pump(
  WidgetTester tester,
  double width,
  User user, [
  FakeOrderRepository? repository,
]) async {
  Authenticator.user = user;
  tester.binding.window.physicalSizeTestValue = Size(width, 800);
  tester.binding.window.devicePixelRatioTestValue = 1;
  final repo = repository ?? FakeOrderRepository();
  final controller = OrderController(repo: repo);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Provider<OrdersRepository>.value(
        value: repo,
        child: ChangeNotifierProvider.value(
          value: controller,
          child: OrderListScreen(user: user),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  return controller;
}

class _PagedFakeRepository extends FakeOrderRepository {
  @override
  Future<Result<PagedResult<ServiceOrderSummary>>> getOrders({
    OrderListQuery? query,
    OrderStatus? status,
    String? vehicleId,
    String? customerId,
    String? branchId,
    String? assignedToId,
    PaymentStatus? paymentStatus,
    bool? postpaid,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? q,
    int page = 1,
    int pageSize = 25,
  }) async {
    final effective = query ?? const OrderListQuery();
    final result = await super.getOrders(query: effective);
    if (result case Ok(:final value)) {
      return Ok(
        PagedResult(
          items: value.items,
          pagination: PaginationMeta(
            page: effective.page,
            pageSize: effective.pageSize,
            total: 2,
            totalPages: 2,
            hasPrev: effective.page > 1,
            hasNext: effective.page == 1,
          ),
        ),
      );
    }
    return result;
  }
}

void main() {
  setUpAll(openTestHiveBoxes);

  tearDown(() {
    Authenticator.user = null;
    TestWidgetsFlutterBinding.ensureInitialized().window
        .clearPhysicalSizeTestValue();
    TestWidgetsFlutterBinding.ensureInitialized().window
        .clearDevicePixelRatioTestValue();
  });

  testWidgets('renders phone, tablet and wide tablet list layouts', (
    tester,
  ) async {
    for (final width in [375.0, 700.0, 1024.0]) {
      final controller = await _pump(
        tester,
        width,
        _user(const ['orders.view']),
      );
      expect(find.byType(OrderListScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('orders_in_progress_nav')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('orders_postpaid_nav')), findsOneWidget);
      expect(tester.takeException(), isNull);
      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
    'landscape keyboard neither overflows nor steals search focus',
    (tester) async {
      final controller = await _pump(
        tester,
        1280,
        _user(const ['orders.view']),
      );
      final search = find.byType(TextField).first;
      await tester.tap(search);
      await tester.pump();
      bool focused() =>
          tester.widget<EditableText>(
            find.descendant(of: search, matching: find.byType(EditableText)),
          ).focusNode.hasFocus;
      expect(focused(), isTrue);

      // The on-screen keyboard shrinks the body well below the controls'
      // natural height — the case that overflowed, then flickered.
      tester.view.viewInsets = const FakeViewPadding(bottom: 480);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(tester.takeException(), isNull);
      expect(focused(), isTrue);
      controller.dispose();
    },
  );

  testWidgets('viewOwn can see the list and create is distinct from edit', (
    tester,
  ) async {
    final controller = await _pump(
      tester,
      375,
      _user(const ['orders.viewOwn', 'orders.create']),
    );
    expect(find.byKey(const ValueKey('order_create_fab')), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.byKey(const ValueKey('bulk_status_button')), findsNothing);
    expect(find.byKey(const ValueKey('bulk_assign_button')), findsNothing);
    controller.dispose();
  });

  testWidgets('assignment and status bulk controls are independently gated', (
    tester,
  ) async {
    final assignOnly = await _pump(
      tester,
      1024,
      _user(const ['orders.view', 'orders.assign']),
    );
    await tester.tap(find.text('Энэ хуудсыг сонгох'));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(const ValueKey('bulk_assign_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('bulk_status_button')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('bulk_assign_button')));
    await tester.pump();
    expect(find.text('Fake User'), findsOneWidget);
    assignOnly.dispose();

    await tester.pumpWidget(const SizedBox.shrink());
    final editOnly = await _pump(
      tester,
      1024,
      _user(const ['orders.view', 'orders.edit']),
    );
    await tester.tap(find.text('Энэ хуудсыг сонгох'));
    await tester.pump();
    expect(find.byKey(const ValueKey('bulk_status_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('bulk_assign_button')), findsNothing);
    editOnly.dispose();
  });

  testWidgets('tablet list exposes an actionable load-more footer', (
    tester,
  ) async {
    final repository = _PagedFakeRepository();
    final controller = await _pump(
      tester,
      1024,
      _user(const ['orders.view']),
      repository,
    );
    expect(find.text('Дараагийн хуудас'), findsOneWidget);

    await tester.tap(find.text('Дараагийн хуудас'));
    await tester.pump();
    expect(controller.filtered, isNotEmpty);
    controller.dispose();
  });

  Future<OrderController> pumpWithRouter(
    WidgetTester tester,
    double width,
    User user, [
    FakeOrderRepository? repository,
  ]) async {
    Authenticator.user = user;
    tester.binding.window.physicalSizeTestValue = Size(width, 800);
    tester.binding.window.devicePixelRatioTestValue = 1;
    addTearDown(() {
      Authenticator.user = null;
      TestWidgetsFlutterBinding.ensureInitialized().window
          .clearPhysicalSizeTestValue();
      TestWidgetsFlutterBinding.ensureInitialized().window
          .clearDevicePixelRatioTestValue();
    });
    final repo = repository ?? FakeOrderRepository();
    final controller = OrderController(repo: repo);
    addTearDown(controller.dispose);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Provider<OrdersRepository>.value(
            value: repo,
            child: ChangeNotifierProvider.value(
              value: controller,
              child: OrderListScreen(user: user),
            ),
          ),
        ),
        GoRoute(
          path: '/orders/:id',
          builder: (context, state) => Scaffold(
            appBar: AppBar(
              title: Text('pushed-${state.pathParameters['id']}'),
            ),
            body: const SizedBox(),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    return controller;
  }

  testWidgets('tablet width pushes the order detail route', (tester) async {
    final repository = FakeOrderRepository(seedOrders: [_secondOrder()]);
    await pumpWithRouter(
      tester,
      1024,
      _user(const ['orders.view']),
      repository,
    );
    await tester.tap(find.text('1234ABC').first);
    await tester.pumpAndSettle();

    expect(find.text('pushed-order-1'), findsOneWidget);
    // The list is no longer on screen — this was a real route push, not a
    // side pane.
    expect(find.text('5678DEF'), findsNothing);
  });

  testWidgets(
    'the list is shown again (and reloaded) after popping back from the '
    'pushed detail route',
    (tester) async {
      final repository = FakeOrderRepository(seedOrders: [_secondOrder()]);
      await pumpWithRouter(
        tester,
        1024,
        _user(const ['orders.view']),
        repository,
      );

      await tester.tap(find.text('1234ABC').first);
      await tester.pumpAndSettle();
      expect(find.text('1234ABC'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('1234ABC'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('phone width pushes a route as well', (tester) async {
    final user = _user(const ['orders.view']);
    await pumpWithRouter(tester, 375, user);

    await tester.tap(find.text('#A-0001').first);
    await tester.pumpAndSettle();

    expect(find.text('pushed-order-1'), findsOneWidget);
  });

  group('quick filter chips (Phase 5)', () {
    testWidgets('hidden on phone, shown on tablet', (tester) async {
      await _pump(tester, 400, _user(const ['orders.view']));
      expect(
        find.byKey(const ValueKey('orders_quick_filter_today')),
        findsNothing,
      );

      await _pump(tester, 900, _user(const ['orders.view']));
      expect(
        find.byKey(const ValueKey('orders_quick_filter_today')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('orders_quick_filter_open')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('orders_quick_filter_unpaid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('orders_quick_filter_mine')),
        findsOneWidget,
      );
    });

    testWidgets('Өнөөдөр toggles the today date preset on and off', (
      tester,
    ) async {
      final controller = await _pump(tester, 900, _user(const ['orders.view']));

      await tester.tap(find.byKey(const ValueKey('orders_quick_filter_today')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(controller.filter.datePreset, DatePreset.today);

      await tester.tap(find.byKey(const ValueKey('orders_quick_filter_today')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(controller.filter.datePreset, DatePreset.all);
    });

    testWidgets('Нээлттэй and Төлбөр дутуу combine independently', (
      tester,
    ) async {
      final controller = await _pump(tester, 900, _user(const ['orders.view']));

      await tester.tap(find.byKey(const ValueKey('orders_quick_filter_open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(controller.filter.statuses, {
        OrderStatus.SCHEDULED,
        OrderStatus.IN_PROGRESS,
      });

      await tester.tap(
        find.byKey(const ValueKey('orders_quick_filter_unpaid')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(controller.filter.paymentStatuses, {PaymentStatus.UNPAID});
      // The earlier "open" toggle is preserved.
      expect(controller.filter.statuses, {
        OrderStatus.SCHEDULED,
        OrderStatus.IN_PROGRESS,
      });
    });

    testWidgets('Миний filters by the signed-in user id', (tester) async {
      final user = _user(const ['orders.view']);
      final controller = await _pump(tester, 900, user);

      await tester.tap(find.byKey(const ValueKey('orders_quick_filter_mine')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(controller.filter.assignedToId, user.id);
    });
  });

  group('all-orders tablet table (Phase 5 remainder)', () {
    testWidgets('tapping a column header sorts the loaded page client-side', (
      tester,
    ) async {
      final repository = FakeOrderRepository(seedOrders: [_secondOrder()]);
      final controller = await _pump(
        tester,
        1024,
        _user(const ['orders.view']),
        repository,
      );

      List<String> platesInOrder() =>
          tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .whereType<String>()
              .where((s) => s == '1234ABC' || s == '5678DEF')
              .toList();

      // Seeded second-then-first insertion order: A-0001/1234ABC precedes
      // A-0002/5678DEF from the fake repository's default ordering.
      expect(platesInOrder(), ['1234ABC', '5678DEF']);

      // The "Дугаар" (plate) column header is index 1 (index 0 is the
      // selection checkbox column, which never sorts).
      await tester.tap(find.text('Дугаар'));
      await tester.pump();
      expect(platesInOrder(), ['1234ABC', '5678DEF']);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

      // Tapping the same header again reverses the order.
      await tester.tap(find.text('Дугаар'));
      await tester.pump();
      expect(platesInOrder(), ['5678DEF', '1234ABC']);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);

      controller.dispose();
    });

    testWidgets(
      'persistent filter panel shows at >=1200dp and not below it',
      (tester) async {
        final below = await _pump(tester, 1024, _user(const ['orders.view']));
        expect(
          find.byKey(const ValueKey('order_filter_panel')),
          findsNothing,
        );
        below.dispose();
        await tester.pumpWidget(const SizedBox.shrink());

        final atThreshold = await _pump(
          tester,
          1200,
          _user(const ['orders.view']),
        );
        expect(
          find.byKey(const ValueKey('order_filter_panel')),
          findsOneWidget,
        );
        atThreshold.dispose();
      },
    );

    testWidgets('the persistent panel applies a filter immediately', (
      tester,
    ) async {
      final controller = await _pump(tester, 1280, _user(const ['orders.view']));

      await tester.tap(find.text('Товлогдсон').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(controller.filter.statuses, {OrderStatus.SCHEDULED});
      controller.dispose();
    });
  });

  group('large text (Phase 6)', () {
    Future<void> pumpScaled(
      WidgetTester tester,
      double width,
      double scale,
    ) async {
      Authenticator.user = _user(const ['orders.view']);
      tester.binding.window.physicalSizeTestValue = Size(width, 900);
      tester.binding.window.devicePixelRatioTestValue = 1;
      final repo = FakeOrderRepository(seedOrders: [_secondOrder()]);
      final controller = OrderController(repo: repo);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Provider<OrdersRepository>.value(
            value: repo,
            child: ChangeNotifierProvider.value(
              value: controller,
              child: OrderListScreen(user: Authenticator.user),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
    }

    testWidgets('2.0x on phone width renders without overflow', (
      tester,
    ) async {
      await pumpScaled(tester, 400, 2.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2.0x on the tablet table renders without overflow', (
      tester,
    ) async {
      await pumpScaled(tester, 1024, 2.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '2.0x with the persistent filter panel (>=1200dp) renders without overflow',
      (tester) async {
        await pumpScaled(tester, 1280, 2.0);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
