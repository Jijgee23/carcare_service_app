import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/widgets/selection/selection_controller.dart';
import 'package:carcare_service/features/schedules/data/schedule_repository.dart';
import 'package:carcare_service/features/schedules/domain/schedule.dart';
import 'package:carcare_service/features/schedules/domain/schedules_repository.dart';
import 'package:carcare_service/features/schedules/presentation/schedule_dates.dart';

/// Presentation state for the employee×day schedule grid — P6-F4.
///
/// Owns navigation (week/month toggle, prev/next/today), the employee search
/// and branch filter, the loaded [ScheduleGrid], and a rectangular
/// tap-tap [SelectionController] over cell keys (`"userId|YYYY-MM-DD"`) for
/// the bulk-edit flow — no mouse drag, per the slice brief. The grid itself
/// (not [SelectionController], which is geometry-agnostic by design — see
/// its own doc comment) computes which cells lie between two tapped corners,
/// since only the grid knows its own row/column order.
class ScheduleGridController extends ChangeNotifier {
  ScheduleGridController({SchedulesRepository? repo, Duration? searchDebounce})
    : _repo = repo ?? RemoteSchedulesRepository(),
      searchDebounce = searchDebounce ?? defaultSearchDebounce;

  static const Duration defaultSearchDebounce = Duration(milliseconds: 350);

  final Duration searchDebounce;
  final SchedulesRepository _repo;
  Timer? _searchTimer;
  int _generation = 0;
  bool _disposed = false;

  final SelectionController<String> selection = SelectionController<String>();

  AsyncValue<ScheduleGrid> gridState = const AsyncLoading();
  String view = 'week'; // 'week' | 'month'
  DateTime anchorDate = dateOnly(DateTime.now());
  String? branchId;
  String _query = '';

  String get query => _query;
  bool get canEdit => gridState.valueOrNull?.canEdit ?? false;
  ScheduleGrid? get grid => gridState.valueOrNull;
  SchedulesRepository get repository => _repo;

  static String cellKey(String userId, String date) => '$userId|$date';

  (String userId, String date) parseCellKey(String key) {
    final i = key.indexOf('|');
    return (key.substring(0, i), key.substring(i + 1));
  }

  Future<void> load() async {
    final requestGeneration = ++_generation;
    gridState = const AsyncLoading();
    notifyListeners();
    final result = await _repo.getGrid(
      query: ScheduleGridQuery(
        view: view,
        date: ymd(anchorDate),
        branchId: branchId,
        q: _query.isEmpty ? null : _query,
      ),
    );
    if (_disposed || requestGeneration != _generation) return;
    switch (result) {
      case Ok(:final value):
        gridState = AsyncData(value);
      case Err(:final error):
        gridState = AsyncError(error);
    }
    notifyListeners();
  }

  Future<void> refresh() => load();

  void setView(String next) {
    if (next == view) return;
    view = next;
    load();
  }

  void goToday() {
    anchorDate = dateOnly(DateTime.now());
    load();
  }

  void nextPeriod() {
    anchorDate = view == 'month'
        ? addMonths(anchorDate, 1)
        : anchorDate.add(const Duration(days: 7));
    load();
  }

  void prevPeriod() {
    anchorDate = view == 'month'
        ? addMonths(anchorDate, -1)
        : anchorDate.subtract(const Duration(days: 7));
    load();
  }

  void setBranch(String? id) {
    if (id == branchId) return;
    branchId = id;
    load();
  }

  void setQuery(String value) {
    _query = value.trim();
    _searchTimer?.cancel();
    notifyListeners();
    _searchTimer = Timer(searchDebounce, () {
      if (!_disposed) unawaited(load());
    });
  }

  // ─── Selection / rectangular range ───────────────────────────────────────

  void enterSelectionMode() => selection.enter();

  void exitSelectionMode() => selection.clear();

  /// Individual toggle — long-press on a cell, or a plain tap while already
  /// mid-range-gesture is not in progress and the caller wants a single-cell
  /// flip rather than starting a range.
  void toggleCell(String userId, String date) =>
      selection.toggle(cellKey(userId, date));

  /// Tap-tap range: first call anchors the range, the second call (a
  /// different cell) computes the full rectangle between the two corners
  /// using the grid's own row/column order and commits it. A repeated tap on
  /// the same anchor cancels the pending range instead of selecting a
  /// single-cell "rectangle" silently, which would surprise a user expecting
  /// a plain toggle.
  void onRangeTap(String userId, String date) {
    final key = cellKey(userId, date);
    final anchor = selection.rangeAnchor;
    if (anchor == null) {
      selection.beginRange(key);
      return;
    }
    if (anchor == key) {
      selection.cancelRange();
      return;
    }
    final rect = rectangleBetween(anchor, key);
    selection.extendRange(rect);
    selection.endRange();
  }

