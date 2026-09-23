import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/reports/data/report_dto.dart';
import 'package:carcare_service/features/reports/data/reports_data_source.dart';
import 'package:carcare_service/features/reports/domain/report.dart';
import 'package:carcare_service/features/reports/domain/reports_repository.dart';

/// Remote adapter for [ReportsRepository] — P7-F1.
class RemoteReportsRepository implements ReportsRepository {
  RemoteReportsRepository({ReportsDataSource? dataSource})
    : _dataSource = dataSource ?? RemoteReportsDataSource();

  final ReportsDataSource _dataSource;

  @override
  Future<Result<ReportResult>> getReport({ReportRangeQuery? query}) async {
    final effective = query ?? const ReportRangeQuery();
    try {
      return Ok(
        ReportResultDto.fromJson(
          await _dataSource.get({
            if (effective.from != null && effective.from!.isNotEmpty)
              'from': effective.from,
            if (effective.to != null && effective.to!.isNotEmpty)
              'to': effective.to,
          }),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Тайлан ачаалж чадсангүй'));
    }
  }

  @override
  Future<Result<ReportExportFile>> exportReport({
    required String from,
    required String to,
  }) async {
    try {
      final raw = await _dataSource.export({'from': from, 'to': to});
      return Ok(
        ReportExportFile(
          bytes: raw.bytes,
          filename: _filename(raw.contentDisposition, from, to),
        ),
      );
    } catch (error) {
      return Err(_error(error, 'Тайлан экспортлож чадсангүй'));
    }
  }
}

/// Parses `filename="..."` (optionally `filename*=UTF-8''...`) out of a
/// `Content-Disposition` header. Falls back to
/// `tailan_<from>_<to>.xlsx` — matching `lib/reports-export.ts`'s
/// `reportExportFilename` — when the header is absent or unparsable.
String _filename(String? contentDisposition, String from, String to) {
  final fallback = 'tailan_${from}_$to.xlsx';
  if (contentDisposition == null || contentDisposition.isEmpty) {
    return fallback;
  }
  final starMatch = RegExp(
    "filename\\*=UTF-8''([^;]+)",
    caseSensitive: false,
  ).firstMatch(contentDisposition);
  if (starMatch != null) {
    final raw = starMatch.group(1)?.trim();
    if (raw != null && raw.isNotEmpty) {
      try {
        return Uri.decodeComponent(raw);
      } catch (_) {
        // Fall through to the plain `filename=` form below.
      }
    }
  }
  final match = RegExp(
    'filename="?([^";]+)"?',
    caseSensitive: false,
  ).firstMatch(contentDisposition);
  final name = match?.group(1)?.trim();
  return (name == null || name.isEmpty) ? fallback : name;
}

AppError _error(Object error, String fallback) => switch (error) {
  AppError value => value,
  ReportParseException value => AppError(ErrorKind.unknown, value.message),
  _ => AppError(ErrorKind.unknown, fallback),
};
