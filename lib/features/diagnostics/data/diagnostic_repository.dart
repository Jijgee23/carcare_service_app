import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/domain/diagnostic.dart';
import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:dio/dio.dart';

class DiagnosticRepository {
  // ─── Templates ─────────────────────────────────────────────────────────────

  Future<List<DiagnosticTemplateSummary>> getTemplates() async {
    final res = await api(Api.get, 'diagnostics/templates');
    if (res == null) return [];
    final list = res.data['templates'] as List;
    return list
        .map(
          (e) => DiagnosticTemplateSummary.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  Future<DiagnosticTemplateDetail?> getTemplateDetail(String id) async {
    final res = await api(Api.get, 'diagnostics/templates/$id');
    if (res == null) return null;
    return DiagnosticTemplateDetail.fromJson(
      res.data['template'] as Map<String, dynamic>,
    );
  }

  // ─── Reports ───────────────────────────────────────────────────────────────

  Future<PagedResult<DiagnosticReportSummary>> getReports({
    bool filledByMe = false,
    String? vehicleId,
    String? customerId,
    int page = 1,
    int pageSize = 30,
  }) async {
    final q = [
      'page=$page',
      'pageSize=$pageSize',
      if (filledByMe) 'filledByMe=true',
      if (vehicleId != null) 'vehicleId=$vehicleId',
      if (customerId != null) 'customerId=$customerId',
    ].join('&');
    final res = await api(Api.get, 'diagnostics/reports?$q');
    if (res == null) {
      return PagedResult(
        items: [],
        pagination: PaginationMeta.empty(page, pageSize),
      );
    }
    final list = res.data['reports'] as List;
    final meta = PaginationMeta.fromJson(
      res.data['pagination'] as Map<String, dynamic>,
    );
    return PagedResult(
      items: list
          .map(
            (e) => DiagnosticReportSummary.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      pagination: meta,
    );
  }

  Future<Result<void>> deleteReport(String id) async {
    try {
      await apiOrThrow(Api.delete, 'diagnostics/reports/$id');
      return const Ok(null);
    } on AppError catch (e) {
      return Err(e);
    }
  }

  Future<DiagnosticReportDetail?> getReportDetail(String id) async {
    final res = await api(Api.get, 'diagnostics/reports/$id');
    if (res == null) return null;
    return DiagnosticReportDetail.fromJson(
      res.data['report'] as Map<String, dynamic>,
    );
  }

  // ─── Create template ──────────────────────────────────────────────────────

  Future<Result<DiagnosticTemplateSummary>> createTemplate({
    required String name,
    String? description,
    required DiagnosticType type,
    bool isActive = true,
    double? price,
    int? durationMin,
    required List<Map<String, dynamic>> sections,
  }) async {
    try {
      final res = await apiOrThrow(
        Api.post,
        'diagnostics/templates',
        body: {
          'name': name,
          if (description != null && description.isNotEmpty)
            'description': description,
          'type': type.name,
          'isActive': isActive,
          'price': ?price,
          'durationMin': ?durationMin,
          'schema': {'sections': sections},
        },
      );
      return Ok(
        DiagnosticTemplateSummary.fromJson(
          res.data['template'] as Map<String, dynamic>,
        ),
      );
    } on AppError catch (e) {
      return Err(e);
    }
  }

  // FormData нь api() helper-ийн Map<String,dynamic> type-тай нийцэхгүй
  // тул dio-г шууд дуудна.
  Future<String?> submitReport(FormData formData) async {
    try {
      final res = await ApiService.instance.dio.post(
        'diagnostics/reports',
        data: formData,
      );
      if (res.statusCode == 201 && res.data != null) {
        return res.data['report']['id'] as String?;
      }
    } on DioException catch (e) {
      final msg =
          e.response?.data?['error']?.toString() ??
          'Тайлан илгээхэд алдаа гарлаа';
      messageError(msg);
    }
    return null;
  }
}
