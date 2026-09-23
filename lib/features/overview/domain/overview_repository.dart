import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/overview/domain/overview.dart';

/// Optional income-range picker params for `GET /api/v1/overview` — mirrors
/// the web dashboard's `resolveIncomeRange`; omitted entirely, the server
/// applies its own default. This class does not validate locally, matching
/// [ReportRangeQuery]'s sibling in `features/reports`.
class OverviewRangeQuery {
  final String? range;
  final String? from;
  final String? to;

  const OverviewRangeQuery({this.range, this.from, this.to});
}

/// One frozen repository contract for the Overview feature — P7-F1.
///
/// Branch scoping is header-driven (`X-Working-Branch`), matching every
/// other Phase 6/7 mobile contract.
///
/// Errors a caller must expect:
/// * `401` — no code, auth required only.
/// * `422 VALIDATION` — an unknown query param (should not happen from this
///   client, since [OverviewRangeQuery] only ever sends the allow-listed
///   three).
abstract interface class OverviewRepository {
  /// `GET /api/v1/overview`.
  Future<Result<Overview>> getOverview({OverviewRangeQuery? query});
}
