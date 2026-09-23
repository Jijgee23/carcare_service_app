import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/employees/data/employee_repository.dart';
import 'package:carcare_service/features/employees/domain/employee.dart';
import 'package:carcare_service/features/employees/domain/employees_repository.dart';

/// Presentation state for the server-backed Employees list — P6-F2.
///
/// Copies `ServiceListController`'s generation-guarded load/loadMore/
/// debounced-search shape exactly (see that file's doc comment for the race
/// the guard closes). The API is authoritative for filtering, ordering and
/// pagination; this controller never filters a page locally and never
/// invents a query parameter outside the frozen [EmployeeListQuery]
/// contract (`q`, `branchId`, `roleId`, `active`, `page`, `pageSize`).
///
/// [meta] (branch chips with stable counts + role labels) is refreshed on
/// every full [loadEmployees] alongside the page — one call produces both,
/// per `EmployeesRepository.getEmployees`'s doc comment.
class EmployeeListController extends ChangeNotifier {
  EmployeeListController({EmployeesRepository? repo, Duration? searchDebounce})
    : _repo = repo ?? RemoteEmployeesRepository(),
      searchDebounce = searchDebounce ?? defaultSearchDebounce;

  static const int defaultPageSize = 50;
  static const Duration defaultSearchDebounce = Duration(milliseconds: 350);

  final Duration searchDebounce;
  final EmployeesRepository _repo;
  Timer? _searchTimer;

  EmployeesRepository get repository => _repo;

  int _generation = 0;
  bool _disposed = false;

  AsyncValue<List<Employee>> listState = const AsyncLoading();
  EmployeeListMeta meta = const EmployeeListMeta();
  bool loadingMore = false;
  AppError? loadMoreError;
  bool _hasNext = false;
  int _page = 1;
  int _total = 0;

  String _query = '';
  String? _branchId;
  String? _roleId;

  /// `null` = both; `true`/`false` narrows to active/inactive only.
  bool? _active;

  String get query => _query;
  String? get branchId => _branchId;
  String? get roleId => _roleId;
  bool? get active => _active;
  bool get hasNext => _hasNext;
  int get total => _total;
  int get page => _page;

  List<Employee> get filtered => listState.valueOrNull ?? const <Employee>[];

  // ─── Server-side filters ─────────────────────────────────────────────────

  void setQuery(String value) {
    _query = value.trim();
    _searchTimer?.cancel();
    notifyListeners();
    _searchTimer = Timer(searchDebounce, () {
      if (!_disposed) unawaited(loadEmployees());
    });
  }

  /// Branch chip tap. Only a real branch id or `null` (the "Бүгд" chip) is
  /// accepted as a filter. The synthetic "Хуваарилагдаагүй" (unassigned)
  /// chip in `meta.branches` (`id: ""`) is deliberately **not** wireable
  /// here: `GET /employees`'s `branchId` query param is dropped when empty
  /// (`optionalText`/`branchId && {branchId}` in `route.ts`), so the server
  /// has no way to filter *by* an unassigned branch at all. An earlier
  /// version of this controller faked that filter client-side over
  /// whatever page happened to be loaded, which silently produced wrong
  /// results once there was more than one page (an unassigned employee
  /// outside the loaded page(s) would not appear). Rather than repeat that
  /// mistake, the unassigned chip renders as a count-only, non-tappable
  /// badge (see `_BranchChipRow`) until the backend contract adds a real
  /// way to filter by it.
  Future<void> setBranch(String? branchId) {
    if (branchId == '' || branchId == _branchId) return Future.value();
    _branchId = branchId;
    return loadEmployees();
  }

  Future<void> setRole(String? roleId) {
    if (roleId == _roleId) return Future.value();
    _roleId = roleId;
    return loadEmployees();
  }

  Future<void> setActive(bool? active) {
    if (active == _active) return Future.value();
    _active = active;
    return loadEmployees();
  }

  // ─── Load / refresh / load-more ──────────────────────────────────────────

  Future<void> loadEmployees() async {
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
        _page = value.page.pagination.page;
        _hasNext = value.page.pagination.hasNext;
        _total = value.page.pagination.total;
        meta = value.meta;
        listState = AsyncData(value.page.items);
      case Err(:final error):
        listState = AsyncError(error);
    }
    notifyListeners();
  }

  Future<void> refresh() => loadEmployees();

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
        final current = listState.valueOrNull ?? const <Employee>[];
        _page = value.page.pagination.page;
        _hasNext = value.page.pagination.hasNext;
        _total = value.page.pagination.total;
        meta = value.meta;
        listState = AsyncData([...current, ...value.page.items]);
      case Err(:final error):
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

  EmployeeListQuery _queryFor(int page) => EmployeeListQuery(
    q: _query.isEmpty ? null : _query,
    branchId: _branchId,
    roleId: _roleId,
    active: _active,
    page: page,
    pageSize: defaultPageSize,
  );

  Future<Result<EmployeePage>> _fetchPage(int page) =>
      _repo.getEmployees(query: _queryFor(page));
}
