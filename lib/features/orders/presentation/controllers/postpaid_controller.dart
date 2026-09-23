import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/domain/orders_repository.dart';

/// State for the postpaid history surface.
///
/// The API deliberately returns aggregate totals independently from the
/// paginated history filters. This controller therefore stores the server
/// page as-is and never derives or replaces its totals from the loaded rows.
class PostpaidController extends ChangeNotifier {
  // Keep the public `repo:` name; the private initializing formal would make
  // callers outside this library unable to construct the controller.
  // ignore: prefer_initializing_formals
  PostpaidController({required OrdersRepository repo}) : _repo = repo;

  final OrdersRepository _repo;

  AsyncValue<PostpaidPage> state = const AsyncLoading();
  bool loadingMore = false;
  AppError? loadMoreError;

  String? selectedVehicleId;
  PaymentStatus? selectedPaymentStatus;
  DateTime? dateFrom;
  DateTime? dateTo;
  String? selectedBranchId;

  int _page = 1;
  bool _hasNext = false;
  int _generation = 0;
  bool _disposed = false;

  PostpaidPage? get page => state.valueOrNull;
  List<PostpaidVehicleAggregate> get vehicles =>
      page?.vehicles ?? const <PostpaidVehicleAggregate>[];
  List<ServiceOrderSummary> get orders =>
      page?.orders ?? const <ServiceOrderSummary>[];
  PostpaidSummary? get summary => page?.summary;
  PaginationMeta? get pagination => page?.pagination;
  bool get hasNext => _hasNext;
  int get currentPage => _page;

  PostpaidQuery get query => PostpaidQuery(
    vehicleId: selectedVehicleId,
    paymentStatus: selectedPaymentStatus,
    dateFrom: dateFrom,
    dateTo: dateTo,
    page: _page,
  );

  Future<void> load() async {
    final generation = ++_generation;
    _page = 1;
    _hasNext = false;
    loadingMore = false;
    loadMoreError = null;
    state = const AsyncLoading();
    _notify();

    final result = await _repo.getPostpaid(query: _queryForPage(1));
    if (!_isCurrent(generation)) return;
    switch (result) {
      case Ok(:final value):
        _page = value.pagination.page;
        _hasNext = value.pagination.hasNext;
        state = AsyncData(value);
      case Err(:final error):
        state = AsyncError(error);
    }
    _notify();
  }

  Future<void> retry() => load();

  Future<void> refresh() => load();

  Future<void> loadMore() async {
    if (loadingMore || !_hasNext || state.valueOrNull == null) return;
    final generation = _generation;
    final nextPage = _page + 1;
    loadingMore = true;
    loadMoreError = null;
    _notify();

    final result = await _repo.getPostpaid(query: _queryForPage(nextPage));
    if (!_isCurrent(generation)) return;
    switch (result) {
      case Ok(:final value):
        final current = state.valueOrNull!;
        _page = value.pagination.page;
        _hasNext = value.pagination.hasNext;
        state = AsyncData(
          PostpaidPage(
            vehicles: current.vehicles,
            summary: current.summary,
            orders: [...current.orders, ...value.orders],
            pagination: value.pagination,
          ),
        );
      case Err(:final error):
        loadMoreError = error;
    }
    loadingMore = false;
    _notify();
  }

  Future<void> setBranch(String? branchId) async {
    if (selectedBranchId == branchId) return;
    selectedBranchId = branchId;
    await load();
  }

  Future<void> setVehicle(String? vehicleId) async {
    if (selectedVehicleId == vehicleId) return;
    selectedVehicleId = vehicleId;
    await load();
  }

  Future<void> setPaymentStatus(PaymentStatus? status) async {
    if (selectedPaymentStatus == status) return;
    selectedPaymentStatus = status;
    await load();
  }

  Future<void> setDateRange(DateTime? from, DateTime? to) async {
    final normalizedFrom = _dateOnly(from);
    final normalizedTo = _dateOnly(to);
    if (dateFrom == normalizedFrom && dateTo == normalizedTo) return;
    dateFrom = normalizedFrom;
    dateTo = normalizedTo;
    await load();
  }

  Future<void> clearFilters() async {
    if (selectedVehicleId == null &&
        selectedPaymentStatus == null &&
        dateFrom == null &&
        dateTo == null) {
      return;
    }
    selectedVehicleId = null;
    selectedPaymentStatus = null;
    dateFrom = null;
    dateTo = null;
    await load();
  }

  PostpaidQuery _queryForPage(int page) => PostpaidQuery(
    vehicleId: selectedVehicleId,
    paymentStatus: selectedPaymentStatus,
    dateFrom: dateFrom,
    dateTo: dateTo,
    page: page,
  );

  DateTime? _dateOnly(DateTime? value) =>
      value == null ? null : DateTime(value.year, value.month, value.day);

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
