import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/overview/domain/overview.dart';
import 'package:carcare_service/features/overview/domain/overview_repository.dart';

/// Hand-written fake for [OverviewRepository] — P7-F1, for later widget
/// tests (`P7-F4`, home screen retirement of `AnalyticsScreen`).
class FakeOverviewRepository implements OverviewRepository {
  FakeOverviewRepository({
    this.overview = const Overview(
      counts: OverviewCounts(branches: 1, employees: 2, customers: 3),
    ),
  });

  Overview overview;
  int getCalls = 0;

  @override
  Future<Result<Overview>> getOverview({OverviewRangeQuery? query}) async {
    getCalls++;
    return Ok(overview);
  }
}