  /// The full rectangle of cell keys between [anchorKey] and [endKey],
  /// inclusive, using the currently loaded grid's row order (employees) and
  /// column order (dates). Returns just the two keys if the grid is not
  /// loaded (defensive — the UI should never allow a tap before then).
  Set<String> rectangleBetween(String anchorKey, String endKey) {
    final g = grid;
    if (g == null) return {anchorKey, endKey};
    final (anchorUser, anchorDate) = parseCellKey(anchorKey);
    final (endUser, endDateStr) = parseCellKey(endKey);
    final rowIds = g.rows.map((r) => r.id).toList(growable: false);
    final dates = g.dates;
    final r1 = rowIds.indexOf(anchorUser);
    final r2 = rowIds.indexOf(endUser);
    final c1 = dates.indexOf(anchorDate);
    final c2 = dates.indexOf(endDateStr);
    if (r1 < 0 || r2 < 0 || c1 < 0 || c2 < 0) return {anchorKey, endKey};
    final rowLo = r1 <= r2 ? r1 : r2;
    final rowHi = r1 <= r2 ? r2 : r1;
    final colLo = c1 <= c2 ? c1 : c2;
    final colHi = c1 <= c2 ? c2 : c1;
    final out = <String>{};
    for (var r = rowLo; r <= rowHi; r++) {
      for (var c = colLo; c <= colHi; c++) {
        out.add(cellKey(rowIds[r], dates[c]));
      }
    }
    return out;
  }

  // ─── Bulk targets (rectangular selection → server contract) ─────────────

  /// The distinct [Weekday]s among the currently selected cells, in a fixed
  /// Monday-Sunday order (not encounter order) so the weekday-scope
  /// explanation reads the same regardless of tap order — parity with
  /// `schedule-grid.tsx`'s `BulkShiftEditor` weekday-scope radio label,
  /// which lists every weekday the selection touches.
  Set<Weekday> distinctWeekdaysForSelection() {
    final out = <Weekday>{};
    for (final key in selection.selected) {
      final (_, date) = parseCellKey(key);
      final parsed = DateTime.tryParse(date);
      if (parsed != null) out.add(weekdayOf(parsed));
    }
    return out;
  }

  static const List<Weekday> _weekOrder = [
    Weekday.mon,
    Weekday.tue,
    Weekday.wed,
    Weekday.thu,
    Weekday.fri,
    Weekday.sat,
    Weekday.sun,
  ];

  /// [distinctWeekdaysForSelection] ordered Monday-first for display.
  List<Weekday> orderedDistinctWeekdaysForSelection() => _weekOrder
      .where(distinctWeekdaysForSelection().contains)
      .toList(growable: false);

  /// Builds the `POST /employee-schedules/bulk` `targets` for the current
  /// selection under [scope] — mirrors `schedule-grid.tsx`'s
  /// `bulkTargets`/`bulkUpsertEmployeeShiftCommand` split exactly:
  /// * `date` scope — one target per selected cell, carrying its own date.
  /// * `weekday` scope — one target per distinct `(userId, weekday)` pair,
  ///   **deduped** so a rectangular selection spanning several weeks never
  ///   sends the same user×weekday rule twice (the server would also dedupe
  ///   this itself — see that command's `seen` set — but a client sending
  ///   the same target twice would otherwise double-count `applied`).
  List<ScheduleBulkTarget> bulkTargets(ScheduleScope scope) {
    if (scope == ScheduleScope.date) {
      return selection.selected
          .map(parseCellKey)
          .map((t) => ScheduleBulkTarget(userId: t.$1, date: t.$2))
          .toList(growable: false);
    }
    final seen = <String>{};
    final targets = <ScheduleBulkTarget>[];
    for (final key in selection.selected) {
      final (userId, date) = parseCellKey(key);
      final parsed = DateTime.tryParse(date);
      if (parsed == null) continue;
      final weekday = weekdayOf(parsed);
      if (seen.add('$userId#${weekday.wire}')) {
        targets.add(ScheduleBulkTarget(userId: userId, weekday: weekday));
      }
    }
    return targets;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _searchTimer?.cancel();
    selection.dispose();
    super.dispose();
  }
}
