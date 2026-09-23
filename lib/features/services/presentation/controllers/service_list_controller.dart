import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/services/data/service_repository.dart';
import 'package:carcare_service/features/services/domain/service.dart';
import 'package:carcare_service/features/services/domain/services_repository.dart';

/// Presentation state for the server-backed Services list — P4-F2.
///
/// Copies `VehicleListController`/`AppointmentListController`'s
/// generation-guarded load/loadMore/debounced-search shape exactly (see
/// those files' doc comments for the race the guard closes). The API is
/// authoritative for filtering, ordering and pagination; this controller
/// never filters a page locally, and it never invents a query parameter
/// outside the frozen `ServiceListQuery` (`type`, `q`, `includeInactive`,
/// `page`, `pageSize` — `P4-F1`'s contract).
///
/// [type] always holds one of the three kinds the kind-filter tabs offer —
/// there is deliberately no "all kinds" option, matching the legacy screen's
/// three-tab shape (see `service_list_screen.dart`'s affordance list).
/// Switching tabs triggers a fresh, authoritative server reload rather than
/// keeping three independently client-cached lists the way the legacy
/// `TabBarView` + `AutomaticKeepAliveClientMixin` did — consistent with
/// every other server-side filter in this app
/// (`VehicleListController.setAssigned`,
/// `AppointmentListController.setStatusFilter`): a filter change is always a
/// fresh fetch, never a client-cached swap.
///
/// [includeInactive] stays `false` (server default: active-only) — this
/// slice does not add a "show archived" affordance the legacy screen never
/// had either; see [ServiceListQuery]'s doc comment for why that flag is a
/// one-way switch, not a tri-state filter.
class ServiceListController extends ChangeNotifier {
  ServiceListController({
    ServicesRepository? repo,
    Duration? searchDebounce,
    ServiceKind? initialType,
  }) : _repo = repo ?? RemoteServicesRepository(),
       searchDebounce = searchDebounce ?? defaultSearchDebounce {
    // `P4-F4` addition: seeds the server-side kind filter to match whatever
    // tab `ServiceListScreen.initialType` opens on, so a route that already
    // knows the desired kind (the "Каталог" drawer) does not open the list
    // on labor and then have to re-fetch when the tab visually corrects
    // itself. `null` keeps the pre-existing default below untouched.
    if (initialType != null) _type = initialType;
  }

  static const int defaultPageSize = 50;

  /// Matches `AppointmentListController.defaultSearchDebounce` /
  /// `VehicleListController.defaultSearchDebounce` — same window across
  /// every list in the app so search feels consistent.
  static const Duration defaultSearchDebounce = Duration(milliseconds: 350);

  /// Injectable so tests need not sleep on the wall clock — see
  /// `AppointmentListController`'s doc comment for why `Duration.zero` still
  /// genuinely exercises the debounce path under test.
  final Duration searchDebounce;

  final ServicesRepository _repo;
  Timer? _searchTimer;

  ServicesRepository get repository => _repo;

  int _generation = 0;
  bool _disposed = false;

  AsyncValue<List<Service>> listState = const AsyncLoading();
  bool loadingMore = false;
  AppError? loadMoreError;
  bool _hasNext = false;
  int _page = 1;
  int _total = 0;

  String _query = '';

  /// Default tab: the legacy screen's `TabController` opened on the labor
  /// tab (index 0) — preserved here as the controller's initial filter so a
  /// freshly-constructed controller and a freshly-built screen agree on
  /// which tab is selected without either having to tell the other.
  ServiceKind _type = ServiceKind.labor;
  final bool _includeInactive = false;

  String get query => _query;
  ServiceKind get type => _type;
  bool get includeInactive => _includeInactive;
  bool get hasNext => _hasNext;
  int get total => _total;
  int get page => _page;

  /// Compatibility getter mirroring `AppointmentListController.filtered` /
  /// `VehicleListController.filtered`: the server page, unfiltered on the
  /// client.
  List<Service> get filtered => listState.valueOrNull ?? const <Service>[];

  // ─── Server-side filters ─────────────────────────────────────────────────

  /// Debounced exactly like `AppointmentListController.setQuery` /
  /// `VehicleListController.setQuery` — the same race protection for every
  /// caller, and pagination resets to page 1 once the debounce fires.
  void setQuery(String value) {
    _query = value.trim();
    _searchTimer?.cancel();
    notifyListeners();
    _searchTimer = Timer(searchDebounce, () {
      if (!_disposed) unawaited(loadServices());
    });
  }

  /// Kind-filter-tab entry point. Not debounced — a tab switch is a single
  /// discrete action, unlike keystrokes, matching
  /// `AppointmentListController.setStatusFilter`.
  Future<void> setType(ServiceKind type) {
    if (type == _type) return Future.value();
    _type = type;
    return loadServices();
  }

  // ─── Load / refresh / load-more — generation-guarded, matching
  //     AppointmentListController / VehicleListController exactly ─────────

  Future<void> loadServices() async {
    final requestGeneration = ++_generation;
    _searchTimer?.cancel();
    loadingMore = false;
    loadMoreError = null;
    _page = 1;
    _hasNext = false;
    listState = const AsyncLoading();
    notifyListeners();

    final result = await _fetchPage(1);
    if (_disposed || requestGeneration != _generation) return;
    switch (result) {
      case Ok(:final value):
        _page = value.pagination.page;
        _hasNext = value.pagination.hasNext;
        _total = value.pagination.total;
        listState = AsyncData(value.items);
      case Err(:final error):
        listState = AsyncError(error);
    }
    notifyListeners();
  }

  Future<void> refresh() => loadServices();

  Future<void> loadMore() async {
    if (_disposed || loadingMore || !_hasNext) return;
    final requestGeneration = _generation;
    final nextPage = _page + 1;
    loadingMore = true;
    loadMoreError = null;
    notifyListeners();

    final result = await _fetchPage(nextPage);
    if (_disposed || requestGeneration != _generation) return;
    switch (result) {
      case Ok(:final value):
        final current = listState.valueOrNull ?? const <Service>[];
        _page = value.pagination.page;
        _hasNext = value.pagination.hasNext;
        _total = value.pagination.total;
        listState = AsyncData([...current, ...value.items]);
      case Err(:final error):
        // Keep the loaded page intact; the footer allows a retry, matching
        // `VehicleListController.loadMore` / `AppointmentListController.loadMore`.
        loadMoreError = error;
    }
    loadingMore = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _searchTimer?.cancel();
    super.dispose();
  }

  ServiceListQuery _queryFor(int page) => ServiceListQuery(
    type: _type,
    q: _query.isEmpty ? null : _query,
    includeInactive: _includeInactive,
    page: page,
    pageSize: defaultPageSize,
  );

  Future<Result<PagedResult<Service>>> _fetchPage(int page) =>
      _repo.getServices(query: _queryFor(page));
}
