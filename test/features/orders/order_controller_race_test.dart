import 'dart:async';

import 'package:carcare_service/core/domain/diagnostic.dart';
import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/orders/data/order_repository.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/domain/orders_repository.dart';
import 'package:carcare_service/features/orders/presentation/controllers/order_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _QueuedOrders extends OrderRepository {
  final requests = <String?>[];
  final pending = <Completer<Result<PagedResult<ServiceOrderSummary>>>>[];

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
  }) {
    requests.add(branchId);
    final result = Completer<Result<PagedResult<ServiceOrderSummary>>>();
    pending.add(result);
    return result.future;
  }
}

ServiceOrderSummary _order(String id) => ServiceOrderSummary(
  id: id,
  number: id,
  status: OrderStatus.SCHEDULED,
  paymentStatus: PaymentStatus.UNPAID,
  createdAt: DateTime(2026),
  customer: const CustomerSummary(
    id: 'customer',
    fullName: 'Customer',
    phone: '1',
  ),
  vehicle: const VehicleSummary(
    id: 'vehicle',
    plate: '1',
    make: 'Make',
    model: 'Model',
  ),
  branch: const BranchSummary(id: 'branch', name: 'Branch'),
);

Result<PagedResult<ServiceOrderSummary>> _page(
  String id, {
  bool hasNext = false,
  int page = 1,
}) => Ok(
  PagedResult(
    items: [_order(id)],
    pagination: PaginationMeta(
      page: page,
      pageSize: 25,
      total: 1,
      totalPages: hasNext ? 2 : 1,
      hasPrev: page > 1,
      hasNext: hasNext,
    ),
  ),
);

void main() {
  test(
    'branch change sends null legacy query and old list response cannot win',
    () async {
      final repository = _QueuedOrders();
      final controller = OrderController(repo: repository);

      controller.selectedBranchId = 'stale-branch';
      final oldLoad = controller.loadOrders();
      final newLoad = controller.setBranch(null);
      expect(repository.requests, ['stale-branch', null]);

      repository.pending[1].complete(_page('new'));
      await newLoad;
      repository.pending[0].complete(_page('old'));
      await oldLoad;

      expect(controller.listState.valueOrNull!.single.id, 'new');
      controller.dispose();
    },
  );

  test('stale loadMore is a no-op after a newer list load', () async {
    final repository = _QueuedOrders();
    final controller = OrderController(repo: repository);

    final initial = controller.loadOrders();
    repository.pending[0].complete(_page('initial', hasNext: true));
    await initial;

    final more = controller.loadMore();
    final reload = controller.loadOrders();
    repository.pending[2].complete(_page('reload'));
    await reload;
    repository.pending[1].complete(_page('stale-more', page: 2));
    await more;

    expect(controller.listState.valueOrNull!.map((item) => item.id), [
      'reload',
    ]);
    expect(controller.loadingMore, isFalse);
    controller.dispose();
  });
}
