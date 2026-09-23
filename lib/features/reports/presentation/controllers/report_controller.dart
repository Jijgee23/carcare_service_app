import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/reports/data/report_repository.dart';
import 'package:carcare_service/features/reports/domain/report.dart';
import 'package:carcare_service/features/reports/domain/reports_repository.dart';
import 'package:carcare_service/features/reports/presentation/report_ranges.dart';

/// Presentation state for the Reports screen — P7-F2.
///
/// Copies `MyScheduleController`'s generation-guarded load shape. The range
/// is resolved locally (mirroring the web's `quickBounds`) purely so the
/// UI can highlight the active quick-range chip and pre-fill the
/// date-range picker; the server remains authoritative for what the range
/// actually covers (`ReportRangeQuery`'s doc comment) — [export] always
/// prefers the server-resolved `range` on the loaded [ReportResult] over
/// the locally-computed bounds, so the exported file always names the
/// period the data actually came from.
class ReportController extends ChangeNotifier {
  ReportController({ReportsRepository? repo, DateTime? now})
    : _repo = repo ?? RemoteReportsRepository() {
    final bounds = reportQuickBounds(
      ReportQuickRange.thisMonth,
      now ?? DateTime.now(),
    );
    _quickKey = ReportQuickRange.thisMonth;
    _from = bounds.from;
    _to = bounds.to;
  }

  final ReportsRepository _repo;
  int _generation = 0;
  bool _disposed = false;

  AsyncValue<ReportResult> state = const AsyncLoading();
  bool exporting = false;

  late ReportQuickRange _quickKey;
  late DateTime _from;
  late DateTime _to;

  ReportQuickRange get quickKey => _quickKey;
  DateTime get from => _from;
  DateTime get to => _to;

  Future<void> load() async {
    final requestGeneration = ++_generation;
    state = const AsyncLoading();
    notifyListeners();

    final result = await _repo.getReport(
      query: ReportRangeQuery(from: reportYmd(_from), to: reportYmd(_to)),
    );
    if (_disposed || requestGeneration != _generation) return;
    switch (result) {
      case Ok(:final value):
        state = AsyncData(value);
      case Err(:final error):
        state = AsyncError(error);
    }
    notifyListeners();
  }

  Future<void> refresh() => load();

  /// Quick-range chip tap. `custom` is not selectable this way — the screen
  /// opens a date-range picker and calls [setCustomRange] instead.
  Future<void> setQuickRange(ReportQuickRange key) {
    if (key == ReportQuickRange.custom) return Future.value();
    final bounds = reportQuickBounds(key, DateTime.now());
    _quickKey = key;
    _from = bounds.from;
    _to = bounds.to;
    return load();
  }

  Future<void> setCustomRange(DateTime from, DateTime to) {
    _quickKey = ReportQuickRange.custom;
    _from = reportDateOnly(from);
    _to = reportDateOnly(to);
    return load();
  }

  /// `GET /api/v1/reports/export` for the currently loaded range. Returns
  /// the [Result] to the caller (the screen) rather than triggering the
  /// share sheet itself — sharing is a platform side effect that belongs in
  /// the widget layer, exactly as `ReportDetailScreen._exportPdf` splits it.
  Future<Result<ReportExportFile>> export() async {
    exporting = true;
    notifyListeners();
    final resolvedRange = state.valueOrNull?.range;
    final fromStr = resolvedRange?.from != null
        ? reportYmd(resolvedRange!.from!)
        : reportYmd(_from);
    final toStr = resolvedRange?.to != null
        ? reportYmd(resolvedRange!.to!)
        : reportYmd(_to);
    final result = await _repo.exportReport(from: fromStr, to: toStr);
    if (!_disposed) {
      exporting = false;
      notifyListeners();
    }
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
