import 'package:carcare_service/core/domain/diagnostic.dart';
import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/domain/orders_repository.dart';

import '../../fakes/fake_order_repository.dart';

/// Fixed "now" for Today tests: 2026-09-23 10:00 local.
final todayNow = DateTime(2026, 9, 23, 10);

ServiceOrderSummary todayOrder(
  String id, {
  OrderStatus status = OrderStatus.SCHEDULED,
  PaymentStatus paymentStatus = PaymentStatus.UNPAID,
  DateTime? scheduledAt,
  DateTime? startedAt,
  DateTime? completedAt,
  DateTime? expectedFinishAt,
  DateTime? createdAt,
  UserSummary? assignedTo,
  String? plate,
  List<String> servicePreview = const [],
}) => ServiceOrderSummary(
  id: id,
  number: 'A-$id',
  status: status,
  paymentStatus: paymentStatus,
  scheduledAt: scheduledAt,
  startedAt: startedAt,
  completedAt: completedAt,
  expectedFinishAt: expectedFinishAt,
  createdAt: createdAt ?? DateTime(2026, 9, 23, 8),
  assignedTo: assignedTo,
  servicePreview: servicePreview,
  customer: const CustomerSummary(id: 'c', fullName: 'Бат', phone: '99001122'),
  vehicle: VehicleSummary(
    id: 'v-$id',
    plate: plate ?? 'PL-$id',
    make: 'Toyota',
    model: 'Prius',
  ),
  branch: const BranchSummary(id: 'b', name: 'Салбар'),
);

/// A minimal [ServiceOrderDetail] for a [todayOrder] summary, so the same id
/// can be opened through [OrdersRepository.getOrderDetail] (the detail pane
/// / pushed detail route) as well as listed on the board.
ServiceOrderDetail todayOrderDetail(
  String id, {
  OrderStatus status = OrderStatus.SCHEDULED,
  PaymentStatus paymentStatus = PaymentStatus.UNPAID,
}) => ServiceOrderDetail(
  id: id,
  number: 'A-$id',
  status: status,
  paymentStatus: paymentStatus,
  createdAt: DateTime(2026, 9, 23, 8),
  customer: const CustomerSummary(id: 'c', fullName: 'Бат', phone: '99001122'),
  vehicle: VehicleSummary(id: 'v-$id', plate: 'PL-$id', make: 'Toyota', model: 'Prius'),
  branch: const BranchSummary(id: 'b', name: 'Салбар'),
  items: const [],
  reports: const [],
);

/// Serves fixed pages per status and records status updates.
class TodayFakeRepository extends FakeOrderRepository {
  TodayFakeRepository({
    this.byStatus = const {},
    this.totals = const {},
    this.failWith,
    super.seedOrders = const [],
  });

  Map<OrderStatus, List<ServiceOrderSummary>> byStatus;
  final Map<OrderStatus, int> totals;
  AppError? failWith;
  final List<OrderListQuery> queries = [];
  final List<({String id, OrderStatus status, int? duration})> updates = [];

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
    if (query != null) queries.add(query);
    final error = failWith;
    if (error != null) return Err(error);
    final allItems = byStatus[status] ?? const <ServiceOrderSummary>[];
    final total = totals[status] ?? allItems.length;
    final start = (page - 1) * pageSize;
    final items = start >= allItems.length
        ? <ServiceOrderSummary>[]
        : allItems.skip(start).take(pageSize).toList();
    return Ok(
      PagedResult(
        items: items,
        pagination: PaginationMeta(
          page: page,
          pageSize: pageSize,
          total: total,
          totalPages: (total / pageSize).ceil(),
          hasPrev: page > 1,
          hasNext: page * pageSize < total,
        ),
      ),
    );
  }

  @override
  Future<Result<ServiceOrderDetail>> updateStatus(
    String id,
    OrderStatus status, {
    int? durationMinutes,
  }) {
    updates.add((id: id, status: status, duration: durationMinutes));
    return super.updateStatus(
      'order-1',
      status,
      durationMinutes: durationMinutes,
    );
  }
}
