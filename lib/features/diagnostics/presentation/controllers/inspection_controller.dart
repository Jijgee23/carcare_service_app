import 'package:carcare_service/core/domain/diagnostic.dart' as legacy;
import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/diagnostics/data/diagnostics_data_source.dart';
import 'package:carcare_service/features/diagnostics/data/diagnostics_repository.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostic.dart'
    as typed;
import 'package:carcare_service/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:flutter/material.dart';

class InspectionController extends ChangeNotifier {
  InspectionController({DiagnosticReportRepository? repo})
    : _repo = repo ?? DiagnosticsRepositoryImpl(RemoteDiagnosticsDataSource());

  final DiagnosticReportRepository _repo;
  List<legacy.DiagnosticReportSummary> _reports = [];
  bool loading = false;
  bool loadingMore = false;
  bool _hasNext = false;
  int _page = 1;
  int _total = 0;
  String? error;

  List<legacy.DiagnosticReportSummary> get reports => _reports;
  bool get hasNext => _hasNext;
  int get total => _total;
  int get todayCount => _reports.where((r) => _isToday(r.createdAt)).length;

  Future<void> loadReports() async {
    if (loading) return;
    _page = 1;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _repo.getReports(page: 1);
      switch (result) {
        case Ok(:final value):
          _reports = value.items.map(_legacySummary).toList();
          _hasNext = value.pagination.hasNext;
          _total = value.pagination.total;
        case Err(:final error):
          this.error = error.display;
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (loadingMore || !_hasNext) return;
    loadingMore = true;
    notifyListeners();
    try {
      final result = await _repo.getReports(page: _page + 1);
      switch (result) {
        case Ok(:final value):
          _reports = [..._reports, ...value.items.map(_legacySummary)];
          _page = value.pagination.page;
          _hasNext = value.pagination.hasNext;
          _total = value.pagination.total;
        case Err(:final error):
          this.error = error.display;
      }
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  void prependReport(legacy.DiagnosticReportSummary report) {
    _reports = [report, ..._reports];
    _total++;
    notifyListeners();
  }

  void removeReport(String id) {
    final before = _reports.length;
    _reports = _reports.where((r) => r.id != id).toList();
    if (_reports.length != before && _total > 0) _total--;
    notifyListeners();
  }

  Future<Result<void>> deleteReport(String id) async {
    final result = await _repo.deleteReport(id);
    if (result case Ok()) removeReport(id);
    return result;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

legacy.DiagnosticReportSummary _legacySummary(
  typed.DiagnosticReportSummary r,
) => legacy.DiagnosticReportSummary(
  id: r.id,
  createdAt: r.createdAt ?? DateTime(2000),
  templateVersion: r.templateVersion,
  mileageAtReport: r.mileageAtReport,
  orderId: r.orderId,
  template: legacy.ReportTemplateSummary(
    id: r.template.id,
    name: r.template.name,
    type: legacy.DiagnosticType.values.firstWhere(
      (e) => e.name == r.template.type.name,
      orElse: () => legacy.DiagnosticType.ROUTINE,
    ),
  ),
  customer: legacy.CustomerSummary(
    id: r.customer.id,
    fullName: r.customer.fullName,
    phone: r.customer.phone,
    email: r.customer.email,
  ),
  vehicle: legacy.VehicleSummary(
    id: r.vehicle.id,
    plate: r.vehicle.plate,
    vin: r.vehicle.vin,
    make: r.vehicle.make,
    model: r.vehicle.model,
    year: r.vehicle.year,
    mileage: r.vehicle.mileage,
    customerId: r.vehicle.customerId,
  ),
  branch: legacy.BranchSummary(
    id: r.branch.id,
    name: r.branch.name,
    address: r.branch.address,
  ),
  filledBy: r.filledBy == null
      ? null
      : legacy.UserSummary(
          id: r.filledBy!.id,
          firstName: r.filledBy!.firstName,
          lastName: r.filledBy!.lastName,
        ),
);
