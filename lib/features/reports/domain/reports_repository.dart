import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/reports/domain/report.dart';

/// Server-side filters for `GET /api/v1/reports` and
/// `GET /api/v1/reports/export` — both optional, `YYYY-MM-DD`. Measured
/// against `validateReportRangeParams` (`lib/reports.ts`): if either is
/// present both must parse, `from <= to`, span at most 366 days. Absent
/// both, the server defaults to "this month" (`parseRange`'s default) — this
/// class does not replicate that default locally, the server is
/// authoritative.
class ReportRangeQuery {
  final String? from;
  final String? to;

  const ReportRangeQuery({this.from, this.to});
}

/// One frozen repository contract for the Reports feature — P7-F1.
///
/// Branch scoping is header-driven (`X-Working-Branch`, `resolveWorkingBranch`
/// on the server), same as every other Phase 6/7 mobile contract — neither
/// method takes a branch id directly.
///
/// Errors a caller must expect:
/// * `401` — no code, auth required only (D-174).
/// * `422 VALIDATION` — bad range params, carries `fieldErrors`.
abstract interface class ReportsRepository {
  /// `GET /api/v1/reports?from&to`.
  Future<Result<ReportResult>> getReport({ReportRangeQuery? query});

  /// `GET /api/v1/reports/export?from&to` — the same `.xlsx` workbook the
  /// web export route builds (D-175), returned as bytes plus a resolved
  /// filename for the share sheet. Both bounds are required here (unlike
  /// [getReport]): a caller with no explicit range should read [getReport]'s
  /// resolved `range` first and export that exact span, so the file always
  /// names the period it actually covers.
  Future<Result<ReportExportFile>> exportReport({
    required String from,
    required String to,
  });
}
