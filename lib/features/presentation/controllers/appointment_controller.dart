import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/presentation/data/repository/appointment_repository.dart';
import 'package:carcare_service/features/models/appointment.dart';
import 'package:carcare_service/shared/widgets/dialogs/message.dart';
import 'package:flutter/material.dart';

class AppointmentController extends ChangeNotifier {
  AppointmentController({AppointmentRepository? repo}) : _repo = repo ?? AppointmentRepository();

  final AppointmentRepository _repo;

  AsyncValue<List<AppointmentSummary>> listState = const AsyncLoading();

  // key: 'YYYY-MM-DD', value: appointment count
  Map<String, int> monthCounts = {};

  DateTime _selectedDate = DateTime.now();
  AppointmentStatus? _statusFilter;
  String? selectedBranchId;

  DateTime get selectedDate => _selectedDate;
  AppointmentStatus? get statusFilter => _statusFilter;

  List<AppointmentSummary> get filtered {
    final list = listState.valueOrNull ?? [];
    if (_statusFilter == null) return list;
    return list.where((a) => a.status == _statusFilter).toList();
  }

  // ─── Date navigation ───────────────────────────────────────────────────────

  void setDate(DateTime d) {
    _selectedDate = d;
    notifyListeners();
    loadAppointments();
  }

  void prevDay() => setDate(_selectedDate.subtract(const Duration(days: 1)));
  void nextDay() => setDate(_selectedDate.add(const Duration(days: 1)));

  void goToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_selectedDate != today) setDate(today);
  }

  // ─── Status filter ─────────────────────────────────────────────────────────

  void setStatusFilter(AppointmentStatus? s) {
    _statusFilter = s;
    notifyListeners();
  }

  void setBranch(String? branchId) {
    selectedBranchId = branchId;
    loadAppointments();
  }

  // ─── Month counts ──────────────────────────────────────────────────────────

  Future<void> loadMonthCounts(int year, int month) async {
    final result = await _repo.getMonthCounts(year: year, month: month, branchId: selectedBranchId);
    if (result case Ok(:final value)) {
      monthCounts = {...monthCounts, ...value};
      notifyListeners();
    }
  }

  // ─── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadAppointments() async {
    listState = const AsyncLoading();
    notifyListeners();
    final result = await _repo.getAppointments(date: _selectedDate, branchId: selectedBranchId);
    listState = switch (result) {
      Ok(:final value) => AsyncData(value),
      Err(:final error) => AsyncError(error),
    };
    notifyListeners();
  }

  // ─── Mutations ─────────────────────────────────────────────────────────────

  Future<bool> updateStatus(String id, AppointmentStatus status) async {
    final result = await _repo.updateStatus(id, status);
    switch (result) {
      case Ok(:final value):
        final current = listState.valueOrNull ?? [];
        listState = AsyncData(current.map((a) => a.id == id ? value : a).toList());
        notifyListeners();
        return true;
      case Err(:final error):
        messageError(error.display);
        return false;
    }
  }
}
