import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets(
    'expanded list selects a detail pane instead of pushing a route',
    (tester) async {
      final repository = FakeOrderRepository(seedOrders: [_secondOrder()]);
      final controller = await _pump(
        tester,
        1024,
        _user(const ['orders.view']),
        repository,
      );
      await tester.tap(find.text('#A-0001').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('order_detail_number')), findsOneWidget);
      expect(find.text('#A-0001'), findsWidgets);

      await tester.tap(find.text('#A-0002').first);
      await tester.pumpAndSettle();
      expect(find.text('#A-0002'), findsWidgets);
      controller.dispose();
    },
  );
}
