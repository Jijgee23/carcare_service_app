import 'package:carservice_business/core/errors/app_error.dart';
import 'package:carservice_business/core/utils/result.dart';
import 'package:carservice_business/features/reports/domain/report.dart';
import 'package:carservice_business/features/reports/domain/reports_repository.dart';

/// Hand-written fake for [ReportsRepository] — P7-F1, for later widget
/// tests (`P7-F2`). Mirrors `FakeEmployeeRepository`'s pattern.
class FakeReportsRepository implements ReportsRepository {
  FakeReportsRepository({this.data = const ReportData(totalRevenue: 100)});

  ReportData data;
  int getCalls = 0;
  int exportCalls = 0;
  bool failExport = false;

  @override
  Future<Result<ReportResult>> getReport({ReportRangeQuery? query}) async {
    getCalls++;
    return Ok(
      ReportResult(
        range: const ReportRange(label: 'Энэ сар', key: 'this-month'),
        data: data,
      ),
    );
  }

  @override
  Future<Result<ReportExportFile>> exportReport({
    required String from,
    required String to,
  }) async {
    exportCalls++;
    if (failExport) {
      return const Err(
        AppError(ErrorKind.unknown, 'Экспортлож чадсангүй', statusCode: 500),
      );
    }
    return Ok(
      ReportExportFile(
        bytes: const [1, 2, 3],
        filename: 'tailan_${from}_$to.xlsx',
      ),
    );
  }
}
