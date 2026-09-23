import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/appointments/data/appointment_repository.dart';
import 'package:carcare_service/features/appointments/domain/appointment.dart';
import 'package:carcare_service/features/appointments/domain/appointments_repository.dart';

/// Presentation state for the server-backed Appointments list — P2-F2.
///
/// Follows `OrderListController`'s idiom exactly: the API is authoritative
/// for filtering, ordering and pagination; this controller never filters a
/// page locally.
///
/// **P2-F2a correction:** the P2-F1 frozen `AppointmentListQuery`
/// (`lib/features/appointments/domain/appointments_repository.dart`) was
/// missing `q`. `P2-B8` added `?q=` server-side, matching the web
/// dashboard's search exactly (account name case-insensitive, account phone
/// case-sensitive, note case-insensitive) and `P2-F2a` wires [setQuery]
/// through to it here. There is deliberately no date-range and no
/// customer/vehicle filter — the web dashboard has neither, and adding them
/// would be parity drift, not parity.
class AppointmentListController extends ChangeNotifier {
  AppointmentListController({
    AppointmentsRepository? repo,
    Duration? searchDebounce,
  }) : _repo = repo ?? RemoteAppointmentsRepository(),
       searchDebounce = searchDebounce ?? defaultSearchDebounce;

  static const int defaultPageSize = 50;

  /// Matches `OrderListController.searchDebounce` — the same debounce window
  /// the Orders precedent uses for `q`.
  static const Duration defaultSearchDebounce = Duration(milliseconds: 350);

  /// Injectable so tests need not sleep on the wall clock.
  ///
  /// The suite used to wait `defaultSearchDebounce + 50 ms` of real time and
  /// then assert. That margin held on an idle machine and failed under load —
  /// 2 of 3 full-suite runs failed while another `flutter test` was running,
  /// and widening the margin only moves the threshold rather than removing it.
  /// With `Duration.zero` the timer still fires asynchronously, so the
  /// debounce path is genuinely exercised, but completion depends on event-loop
  /// turns instead of elapsed time.
  final Duration searchDebounce;

  final AppointmentsRepository _repo;
  Timer? _searchTimer;

  /// Exposed so [AppointmentController] (which adds single-appointment
  /// lifecycle mutations) can reuse the same repository instance instead of
  /// constructing a second one.
  AppointmentsRepository get repository => _repo;

  int _generation = 0;
  bool _disposed = false;

  AsyncValue<List<AppointmentSummary>> listState = const AsyncLoading();
  bool loadingMore = false;
  AppError? loadMoreError;
  bool _hasNext = false;
  int _page = 1;
  int _total = 0;

  DateTime _selectedDate = _today();
  AppointmentStatus? _statusFilter;
  String? selectedBranchId;
  String _query = '';

  // ─── Touch-native selection ─────────────────────────────────────────────
  //
  // Entry is discoverable via long-press on a row (widget-driven — see
  // `appointment_screen.dart`), which both flips [selectionMode] on and
  // selects that row. While in selection mode a plain tap toggles a row.
  // Range-select is the touch-appropriate stand-in for the web's
  // mouse-drag/shift-click: `armRangeSelect()` primes a one-shot "pick the
  // other end" mode from an explicit toolbar button (see
  // `BulkSelectionBar`-equivalent in the screen); the next tap on a row
  // selects every row between the last-selected anchor and that row,
  // inclusive, in the order currently rendered on screen.
  bool selectionMode = false;
  final Set<String> _selectedIds = <String>{};
  String? _rangeAnchorId;
  bool rangeSelectArmed = false;
  AppointmentBulkResult? lastBulkResult;

  DateTime get selectedDate => _selectedDate;
  AppointmentStatus? get statusFilter => _statusFilter;
  String get query => _query;
  bool get hasNext => _hasNext;
  int get total => _total;
  int get page => _page;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  int get selectedCount => _selectedIds.length;

  /// Compatibility getter for the pre-F1 screen shape: the server page,
  /// unfiltered on the client.
  List<AppointmentSummary> get filtered =>
      listState.valueOrNull ?? const <AppointmentSummary>[];

  // ─── Date navigation ─────────────────────────────────────────────────────

  Future<void> setDate(DateTime d) {
    _selectedDate = DateTime(d.year, d.month, d.day);
    _exitSelection();
    return loadAppointments();
  }

  Future<void> prevDay() =>
      setDate(_selectedDate.subtract(const Duration(days: 1)));
  Future<void> nextDay() => setDate(_selectedDate.add(const Duration(days: 1)));

  Future<void> goToday() {
    final today = _today();
    if (_selectedDate == today) return Future.value();
    return setDate(today);
  }

  // ─── Server-side filters ─────────────────────────────────────────────────

  Future<void> setStatusFilter(AppointmentStatus? status) {
    _statusFilter = status;
    _exitSelection();
    return loadAppointments();
  }

  Future<void> setBranch(String? branchId) {
    selectedBranchId = branchId;
    _exitSelection();
    return loadAppointments();
  }

  /// Search is debounced here (not in the widget) so every caller gets the
  /// same race protection, matching `OrderListController.setQuery`. Composes
  /// with status/branch/date rather than replacing them; resets pagination
  /// to page 1 via [loadAppointments] once the debounce fires.
  void setQuery(String value) {
    _query = value.trim();
    _exitSelection();
    _searchTimer?.cancel();
    notifyListeners();
    _searchTimer = Timer(searchDebounce, () {
      if (!_disposed) unawaited(loadAppointments());
    });
  }

  // ─── Load / refresh / load-more — generation-guarded, matching
  //     OrderListController exactly ─────────────────────────────────────────

