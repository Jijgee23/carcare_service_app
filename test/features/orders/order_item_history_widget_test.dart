import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/presentation/controllers/order_detail_controller.dart';
import 'package:carcare_service/features/orders/presentation/controllers/order_item_controller.dart';
import 'package:carcare_service/features/orders/presentation/widgets/detail/order_item_widgets.dart';

import '../../fakes/fake_order_repository.dart';

void main() {
  testWidgets('history keeps loaded rows visible and exposes next-page retry', (
    tester,
  ) async {
    final repo = FakeOrderRepository();
    final detail = OrderDetailController(repo: repo);
    final controller = OrderItemController(
      repo: repo,
      orderId: 'order-1',
      detailController: detail,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ChangeNotifierProvider.value(
            value: controller,
            child: OrderItemHistorySheet(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();

    controller
      ..historyState = AsyncData(
        OrderItemHistoryPage(
          items: const [
            ServiceItem(
              id: 'cancelled-1',
              kind: ItemKind.LABOR,
              description: 'Oil service',
              quantity: 1,
              unitPrice: 10,
              total: 10,
              status: ServiceItemStatus.CANCELLED,
              cancelledById: 'user-1',
              quantityMoney: Money('1'),
              unitPriceMoney: Money('10'),
              totalMoney: Money('10'),
            ),
          ],
          pagination: const PaginationMeta(
            page: 1,
            pageSize: 1,
            total: 2,
            totalPages: 2,
            hasPrev: false,
            hasNext: true,
          ),
        ),
      )
      ..historyPage = 1
      ..historyHasNext = true
      ..historyNextError = 'Түүх ачаалж чадсангүй.';
    controller.notifyListeners();
    await tester.pump();

    expect(find.text('Oil service'), findsOneWidget);
    expect(find.text('Түүх ачаалж чадсангүй.'), findsOneWidget);
    expect(find.text('Дахин оролдох'), findsOneWidget);

    controller.dispose();
    detail.dispose();
  });
}
