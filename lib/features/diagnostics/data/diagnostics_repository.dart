import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/diagnostics/data/diagnostic_dto.dart';
import 'package:carcare_service/features/diagnostics/data/diagnostics_data_source.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostic.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:dio/dio.dart';

class DiagnosticsRepositoryImpl
    implements DiagnosticTemplateRepository, DiagnosticReportRepository {
  DiagnosticsRepositoryImpl(this._source);
  final DiagnosticsDataSource _source;

  Future<Result<T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Ok(await run());
    } on AppError catch (e) {
      return Err(e);
    } on DiagnosticParseException catch (e) {
      return Err(AppError(ErrorKind.unknown, e.message));
    } catch (_) {
      return const Err(
        AppError(
          ErrorKind.unknown,
          'Оношилгооны мэдээлэл авахад алдаа гарлаа.',
        ),
      );
    }
  }

  @override
  Future<Result<List<DiagnosticTemplateSummary>>> getTemplates() => _guard(
    () async =>
        DiagnosticTemplateListDto.fromJson(await _source.getTemplates()).items,
  );
  @override
  Future<Result<DiagnosticTemplateDetail>> getTemplate(String id) => _guard(
    () async =>
        DiagnosticTemplateEnvelopeDto.fromJson(await _source.getTemplate(id))
            .value,
  );
  @override
  Future<Result<DiagnosticTemplateSummary>> createTemplate(
    Map<String, dynamic> body,
  ) => _guard(
    () async => DiagnosticTemplateSummaryDto.fromJson(
      _mapTemplate(await _source.createTemplate(body)),
    ).value,
  );
  @override
  Future<Result<DiagnosticTemplateSummary>> updateTemplate(
    String id,
    Map<String, dynamic> body,
  ) => _guard(
    () async => DiagnosticTemplateSummaryDto.fromJson(
      _mapTemplate(await _source.updateTemplate(id, body)),
    ).value,
  );
  @override
  Future<Result<void>> deleteTemplate(String id) => _guard(() async {
    await _source.deleteTemplate(id);
  });
  @override
  Future<Result<DiagnosticTemplateSummary>> duplicateTemplate(String id) =>
      _guard(
        () async => DiagnosticTemplateSummaryDto.fromJson(
          _mapTemplate(await _source.duplicateTemplate(id)),
        ).value,
      );
  @override
  Future<Result<PagedResult<DiagnosticReportSummary>>> getReports({
    bool filledByMe = false,
    String? vehicleId,
    String? customerId,
    int page = 1,
    int pageSize = 30,
  }) => _guard(() async {
    final query = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      if (filledByMe) 'filledByMe': true,
      if (vehicleId != null) 'vehicleId': vehicleId,
      if (customerId != null) 'customerId': customerId,
    };
    final dto = DiagnosticReportPageDto.fromJson(
      await _source.getReports(query),
    );
    return PagedResult(items: dto.items, pagination: dto.pagination);
  });
  @override
  Future<Result<DiagnosticReportDetail>> getReport(String id) => _guard(
    () async => DiagnosticReportDetailDto.fromJson(
      _mapReport(await _source.getReport(id)),
    ).value,
  );
  @override
  Future<Result<String>> createReport(FormData formData) => _guard(
    () async =>
        DiagnosticReportIdDto.fromJson(await _source.createReport(formData)).id,
  );
  @override
  Future<Result<void>> deleteReport(String id) => _guard(() async {
    await _source.deleteReport(id);
  });
  @override
  Future<Result<List<int>>> getPdfBytes(String id) => _guard(() async {
    final bytes = await _source.getPdfBytes(id);
    if (bytes is List<int>) return bytes;
    throw const AppError(ErrorKind.unknown, 'PDF хариуны формат буруу байна.');
  });
}

Object? _mapTemplate(Object? raw) => raw is Map ? raw['template'] : null;
Object? _mapReport(Object? raw) => raw is Map ? raw['report'] : null;
