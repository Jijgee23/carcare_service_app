import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/models/order.dart';
import 'package:carcare_service/features/presentation/data/repository/order_repository.dart';
import 'package:carcare_service/features/presentation/pages/orders/order_filter_sheet.dart';
import 'package:carcare_service/shared/widgets/dialogs/message.dart';
import 'package:flutter/material.dart';

class OrderController extends ChangeNotifier {
  OrderController({OrderRepository? repo}) : _repo = repo ?? OrderRepository();

  final OrderRepository _repo;

  // ─── List state ────────────────────────────────────────────────────────────

  AsyncValue<List<ServiceOrderSummary>> listState = const AsyncLoading();
  bool loadingMore = false;
  bool _hasNext = false;
  int _page = 1;
  int _total = 0;

  bool get hasNext => _hasNext;
  int get total => _total;

  // ─── Detail state ──────────────────────────────────────────────────────────

  AsyncValue<ServiceOrderDetail> detailState = const AsyncLoading();
  String? _detailId;

  // ─── Filter / search ───────────────────────────────────────────────────────

  OrderFilter _filter = OrderFilter.empty;
  String _query = '';
  String? selectedBranchId;

  OrderFilter get filter => _filter;
  String get query => _query;

  List<ServiceOrderSummary> get filtered {
    var list = _filter.apply(listState.valueOrNull ?? []);
    if (_query.isNotEmpty) {
      list = list.where((o) {
        return o.number.contains(_query) ||
            o.customer.displayName.toLowerCase().contains(_query) ||
            o.vehicle.plate.toLowerCase().contains(_query) ||
            o.vehicle.make.toLowerCase().contains(_query) ||
            o.vehicle.model.toLowerCase().contains(_query);
      }).toList();
    }
    return list;
  }

  // ─── Load ──────────────────────────────────────────────────────────────────

  void setBranch(String? branchId) {
    selectedBranchId = branchId;
    loadOrders();
  }

  Future<void> loadOrders() async {
    _page = 1;
    listState = const AsyncLoading();
    notifyListeners();
    final result = await _repo.getOrders(page: 1, branchId: selectedBranchId);
    switch (result) {
      case Ok(:final value):
        _hasNext = value.pagination.hasNext;
        _total = value.pagination.total;
        listState = AsyncData(value.items);
      case Err(:final error):
        listState = AsyncError(error);
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (loadingMore || !_hasNext) return;
    loadingMore = true;
    notifyListeners();
    final result = await _repo.getOrders(page: _page + 1, branchId: selectedBranchId);
    switch (result) {
      case Ok(:final value):
        final current = listState.valueOrNull ?? [];
        _page = value.pagination.page;
        _hasNext = value.pagination.hasNext;
        _total = value.pagination.total;
        listState = AsyncData([...current, ...value.items]);
      case Err(): // load more алдааг чимээгүй орхино
        break;
    }
    loadingMore = false;
    notifyListeners();
  }

  void setFilter(OrderFilter f) {
    _filter = f;
    notifyListeners();
  }

  void clearFilter() {
    _filter = OrderFilter.empty;
    notifyListeners();
  }

  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  void prependOrder(ServiceOrderSummary order) {
    final current = listState.valueOrNull ?? [];
    listState = AsyncData([order, ...current]);
    _total++;
    notifyListeners();
  }

  // ─── Detail ────────────────────────────────────────────────────────────────

  Future<void> loadDetail(String id) async {
    _detailId = id;
    detailState = const AsyncLoading();
    notifyListeners();
    final result = await _repo.getOrderDetail(id);
    detailState = switch (result) {
      Ok(:final value) => AsyncData(value),
      Err(:final error) => AsyncError(error),
    };
    notifyListeners();
  }

  Future<void> refreshDetail() async {
    if (_detailId == null) return;
    final result = await _repo.getOrderDetail(_detailId!);
    if (result case Ok(:final value)) {
      detailState = AsyncData(value);
      notifyListeners();
    }
  }

  // ─── Mutations — алдааг toast-оор харуулна ─────────────────────────────────

  Future<bool> updateStatus(String id, OrderStatus status) async {
    final result = await _repo.updateStatus(id, status);
    switch (result) {
      case Ok(:final value):
        detailState = AsyncData(value);
        notifyListeners();
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
    switch (result) {
      case Ok():
        await refreshDetail();
        return true;
      case Err(:final error):
        messageError(error.display);
        return false;
    }
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
    switch (result) {
      case Ok():
        await refreshDetail();
        return true;
      case Err(:final error):
        messageError(error.display);
        return false;
    }
  }

  Future<bool> removeItem(String orderId, String itemId) async {
    final result = await _repo.removeItem(orderId, itemId);
    switch (result) {
      case Ok():
        await refreshDetail();
        return true;
      case Err(:final error):
        messageError(error.display);
        return false;
    }
  }

  // ─── Payment ────────────────────────────────────────────────────────────────

  Future<bool> updatePayment(
    String id,
    PaymentStatus status, {
    double? paidAmount,
  }) async {
    final result = await _repo.updatePayment(id, status: status, paidAmount: paidAmount);
    switch (result) {
      case Ok(:final value):
        detailState = AsyncData(value);
        notifyListeners();
        return true;
      case Err(:final error):
        messageError(error.display);
        return false;
    }
  }

  Future<({bool qpayEnabled, OrderPayment? pending})?> getQPay(String id) async {
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
}
