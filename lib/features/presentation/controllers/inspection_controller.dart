import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/presentation/data/repository/diagnostic_repository.dart';
import 'package:carcare_service/features/models/diagnostic.dart';
import 'package:flutter/material.dart';

class InspectionController extends ChangeNotifier {
  InspectionController({DiagnosticRepository? repo}) : _repo = repo ?? DiagnosticRepository();

  final DiagnosticRepository _repo;

  List<DiagnosticReportSummary> _reports = [];
  bool loading = false;
  bool loadingMore = false;
  bool _hasNext = false;
  int _page = 1;
  int _total = 0;
  String? error;

  List<DiagnosticReportSummary> get reports => _reports;
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
      _reports = result.items;
      _hasNext = result.pagination.hasNext;
      _total = result.pagination.total;
    } catch (e) {
      error = e.toString();
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
      _reports = [..._reports, ...result.items];
      _page = result.pagination.page;
      _hasNext = result.pagination.hasNext;
      _total = result.pagination.total;
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  void prependReport(DiagnosticReportSummary report) {
    _reports = [report, ..._reports];
    _total++;
    notifyListeners();
  }

  /// Removes a report from the loaded list after a successful server delete.
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
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}
