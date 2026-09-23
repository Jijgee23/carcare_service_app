import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/presentation/screens/order_filter_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses only the canonical order statuses', () {
    expect(OrderStatus.values.map((status) => status.name), [
      'SCHEDULED',
      'IN_PROGRESS',
      'COMPLETED',
      'CANCELLED',
    ]);
    expect(
      OrderStatus.values.any((status) => status.name == 'WAITING_PARTS'),
      isFalse,
    );
  });

  test('IN_PROGRESS only offers completion or cancellation', () {
    expect(OrderStatus.IN_PROGRESS.nextStatuses, [
      OrderStatus.COMPLETED,
      OrderStatus.CANCELLED,
    ]);
  });

  test('the filter exposes only serializable canonical statuses', () {
    final filter = OrderFilter(statuses: OrderStatus.values.toSet());

    expect(filter.serverStatus, isNull);
    expect(
      OrderStatus.values.every((status) => status.name != 'WAITING_PARTS'),
      isTrue,
    );
  });
}
