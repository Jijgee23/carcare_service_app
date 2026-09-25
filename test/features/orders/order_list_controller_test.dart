import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/domain/diagnostic.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/orders/data/order_repository.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/domain/orders_repository.dart';
import 'package:carcare_service/features/orders/presentation/controllers/order_list_controller.dart';
import 'package:carcare_service/features/orders/presentation/screens/order_filter_sheet.dart';

class _QueueRepository extends OrderRepository {
  final requests = <OrderListQuery>[];
  final responses = <Completer<Result<PagedResult<ServiceOrderSummary>>>>[];
  BulkOrderResult? nextBulkResult;
  List<String>? lastBulkIds;
  OrderStatus? lastBulkStatus;
  int? lastDurationMinutes;
  final assignableBranches = <String?>[];
  final assignableResponses = <Completer<Result<List<AssignableUser>>>>[];
  Future<Result<BulkOrderResult>>? bulkAssignResponse;

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
    final effective =
        query ??
        OrderListQuery(
          status: status,
          vehicleId: vehicleId,
          customerId: customerId,
          branchId: branchId,
          assignedToId: assignedToId,
          paymentStatus: paymentStatus,
          postpaid: postpaid,
          dateFrom: dateFrom,
          dateTo: dateTo,
          q: q,
          page: page,
          pageSize: pageSize,
        );
    requests.add(effective);
    final completer = Completer<Result<PagedResult<ServiceOrderSummary>>>();
    responses.add(completer);
    return completer.future;
  }

  @override
  Future<Result<BulkOrderResult>> bulkChangeStatus(
    List<String> orderIds,
    OrderStatus status, {
    int? durationMinutes,
  }) async {
    lastBulkIds = [...orderIds];
    lastBulkStatus = status;
    lastDurationMinutes = durationMinutes;
    return Ok(
      nextBulkResult ?? BulkOrderResult(succeeded: orderIds, failed: const []),
    );
  }

  @override
  Future<Result<BulkOrderResult>> bulkAssign(
    List<String> orderIds,
    String? assignedToId,
  ) async {
    lastBulkIds = [...orderIds];
    if (bulkAssignResponse != null) return bulkAssignResponse!;
    return Ok(
      nextBulkResult ?? BulkOrderResult(succeeded: orderIds, failed: const []),
    );
  }

  @override
  Future<Result<List<AssignableUser>>> getAssignableUsers({String? branchId}) {
    assignableBranches.add(branchId);
    final completer = Completer<Result<List<AssignableUser>>>();
    assignableResponses.add(completer);
    return completer.future;
  }
}

ServiceOrderSummary _order(String id) => ServiceOrderSummary(
  id: id,
  number: id,
  status: OrderStatus.SCHEDULED,
  paymentStatus: PaymentStatus.UNPAID,
  createdAt: DateTime(2026, 1, 1),
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
  int page = 1,
  bool hasNext = false,
}) => Ok(
  PagedResult(
    items: [_order(id)],
    pagination: PaginationMeta(
      page: page,
      pageSize: 25,
      total: hasNext ? 2 : 1,
      totalPages: hasNext ? 2 : 1,
      hasPrev: page > 1,
      hasNext: hasNext,
    ),
  ),
);