  Future<void> loadAppointments() async {
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

  Future<void> refresh() => loadAppointments();

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
        final current = listState.valueOrNull ?? const <AppointmentSummary>[];
        _page = value.pagination.page;
        _hasNext = value.pagination.hasNext;
        _total = value.pagination.total;
        listState = AsyncData([...current, ...value.items]);
      case Err(:final error):
        // Keep the loaded page intact; the footer allows a retry, matching
        // `OrderListController.loadMore`.
        loadMoreError = error;
    }
    loadingMore = false;
    notifyListeners();
  }

  // ─── Selection ───────────────────────────────────────────────────────────

  bool isSelected(String id) => _selectedIds.contains(id);

  /// Discoverable long-press entry point: flips selection mode on (if not
  /// already) and selects [id] as the range anchor.
  void enterSelectionMode(String id) {
    if (!_visibleIds.contains(id)) return;
    selectionMode = true;
    rangeSelectArmed = false;
    _selectedIds.add(id);
    _rangeAnchorId = id;
    lastBulkResult = null;
    notifyListeners();
  }

  /// Plain tap while [selectionMode] is active.
  void toggleSelection(String id) {
    if (!selectionMode || !_visibleIds.contains(id)) return;
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
      _rangeAnchorId = id;
    }
    lastBulkResult = null;
    notifyListeners();
  }

  /// Primes the one-shot "pick the other end" affordance — the touch
  /// equivalent of a shift-click. The next [toggleSelection]-eligible tap
  /// (routed through [applyRangeSelectTap]) selects the contiguous run of
  /// currently-rendered rows between the anchor and the tapped row.
  void armRangeSelect() {
    if (!selectionMode || _rangeAnchorId == null) return;
    rangeSelectArmed = true;
    notifyListeners();
  }

  void cancelRangeSelect() {
    if (!rangeSelectArmed) return;
    rangeSelectArmed = false;
    notifyListeners();
  }

  /// Row tap handler while [rangeSelectArmed] is true. Selects every
  /// visible row between the stored anchor and [id], inclusive, then
  /// disarms. Falls back to a normal [toggleSelection] if there is no
  /// anchor.
  void applyRangeSelectTap(String id) {
    final anchor = _rangeAnchorId;
    rangeSelectArmed = false;
    if (anchor == null || !_visibleIds.contains(id)) {
      toggleSelection(id);
      return;
    }
    final ids = _visibleIds;
    final start = ids.indexOf(anchor);
    final end = ids.indexOf(id);
    if (start < 0 || end < 0) {
      toggleSelection(id);
      return;
    }
    final lo = start <= end ? start : end;
    final hi = start <= end ? end : start;
    _selectedIds.addAll(ids.sublist(lo, hi + 1));
    _rangeAnchorId = id;
    lastBulkResult = null;
    notifyListeners();
  }

  /// Selects exactly the currently rendered server rows — never rows on a
  /// page not loaded into the device, matching the Orders precedent.
  void selectAllVisible() {
    selectionMode = true;
    _selectedIds
      ..clear()
      ..addAll(_visibleIds);
    lastBulkResult = null;
    notifyListeners();
  }

  void clearSelection() => _exitSelection(notify: true);

  // ─── Bulk category ───────────────────────────────────────────────────────

  /// `POST /appointments/bulk/category`. Per-row partial failure is
  /// preserved in [lastBulkResult] for the UI to render; the local list is
  /// never patched from the bulk response — on any outcome (including a
  /// request-level failure) an authoritative reload follows, per this
  /// slice's known-trap #2 (never let a discarded mutation result get
  /// silently overwritten by a later error, and never trust a client-side
  /// patch over the server).
  Future<AppointmentBulkResult?> bulkChangeCategory(String categoryId) async {
    final ids = _selectedInVisibleOrder;
    if (ids.isEmpty) return null;
    final operationGeneration = _generation;
    final result = await _repo.bulkChangeCategory(ids, categoryId);
    if (_disposed) return result.valueOrNull;
    if (operationGeneration != _generation) return result.valueOrNull;
    switch (result) {
      case Ok(:final value):
        _exitSelection();
        final reload = loadAppointments();
        final reloadGeneration = _generation;
        await reload;
        if (_disposed || reloadGeneration != _generation) return value;
        lastBulkResult = value;
        notifyListeners();
        return value;
      case Err():
        // A request-level failure (as opposed to per-row partial failure) is
        // surfaced by the caller via the returned Result; selection is kept
        // so the user can retry without losing context.
        return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _searchTimer?.cancel();
    super.dispose();
  }

  AppointmentListQuery _queryFor(int page) => AppointmentListQuery(
    status: _statusFilter,
    branchId: selectedBranchId,
    date: _selectedDate,
    q: _query.isEmpty ? null : _query,
    page: page,
    pageSize: defaultPageSize,
  );

  Future<Result<PagedResult<AppointmentSummary>>> _fetchPage(int page) =>
      _repo.getAppointments(query: _queryFor(page));

  List<String> get _visibleIds =>
      (listState.valueOrNull ?? const <AppointmentSummary>[])
          .map((a) => a.id)
          .toList(growable: false);

  List<String> get _selectedInVisibleOrder =>
      _visibleIds.where(_selectedIds.contains).toList(growable: false);

  void _exitSelection({bool notify = false}) {
    final hadState =
        selectionMode || _selectedIds.isNotEmpty || lastBulkResult != null;
    selectionMode = false;
    rangeSelectArmed = false;
    _rangeAnchorId = null;
    _selectedIds.clear();
    lastBulkResult = null;
    if (notify && hadState) notifyListeners();
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
