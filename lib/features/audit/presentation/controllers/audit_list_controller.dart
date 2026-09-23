import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/audit/data/audit_repository.dart';
import 'package:carcare_service/features/audit/domain/audit_log.dart';
import 'package:carcare_service/features/audit/domain/audit_repository.dart';

/// Presentation state for the server-backed Audit log list — P7-F3.
///
/// Copies `EmployeeListController`'s generation-guarded load/loadMore/
/// debounced-search shape. Page size is fixed server-side at 50
/// (`AuditListQuery` has no `pageSize`, per the frozen P7-F1 contract) — this
/// controller never invents one. The API is authoritative for filtering,
/// ordering and pagination; nothing here filters a loaded page locally.
class AuditListController extends ChangeNotifier {
  AuditListController({AuditRepository? repo, Duration? searchDebounce})
    : _repo = repo ?? RemoteAuditRepository(),
      searchDebounce = searchDebounce ?? defaultSearchDebounce;

  static const Duration defaultSearchDebounce = Duration(milliseconds: 350);

  final Duration searchDebounce;
  final AuditRepository _repo;
  Timer? _searchTimer;

  int _generation = 0;
  bool _disposed = false;

  AsyncValue<List<AuditLogEntry>> listState = const AsyncLoading();
  AuditListMeta meta = const AuditListMeta();
  bool loadingMore = false;
  AppError? loadMoreError;
  bool _hasNext = false;
  int _page = 1;
  int _total = 0;

  String _query = '';
  String? _action;
  String? _entity;
  String? _userId;
  String? _from;
  String? _to;

  String get query => _query;
  String? get action => _action;
  String? get entity => _entity;
  String? get userId => _userId;
  String? get from => _from;
  String? get to => _to;
  bool get hasNext => _hasNext;
  int get total => _total;
  int get page => _page;

  bool get hasActiveFilters =>
      _action != null || _entity != null || _userId != null ||
      _from != null || _to != null;

  List<AuditLogEntry> get entries =>
      listState.valueOrNull ?? const <AuditLogEntry>[];

  // ─── Server-side filters ─────────────────────────────────────────────────

  void setQuery(String value) {
    _query = value.trim();
    _searchTimer?.cancel();
    notifyListeners();
    _searchTimer = Timer(searchDebounce, () {
      if (!_disposed) unawaited(loadAuditLog());
    });
  }

  /// Applies the whole filter set from the filter sheet in one go — a single
  /// server round-trip rather than one per changed field.
  Future<void> applyFilters({
    String? action,
    String? entity,
    String? userId,
    String? from,
    String? to,
  }) {
    _action = action;
    _entity = entity;
    _userId = userId;
    _from = from;
    _to = to;
    return loadAuditLog();
  }

  Future<void> clearFilters() {
    _action = null;
    _entity = null;
    _userId = null;
    _from = null;
    _to = null;
    return loadAuditLog();
  }

  // ─── Load / refresh / load-more ──────────────────────────────────────────

  Future<void> loadAuditLog() async {
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
        meta = value.meta;
        listState = AsyncData(value.items);
      case Err(:final error):
        listState = AsyncError(error);
    }
    notifyListeners();
  }

  Future<void> refresh() => loadAuditLog();

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
        final current = listState.valueOrNull ?? const <AuditLogEntry>[];
        _page = value.pagination.page;
        _hasNext = value.pagination.hasNext;
        _total = value.pagination.total;
        meta = value.meta;
        listState = AsyncData([...current, ...value.items]);
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

  AuditListQuery _queryFor(int page) => AuditListQuery(
    q: _query.isEmpty ? null : _query,
    action: _action,
    entity: _entity,
    userId: _userId,
    from: _from,
    to: _to,
    page: page,
  );

  Future<Result<AuditPage>> _fetchPage(int page) =>
      _repo.getAuditLog(query: _queryFor(page));
}
