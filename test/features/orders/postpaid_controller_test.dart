import 'dart:async';

import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/domain/diagnostic.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/domain/orders_repository.dart';
import 'package:carcare_service/features/orders/presentation/controllers/postpaid_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_order_repository.dart';

class _QueuedPostpaidRepository extends FakeOrderRepository {
  final requests = <PostpaidQuery>[];
  final pending = <Completer<Result<PostpaidPage>>>[];

  @override
  Future<Result<PostpaidPage>> getPostpaid({PostpaidQuery? query}) {
    final effective = query ?? const PostpaidQuery();
    requests.add(effective);
    final completer = Completer<Result<PostpaidPage>>();
    pending.add(completer);
    return completer.future;
  }
}

PostpaidPage _page(String orderId, {bool hasNext = false, int page = 1}) =>
    PostpaidPage(
      vehicles: const [],
      summary: const PostpaidSummary(
        orderCount: 0,
        totalAmountMoney: Money('0'),
        paidAmountMoney: Money('0'),
        balanceAmountMoney: Money('0'),
      ),
      orders: [
        ServiceOrderSummary(
          id: orderId,
          number: orderId,
          status: OrderStatus.COMPLETED,
          paymentStatus: PaymentStatus.PARTIAL,
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
          totalAmountMoney: const Money('100'),
          paidAmountMoney: const Money('50'),
          isPostpaid: true,
        ),
      ],
      pagination: PaginationMeta(
        page: page,
        pageSize: 25,
        total: hasNext ? 2 : 1,
        totalPages: hasNext ? 2 : 1,
        hasPrev: page > 1,
        hasNext: hasNext,
      ),
    );

void main() {
  test('branch reload is generation guarded and resets to page one', () async {
    final repository = _QueuedPostpaidRepository();
    final controller = PostpaidController(repo: repository);

    final oldLoad = controller.load();
    final newLoad = controller.setBranch('branch-2');
    expect(repository.requests.map((query) => query.page), [1, 1]);

    repository.pending[1].complete(Ok(_page('new')));
    await newLoad;
    repository.pending[0].complete(Ok(_page('old')));
    await oldLoad;

    expect(controller.orders.single.id, 'new');
    expect(controller.currentPage, 1);
    controller.dispose();
  });

  test('stale load more cannot overwrite a newer filtered reload', () async {
    final repository = _QueuedPostpaidRepository();
    final controller = PostpaidController(repo: repository);

    final initial = controller.load();
    repository.pending[0].complete(Ok(_page('initial', hasNext: true)));
    await initial;

    final more = controller.loadMore();
    final reload = controller.setPaymentStatus(PaymentStatus.PAID);
    expect(repository.requests[2].page, 1);
    repository.pending[2].complete(Ok(_page('filtered')));
    await reload;
    repository.pending[1].complete(Ok(_page('stale-more', page: 2)));
    await more;

    expect(controller.orders.single.id, 'filtered');
    expect(controller.loadingMore, isFalse);
    expect(controller.selectedPaymentStatus, PaymentStatus.PAID);
    controller.dispose();
  });

  test('date range is normalized and sent to the server query', () async {
    final repository = _QueuedPostpaidRepository();
    final controller = PostpaidController(repo: repository);

    final load = controller.setDateRange(
      DateTime(2026, 4, 3, 18),
      DateTime(2026, 4, 4, 22),
    );
    final query = repository.requests.single;
    expect(query.dateFrom, DateTime(2026, 4, 3));
    expect(query.dateTo, DateTime(2026, 4, 4));
    repository.pending.single.complete(Ok(_page('date')));
    await load;
    controller.dispose();
  });
}
