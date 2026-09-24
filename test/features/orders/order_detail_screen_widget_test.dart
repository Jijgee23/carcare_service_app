import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/presentation/controllers/order_controller.dart';
import 'package:carcare_service/features/orders/presentation/controllers/order_detail_controller.dart';
import 'package:carcare_service/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:carcare_service/features/orders/presentation/widgets/detail/order_detail_widgets.dart';

import '../../fakes/fake_order_repository.dart';

class _RefreshFailingRepository extends FakeOrderRepository {
  var detailRequests = 0;

  @override
  Future<Result<ServiceOrderDetail>> getOrderDetail(String id) async {
    detailRequests++;
    if (detailRequests > 1) {
      return const Err(AppError(ErrorKind.server, 'Detail refresh failed'));
    }
    return super.getOrderDetail(id);
  }
}

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

Future<OrderDetailController> _pump(
  WidgetTester tester,
  double width,
  User user, {
  FakeOrderRepository? repository,
}) async {
  tester.binding.window.physicalSizeTestValue = Size(width, 800);
  tester.binding.window.devicePixelRatioTestValue = 1;
  final repo = repository ?? FakeOrderRepository();
  final detail = OrderDetailController(repo: repo);
  final legacy = OrderController(repo: repo);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: detail),
          ChangeNotifierProvider.value(value: legacy),
        ],
        child: OrderDetailScreen(orderId: 'order-1', user: user),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  addTearDown(() {
    detail.dispose();
    legacy.dispose();
  });
  return detail;
}

void main() {
  test('clamps overdue and future date picker initial values', () {
    final first = DateTime(2026, 9, 20);
    final last = DateTime(2026, 10, 20);
    expect(
      clampOrderDatePickerInitial(
        DateTime(2026, 1, 1),
        firstDate: first,
        lastDate: last,
      ),
      first,
    );
    expect(
      clampOrderDatePickerInitial(
        DateTime(2027, 1, 1),
        firstDate: first,
        lastDate: last,
      ),
      last,
    );
    expect(
      clampOrderDatePickerInitial(
        DateTime(2026, 10, 1, 17, 30),
        firstDate: first,
        lastDate: last,
      ),
      DateTime(2026, 10, 1),
    );
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().window
        .clearPhysicalSizeTestValue();
    TestWidgetsFlutterBinding.ensureInitialized().window
        .clearDevicePixelRatioTestValue();
  });

  testWidgets('detail builds without overflow at phone and expanded widths', (
    tester,
  ) async {
    for (final width in [375.0, 700.0, 1024.0]) {
      await _pump(
        tester,
        width,
        _user(const [
          'orders.view',
          'orders.edit',
          'orders.assign',
          'payments.view',
        ]),
      );
      expect(find.byType(OrderDetailSummaryCard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('controls are hidden when the user lacks mutation permissions', (
    tester,
  ) async {
    await _pump(tester, 375, _user(const ['orders.view']));
    expect(
      find.byKey(const ValueKey('order_status_IN_PROGRESS')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('order_assignment_picker')), findsNothing);
    expect(find.byKey(const ValueKey('order_detail_delete')), findsNothing);
    expect(find.byKey(const ValueKey('order_reschedule_button')), findsNothing);
    expect(find.byKey(const ValueKey('order_payment_entry')), findsNothing);
  });

  testWidgets('view permission remains the route visibility gate', (
    tester,
  ) async {
    await _pump(tester, 375, _user(const []));
    expect(find.text('Захиалга харах эрхгүй'), findsOneWidget);
  });

  testWidgets(
    'successful status update keeps detail visible when reconciliation fails',
    (tester) async {
      final repo = _RefreshFailingRepository();
      final controller = await _pump(
        tester,
        375,
        _user(const ['orders.view', 'orders.edit']),
        repository: repo,
      );

      final result = await controller.updateStatus(OrderStatus.IN_PROGRESS);
      await tester.pump();

      expect(result, isA<Ok<ServiceOrderDetail>>());
      expect(find.byType(OrderDetailSummaryCard), findsOneWidget);
      expect(
        find.byKey(const ValueKey('order_detail_refresh_warning')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('order_detail_refresh_retry')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('start-duration dialog cancel and continue keep detail stable', (
    tester,
  ) async {
    await _pump(tester, 375, _user(const ['orders.view', 'orders.edit']));

    await tester.tap(find.byKey(const ValueKey('order_status_IN_PROGRESS')));
    await tester.pumpAndSettle();
    expect(find.text('Ажлын үргэлжлэх хугацаа'), findsOneWidget);

    await tester.tap(find.text('Болих'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailSummaryCard), findsOneWidget);
    expect(find.text('Мэдээлэл олдсонгүй'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('order_status_IN_PROGRESS')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Үргэлжлүүлэх'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailSummaryCard), findsOneWidget);
    expect(find.text('Мэдээлэл олдсонгүй'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('single layout (no embedded/side-pane mode)', () {
    testWidgets('shows the order number once, in the app bar', (
      tester,
    ) async {
      await _pump(
        tester,
        1024,
        _user(const ['orders.view', 'orders.delete']),
      );

      // App bar shows "#<number>" once.
      expect(find.text('#A-0001'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'delete stays inline on the summary card, with confirmation',
      (tester) async {
        await _pump(
          tester,
          1024,
          _user(const ['orders.view', 'orders.delete']),
        );

        await tester.tap(find.byKey(const ValueKey('order_detail_delete')));
        await tester.pumpAndSettle();

        expect(find.text('Захиалгыг устгах уу?'), findsOneWidget);
      },
    );

    testWidgets('hides delete when the user cannot delete', (tester) async {
      await _pump(tester, 1024, _user(const ['orders.view']));

      expect(find.byKey(const ValueKey('order_detail_delete')), findsNothing);
    });
  });
}
