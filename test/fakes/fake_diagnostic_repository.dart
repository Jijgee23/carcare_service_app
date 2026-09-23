import 'package:carcare_service/core/domain/diagnostic.dart';
import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/diagnostics/data/diagnostic_repository.dart';
import 'package:dio/dio.dart';

/// Hand-written fake for [DiagnosticRepository] (concrete class, no
/// abstract interface — see `fake_order_repository.dart` for why this
/// extends rather than implements).
///
/// Note the real repository's list/detail methods return plain values
/// (`null`/empty on failure) rather than `Result`, unlike orders/
/// appointments/notifications — this fake matches that asymmetry rather
/// than "fixing" it, since normalising it is a `lib/` change outside this
/// slice's scope (flagged in the P0-F4 report).
class FakeDiagnosticRepository extends DiagnosticRepository {
  static final _template = DiagnosticTemplateDetail(
    id: 'tpl-1',
    name: 'Ерөнхий үзлэг',
    type: DiagnosticType.ROUTINE,
    version: 1,
    isActive: true,
    updatedAt: DateTime(2026, 1, 1),
    schema: const TemplateSchema(
      sections: [
        TemplateSection(
          id: 'sec-1',
          title: 'Тоормос',
          items: [
            TemplateItem(id: 'item-1', label: 'Тоормосны наклад', type: ItemType.check, required: true),
          ],
        ),
      ],
    ),
  );

  final List<DiagnosticReportSummary> _reports = [
    DiagnosticReportSummary(
      id: 'report-1',
      createdAt: DateTime(2026, 1, 5),
      templateVersion: 1,
      template: const ReportTemplateSummary(id: 'tpl-1', name: 'Ерөнхий үзлэг', type: DiagnosticType.ROUTINE),
      customer: const CustomerSummary(id: 'cust-1', fullName: 'Бат', phone: '99001122'),
      vehicle: const VehicleSummary(id: 'veh-1', plate: '1234ABC', make: 'Toyota', model: 'Prius'),
      branch: const BranchSummary(id: 'branch-1', name: 'Толгойт салбар'),
    ),
  ];

  @override
  Future<List<DiagnosticTemplateSummary>> getTemplates() async => [_template];

  @override
  Future<DiagnosticTemplateDetail?> getTemplateDetail(String id) async =>
      id == _template.id ? _template : null;

  @override
  Future<PagedResult<DiagnosticReportSummary>> getReports({
    bool filledByMe = false,
    String? vehicleId,
    String? customerId,
    int page = 1,
    int pageSize = 30,
  }) async {
    final filtered = _reports.where((r) {
      if (vehicleId != null && r.vehicle.id != vehicleId) return false;
      if (customerId != null && r.customer.id != customerId) return false;
      return true;
    }).toList();
    return PagedResult(
      items: filtered,
      pagination: PaginationMeta(
        page: page,
        pageSize: pageSize,
        total: filtered.length,
        totalPages: 1,
        hasPrev: false,
        hasNext: false,
      ),
    );
  }

  @override
  Future<Result<void>> deleteReport(String id) async {
    final existed = _reports.any((r) => r.id == id);
    if (!existed) return const Err(AppError(ErrorKind.notFound, 'Тайлан олдсонгүй'));
    _reports.removeWhere((r) => r.id == id);
    return const Ok(null);
  }

  @override
  Future<DiagnosticReportDetail?> getReportDetail(String id) async {
    final found = _reports.where((r) => r.id == id);
    if (found.isEmpty) return null;
    final r = found.first;
    return DiagnosticReportDetail(
      id: r.id,
      createdAt: r.createdAt,
      templateVersion: r.templateVersion,
      mileageAtReport: r.mileageAtReport,
      orderId: r.orderId,
      data: const {},
      template: _template,
      customer: r.customer,
      vehicle: r.vehicle,
      branch: r.branch,
      filledBy: r.filledBy,
    );
  }

  @override
  Future<Result<DiagnosticTemplateSummary>> createTemplate({
    required String name,
    String? description,
    required DiagnosticType type,
    bool isActive = true,
    double? price,
    int? durationMin,
    required List<Map<String, dynamic>> sections,
  }) async {
    return Ok(
      DiagnosticTemplateSummary(
        id: 'tpl-${_reports.length + 1}',
        name: name,
        description: description,
        type: type,
        version: 1,
        isActive: isActive,
        price: price,
        durationMin: durationMin,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Ignores [formData]'s actual content — `apiOrThrow`'s `dio.post` shortcut
  /// isn't exercised by this fake; returns a stable id as the real endpoint
  /// would on success.
  @override
  Future<String?> submitReport(FormData formData) async => 'report-fake-1';
}
