import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostic.dart';
import 'package:dio/dio.dart';

abstract interface class DiagnosticTemplateRepository {
  /// Active templates by default — what a report or an order picks from.
  /// The management list passes [includeInactive].
  Future<Result<List<DiagnosticTemplateSummary>>> getTemplates({
    bool includeInactive = false,
  });
  Future<Result<DiagnosticTemplateDetail>> getTemplate(String id);
  Future<Result<DiagnosticTemplateSummary>> createTemplate(
    Map<String, dynamic> body,
  );
  Future<Result<DiagnosticTemplateSummary>> updateTemplate(
    String id,
    Map<String, dynamic> body,
  );
  Future<Result<TemplateDeleteOutcome>> deleteTemplate(String id);
  Future<Result<DiagnosticTemplateSummary>> duplicateTemplate(String id);
}

abstract interface class DiagnosticReportRepository {
  Future<Result<PagedResult<DiagnosticReportSummary>>> getReports({
    bool filledByMe,
    String? vehicleId,
    String? customerId,
    int page,
    int pageSize,
  });
  Future<Result<DiagnosticReportDetail>> getReport(String id);
  Future<Result<String>> createReport(FormData formData);
  Future<Result<void>> deleteReport(String id);
  Future<Result<List<int>>> getPdfBytes(String id);
}
