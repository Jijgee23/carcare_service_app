import 'dart:async';

import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/domain/orders_repository.dart';
import 'package:carcare_service/features/orders/presentation/controllers/order_list_controller.dart';

/// Shared Orders notifier. List state lives in [OrderListController]; detail
/// actions remain here for the existing detail screen until P1-F4 extracts it.
class OrderController extends OrderListController {
  OrderController({required super.repo}) : _repo = repo;

  final OrdersRepository _repo;
  AsyncValue<ServiceOrderDetail> detailState = const AsyncLoading();
  String? _detailId;
  int _detailGeneration = 0;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _detailGeneration++;
    super.dispose();
  }

  void prependOrder(ServiceOrderSummary order) {
    final current = listState.valueOrNull ?? const <ServiceOrderSummary>[];
    listState = AsyncData([order, ...current]);
    notifyListeners();
  }

  Future<void> loadDetail(String id) async {
    final generation = ++_detailGeneration;
    _detailId = id;
    detailState = const AsyncLoading();
    notifyListeners();
    final result = await _repo.getOrderDetail(id);
    if (generation != _detailGeneration) return;
    detailState = switch (result) {
      Ok(:final value) => AsyncData(value),
      Err(:final error) => AsyncError(error),
    };
    notifyListeners();
  }

  Future<void> refreshDetail() async {
    final id = _detailId;
    if (id == null) return;
    final generation = ++_detailGeneration;
    final result = await _repo.getOrderDetail(id);
    if (generation != _detailGeneration) return;
    if (result case Ok(:final value)) {
      detailState = AsyncData(value);
      notifyListeners();
    }
  }

  Future<bool> updateStatus(String id, OrderStatus status) async {
    final result = await _repo.updateStatus(id, status);
    if (_disposed) return result is Ok<ServiceOrderDetail>;
    switch (result) {
      case Ok(:final value):
        detailState = AsyncData(value);
        notifyListeners();
        unawaited(refresh());
        return true;
      case Err(:final error):
        messageError(error.display);
        return false;
    }
  }

  Future<bool> addItem(
    String orderId, {
    required ItemKind kind,
    required String description,
    required double quantity,
    required double unitPrice,
    String? serviceId,
  }) async {
    final result = await _repo.addItem(
      orderId,
      kind: kind,
      description: description,
      quantity: quantity,
      unitPrice: unitPrice,
      serviceId: serviceId,
    );
    return _reloadAfter(result);
  }

  Future<bool> updateItem(
    String orderId,
    String itemId, {
    ItemKind? kind,
    String? description,
    double? quantity,
    double? unitPrice,
  }) async {
    final result = await _repo.updateItem(
      orderId,
      itemId,
      kind: kind,
      description: description,
      quantity: quantity,
      unitPrice: unitPrice,
    );
    return _reloadAfter(result);
  }

  Future<({bool qpayEnabled, OrderPayment? pending})?> getQPay(
    String id,
  ) async {
    final result = await _repo.getQPay(id);
    switch (result) {
      case Ok(:final value):
        return value;
      case Err(:final error):
        messageError(error.display);
        return null;
    }
  }

  Future<OrderPayment?> createQPay(String id) async {
    final result = await _repo.createQPay(id);
    switch (result) {
      case Ok(:final value):
        return value;
      case Err(:final error):
        messageError(error.display);
        return null;
    }
  }

  Future<({bool paid, String? message})?> checkQPay(
    String id,
    String paymentId,
  ) async {
    final result = await _repo.checkQPay(id, paymentId);
    switch (result) {
      case Ok(:final value):
        if (value.paid) await refreshDetail();
        return value;
      case Err(:final error):
        messageError(error.display);
        return null;
    }
  }

  Future<void> cancelQPay(String id, String paymentId) async {
    await _repo.cancelQPay(id, paymentId);
  }

  Future<bool> _reloadAfter<T>(Result<T> result) async {
    switch (result) {
      case Ok():
        await refreshDetail();
        return true;
      case Err(:final error):
        messageError(error.display);
        return false;
    }
  }
}
