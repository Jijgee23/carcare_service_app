import 'package:carcare_service/core/api/api_client.dart';
import 'package:carcare_service/core/error/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/models/order.dart';
import 'package:carcare_service/features/models/pagination.dart';

class OrderRepository {
  // ─── List ──────────────────────────────────────────────────────────────────

  Future<Result<PagedResult<ServiceOrderSummary>>> getOrders({
    OrderStatus? status,
    String? vehicleId,
    String? customerId,
    String? branchId,
    int page = 1,
    int pageSize = 25,
  }) async {
    final q = [
      'page=$page',
      'pageSize=$pageSize',
      if (status != null) 'status=${status.name}',
      if (vehicleId != null) 'vehicleId=$vehicleId',
      if (customerId != null) 'customerId=$customerId',
      if (branchId != null) 'branchId=$branchId',
    ].join('&');
    try {
      final res = await apiOrThrow(Api.get, 'orders?$q');
      final list = res.data['orders'] as List;
      final meta = PaginationMeta.fromJson(res.data['pagination'] as Map<String, dynamic>);
      return Ok(
        PagedResult(
          items: list.map((e) => ServiceOrderSummary.fromJson(e as Map<String, dynamic>)).toList(),
          pagination: meta,
        ),
      );
    } on AppError catch (e) {
      return Err(e);
    }
  }

  // ─── Detail ────────────────────────────────────────────────────────────────

  Future<Result<ServiceOrderDetail>> getOrderDetail(String id) async {
    try {
      final res = await apiOrThrow(Api.get, 'orders/$id');
      return Ok(ServiceOrderDetail.fromJson(res.data['order'] as Map<String, dynamic>));
    } on AppError catch (e) {
      return Err(e);
    }
  }

  // ─── Create ────────────────────────────────────────────────────────────────

  Future<Result<ServiceOrderSummary>> createOrder({
    required String branchId,
    required String customerId,
    required String vehicleId,
    String? assignedToId,
    DateTime? scheduledAt,
    String? notes,
  }) async {
    try {
      final res = await apiOrThrow(
        Api.post,
        'orders',
        body: {
          'branchId': branchId,
          'customerId': customerId,
          'vehicleId': vehicleId,
          if (assignedToId != null && assignedToId.isNotEmpty) 'assignedToId': assignedToId,
          if (scheduledAt != null) 'scheduledAt': scheduledAt.toIso8601String(),
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return Ok(ServiceOrderSummary.fromJson(res.data['order'] as Map<String, dynamic>));
    } on AppError catch (e) {
      return Err(e);
    }
  }

  // ─── Update status ─────────────────────────────────────────────────────────

  Future<Result<ServiceOrderDetail>> updateStatus(String id, OrderStatus status) async {
    try {
      final res = await apiOrThrow(Api.patch, 'orders/$id', body: {'status': status.name});
      return Ok(ServiceOrderDetail.fromJson(res.data['order'] as Map<String, dynamic>));
    } on AppError catch (e) {
      return Err(e);
    }
  }

  // ─── Items ─────────────────────────────────────────────────────────────────

  Future<Result<ServiceItem>> addItem(
    String orderId, {
    required ItemKind kind,
    required String description,
    required double quantity,
    required double unitPrice,
    String? serviceId,
  }) async {
    try {
      final res = await apiOrThrow(
        Api.post,
        'orders/$orderId/items',
        body: {
          'kind': kind.name,
          'description': description,
          'quantity': quantity,
          'unitPrice': unitPrice,
          if (serviceId != null && serviceId.isNotEmpty) 'serviceId': serviceId,
        },
      );
      return Ok(ServiceItem.fromJson(res.data['item'] as Map<String, dynamic>));
    } on AppError catch (e) {
      return Err(e);
    }
  }

  Future<Result<void>> removeItem(String orderId, String itemId) async {
    try {
      await apiOrThrow(Api.delete, 'orders/$orderId/items/$itemId');
      return const Ok(null);
    } on AppError catch (e) {
      return Err(e);
    }
  }

  Future<Result<ServiceItem>> updateItem(
    String orderId,
    String itemId, {
    ItemKind? kind,
    String? description,
    double? quantity,
    double? unitPrice,
  }) async {
    try {
      final res = await apiOrThrow(
        Api.patch,
        'orders/$orderId/items/$itemId',
        body: {
          if (kind != null) 'kind': kind.name,
          if (description != null) 'description': description,
          if (quantity != null) 'quantity': quantity,
          if (unitPrice != null) 'unitPrice': unitPrice,
        },
      );
      return Ok(ServiceItem.fromJson(res.data['item'] as Map<String, dynamic>));
    } on AppError catch (e) {
      return Err(e);
    }
  }

  // ─── Payment ───────────────────────────────────────────────────────────────

  Future<Result<ServiceOrderDetail>> updatePayment(
    String id, {
    required PaymentStatus status,
    double? paidAmount,
  }) async {
    try {
      final res = await apiOrThrow(
        Api.patch,
        'orders/$id/payment',
        body: {
          'paymentStatus': status.name,
          if (paidAmount != null) 'paidAmount': paidAmount,
        },
      );
      return Ok(ServiceOrderDetail.fromJson(res.data['order'] as Map<String, dynamic>));
    } on AppError catch (e) {
      return Err(e);
    }
  }

  // ─── QPay ──────────────────────────────────────────────────────────────────

  Future<Result<({bool qpayEnabled, OrderPayment? pending})>> getQPay(
    String orderId,
  ) async {
    try {
      final res = await apiOrThrow(Api.get, 'orders/$orderId/qpay');
      final enabled = res.data['qpayEnabled'] as bool? ?? false;
      final pendingJson = res.data['pending'] as Map<String, dynamic>?;
      return Ok((
        qpayEnabled: enabled,
        pending: pendingJson != null ? OrderPayment.fromJson(pendingJson) : null,
      ));
    } on AppError catch (e) {
      return Err(e);
    }
  }

  Future<Result<OrderPayment>> createQPay(String orderId) async {
    try {
      final res = await apiOrThrow(Api.post, 'orders/$orderId/qpay');
      return Ok(OrderPayment.fromJson(res.data['payment'] as Map<String, dynamic>));
    } on AppError catch (e) {
      return Err(e);
    }
  }

  Future<Result<({bool paid, String? message})>> checkQPay(
    String orderId,
    String paymentId,
  ) async {
    try {
      final res = await apiOrThrow(
        Api.post,
        'orders/$orderId/qpay/check',
        body: {'paymentId': paymentId},
      );
      return Ok((
        paid: res.data['paid'] as bool? ?? false,
        message: res.data['message'] as String?,
      ));
    } on AppError catch (e) {
      return Err(e);
    }
  }

  Future<Result<void>> cancelQPay(String orderId, String paymentId) async {
    try {
      await apiOrThrow(
        Api.delete,
        'orders/$orderId/qpay',
        body: {'paymentId': paymentId},
      );
      return const Ok(null);
    } on AppError catch (e) {
      return Err(e);
    }
  }
}