Future<void> _waitForResponse(_QueueRepository repo, int index) async {
  for (
    var attempt = 0;
    attempt < 10 && repo.responses.length <= index;
    attempt++
  ) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'maps all active filters to the server and never filters a page locally',
    () async {
      final repo = _QueueRepository();
      final controller = OrderListController(repo: repo);
      controller.setFilter(
        OrderFilter(
          statuses: const {OrderStatus.IN_PROGRESS},
          paymentStatuses: const {PaymentStatus.PARTIAL},
          assignedToId: 'assignee',
          plate: '1234УБ',
          postpaid: true,
          dateFrom: DateTime(2026, 2, 3),
          dateTo: DateTime(2026, 2, 4),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(repo.requests.single.status, OrderStatus.IN_PROGRESS);
      expect(repo.requests.single.paymentStatus, PaymentStatus.PARTIAL);
      expect(repo.requests.single.assignedToId, 'assignee');
      expect(repo.requests.single.plate, '1234УБ');
      expect(repo.requests.single.postpaid, isTrue);
      expect(repo.requests.single.dateFrom, DateTime(2026, 2, 3));
      expect(repo.requests.single.dateTo, DateTime(2026, 2, 4));
      repo.responses.single.complete(_page('one'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.filtered.single.id, 'one');
      controller.dispose();
    },
  );

  test('debounces encoded search and preserves filters on load more', () async {
    final repo = _QueueRepository();
    final controller = OrderListController(repo: repo);
    controller.setFilter(const OrderFilter(statuses: {OrderStatus.COMPLETED}));
    await Future<void>.delayed(Duration.zero);
    repo.responses[0].complete(_page('first', hasNext: true));
    await Future<void>.delayed(Duration.zero);
    controller.setQuery('A/B ?');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(repo.requests.length, 1);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(repo.requests.length, 2);
    expect(repo.requests[1].q, 'A/B ?');
    repo.responses[1].complete(_page('search', hasNext: true));
    await Future<void>.delayed(Duration.zero);
    final more = controller.loadMore();
    expect(repo.requests[2].status, OrderStatus.COMPLETED);
    expect(repo.requests[2].q, 'A/B ?');
    repo.responses[2].complete(_page('more', page: 2));
    await more;
    expect(controller.filtered.map((item) => item.id), ['search', 'more']);
    controller.dispose();
  });

  test(
    'clearing legacy branch criteria preserves other filters in the next query',
    () async {
      final repo = _QueueRepository();
      final controller = OrderListController(repo: repo);
      controller.setFilter(
        const OrderFilter(
          statuses: {OrderStatus.COMPLETED},
          paymentStatuses: {PaymentStatus.PAID},
          branchId: 'legacy-branch',
          assignedToId: 'assignee',
          postpaid: true,
        ),
      );
      await _waitForResponse(repo, 0);
      expect(repo.requests[0].branchId, 'legacy-branch');
      repo.responses[0].complete(_page('initial'));
      await Future<void>.delayed(Duration.zero);

      final cleared = controller.clearLegacyBranchCriteria();
      await _waitForResponse(repo, 1);
      final query = repo.requests[1];
      expect(query.branchId, isNull);
      expect(query.status, OrderStatus.COMPLETED);
      expect(query.paymentStatus, PaymentStatus.PAID);
      expect(query.assignedToId, 'assignee');
      expect(query.postpaid, isTrue);
      repo.responses[1].complete(_page('cleared'));
      await cleared;
      expect(controller.selectedBranchId, isNull);
      expect(controller.filter.branchId, isNull);
      controller.dispose();
    },
  );

  test('stale refresh cannot replace newer response and visible selection is deterministic', () async {
    final repo = _QueueRepository();
    final controller = OrderListController(repo: repo);
    final old = controller.loadOrders();
    final newer = controller.loadOrders();
    repo.responses[1].complete(_page('new'));
    await newer;
    repo.responses[0].complete(_page('old'));
    await old;
    expect(controller.filtered.single.id, 'new');
    controller.selectVisiblePage();
    expect(controller.selectedIds, {'new'});
    controller.dispose();
  });

  test(
    'bulk returns deterministic partial failures then reloads authoritatively',
    () async {
      final repo = _QueueRepository();
      final controller = OrderListController(repo: repo);
      final load = controller.loadOrders();
      repo.responses[0].complete(_page('one'));
      await load;
      controller.selectVisiblePage();
      repo.nextBulkResult = const BulkOrderResult(
        succeeded: ['one'],
        failed: [
          BulkOrderFailure(orderId: 'two', code: 'LOCKED', message: 'locked'),
        ],
      );

      final bulk = controller.bulkAssign('user');
      expect(repo.lastBulkIds, ['one']);
      await _waitForResponse(repo, 1);
      repo.responses[1].complete(_page('reloaded'));
      final result = await bulk;
      expect(result!.failed.single.code, 'LOCKED');
      expect(controller.filtered.single.id, 'reloaded');
      expect(controller.selectedCount, 0);
      controller.dispose();
    },
  );

  test('query immediately clears visible selection', () async {
    final repo = _QueueRepository();
    final controller = OrderListController(repo: repo);
    final load = controller.loadOrders();
    repo.responses[0].complete(_page('one'));
    await load;
    controller.selectVisiblePage();
    expect(controller.selectedCount, 1);
    controller.setQuery('new search');
    expect(controller.selectedCount, 0);
    controller.dispose();
  });

  test(
    'stale assignable roster cannot overwrite a newer branch roster',
    () async {
      final repo = _QueueRepository();
      final controller = OrderListController(repo: repo);
      final branchOne = controller.setBranch('branch-one');
      repo.responses[0].complete(_page('one'));
      await branchOne;
      final firstRoster = controller.loadAssignableUsers();
      final branchTwo = controller.setBranch('branch-two');
      repo.responses[1].complete(_page('two'));
      final secondRoster = controller.loadAssignableUsers();
      repo.assignableResponses[1].complete(
        const Ok([
          AssignableUser(id: 'new', firstName: 'New', lastName: 'User'),
        ]),
      );
      await secondRoster;
      repo.assignableResponses[0].complete(
        const Ok([
          AssignableUser(id: 'old', firstName: 'Old', lastName: 'User'),
        ]),
      );
      await firstRoster;
      await branchTwo;
      expect(controller.assignableUsersState.valueOrNull!.single.id, 'new');
      expect(repo.assignableBranches, ['branch-one', 'branch-two']);
      controller.dispose();
    },
  );

  test(
    'bulk IN_PROGRESS carries the required duration to the repository',
    () async {
      final repo = _QueueRepository();
      final controller = OrderListController(repo: repo);
      final load = controller.loadOrders();
      repo.responses[0].complete(_page('one'));
      await load;
      controller.selectVisiblePage();
      final bulk = controller.bulkChangeStatus(
        OrderStatus.IN_PROGRESS,
        durationMinutes: 90,
      );
      await _waitForResponse(repo, 1);
      repo.responses[1].complete(_page('reloaded'));
      await bulk;
      expect(repo.lastBulkStatus, OrderStatus.IN_PROGRESS);
      expect(repo.lastDurationMinutes, 90);
      controller.dispose();
    },
  );

  test(
    'load-more failure keeps the loaded page and exposes a retry state',
    () async {
      final repo = _QueueRepository();
      final controller = OrderListController(repo: repo);
      final initial = controller.loadOrders();
      repo.responses[0].complete(_page('first', hasNext: true));
      await initial;

      final failed = controller.loadMore();
      repo.responses[1].complete(
        const Err(AppError(ErrorKind.network, 'offline')),
      );
      await failed;

      expect(controller.filtered.single.id, 'first');
      expect(controller.loadingMore, isFalse);
      expect(controller.loadMoreError?.kind, ErrorKind.network);

      final retry = controller.loadMore();
      repo.responses[2].complete(_page('second', page: 2));
      await retry;
      expect(controller.filtered.map((item) => item.id), ['first', 'second']);
      expect(controller.loadMoreError, isNull);
      controller.dispose();
    },
  );

  test('stale bulk result cannot overwrite a newer list response', () async {
    final repo = _QueueRepository();
    final controller = OrderListController(repo: repo);
    final initial = controller.loadOrders();
    repo.responses[0].complete(_page('first'));
    await initial;
    controller.selectVisiblePage();

    final bulkResponse = Completer<Result<BulkOrderResult>>();
    repo.bulkAssignResponse = bulkResponse.future;
    final bulk = controller.bulkAssign('user');

    final newer = controller.loadOrders();
    repo.responses[1].complete(_page('newer'));
    await newer;
    bulkResponse.complete(
      const Ok(BulkOrderResult(succeeded: ['first'], failed: [])),
    );

    expect(await bulk, isNotNull);
    expect(controller.filtered.single.id, 'newer');
    expect(controller.bulkResult, isNull);
    controller.dispose();
  });

  test('seven-day preset spans today and the previous six calendar dates', () {
    final today = DateTime(2026, 9, 20, 23, 59);
    final from = DatePreset.week.cutoffAt(today);
    expect(from, DateTime(2026, 9, 14));
    expect(from!.difference(DateTime(2026, 9, 20)).inDays, -6);
  });
}
