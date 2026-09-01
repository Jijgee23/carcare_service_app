import 'dart:async';

import 'package:flutter/material.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/services/diagnostic_service.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/models/appointment.dart';
import 'package:carcare_service/features/models/diagnostic.dart';
import 'package:carcare_service/features/presentation/data/repository/appointment_repository.dart';
import 'package:carcare_service/shared/widgets/dialogs/message.dart';

class CreateAppointmentController extends ChangeNotifier {
  CreateAppointmentController({AppointmentRepository? repo})
      : _repo = repo ?? AppointmentRepository();

  final AppointmentRepository _repo;

  // ─── Form state ────────────────────────────────────────────────────────────

  DateTime requestedAt = _defaultRequestedAt();
  BranchSummary? selectedBranch;
  CustomerSummary? selectedCustomer;
  VehicleSummary? selectedVehicle;
  bool isWalkIn = false;
  bool submitting = false;

  // ─── Branch ────────────────────────────────────────────────────────────────

  List<BranchSummary> branches = [];
  bool loadingBranches = true;

  // ─── Customer search ───────────────────────────────────────────────────────

  List<CustomerSummary> customerResults = [];
  bool searchingCustomer = false;
  Timer? _customerTimer;

  // ─── Vehicle search ────────────────────────────────────────────────────────

  List<VehicleSummary> vehicleResults = [];
  bool searchingVehicle = false;
  Timer? _vehicleTimer;

  // ─── Text controllers ──────────────────────────────────────────────────────

  final customerSearchCtrl = TextEditingController();
  final vehicleSearchCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final walkInPhoneCtrl = TextEditingController();
  final walkInNameCtrl = TextEditingController();

  // ─── Computed ──────────────────────────────────────────────────────────────

  bool get canSubmit {
    if (selectedBranch == null) return false;
    if (isWalkIn) return walkInPhoneCtrl.text.trim().isNotEmpty;
    return selectedCustomer != null;
  }

  // ─── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    walkInPhoneCtrl.addListener(notifyListeners);
    final list = await DiagnosticService.getBranches();
    branches = list;
    final branchId = Authenticator.user?.branchId;
    if (branchId != null) {
      try {
        selectedBranch = list.firstWhere((b) => b.id == branchId);
      } catch (_) {
        selectedBranch = list.isNotEmpty ? list.first : null;
      }
    } else if (list.isNotEmpty) {
      selectedBranch = list.first;
    }
    loadingBranches = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _customerTimer?.cancel();
    _vehicleTimer?.cancel();
    walkInPhoneCtrl.removeListener(notifyListeners);
    customerSearchCtrl.dispose();
    vehicleSearchCtrl.dispose();
    noteCtrl.dispose();
    walkInPhoneCtrl.dispose();
    walkInNameCtrl.dispose();
    super.dispose();
  }

  // ─── Date/time ─────────────────────────────────────────────────────────────

  void setRequestedAt(DateTime dt) {
    requestedAt = dt;
    notifyListeners();
  }

  // ─── Branch ────────────────────────────────────────────────────────────────

  void selectBranch(BranchSummary b) {
    selectedBranch = b;
    notifyListeners();
  }

  // ─── Customer ──────────────────────────────────────────────────────────────

  void searchCustomer(String q) {
    _customerTimer?.cancel();
    if (q.trim().isEmpty) {
      customerResults = [];
      notifyListeners();
      return;
    }
    _customerTimer = Timer(const Duration(milliseconds: 400), () async {
      searchingCustomer = true;
      notifyListeners();
      final results = await DiagnosticService.searchCustomers(q.trim());
      customerResults = results;
      searchingCustomer = false;
      notifyListeners();
    });
  }

  void selectCustomer(CustomerSummary c) {
    selectedCustomer = c;
    isWalkIn = false;
    customerResults = [];
    customerSearchCtrl.clear();
    notifyListeners();
  }

  void clearCustomer() {
    selectedCustomer = null;
    selectedVehicle = null;
    vehicleResults = [];
    customerSearchCtrl.clear();
    vehicleSearchCtrl.clear();
    notifyListeners();
  }

  void setWalkIn(bool v) {
    isWalkIn = v;
    if (v) {
      selectedCustomer = null;
      customerResults = [];
      customerSearchCtrl.clear();
    } else {
      walkInPhoneCtrl.clear();
      walkInNameCtrl.clear();
    }
    notifyListeners();
  }

  // ─── Vehicle ───────────────────────────────────────────────────────────────

  void searchVehicle(String q) {
    _vehicleTimer?.cancel();
    if (q.trim().isEmpty) {
      vehicleResults = [];
      notifyListeners();
      return;
    }
    _vehicleTimer = Timer(const Duration(milliseconds: 400), () async {
      searchingVehicle = true;
      notifyListeners();
      final results = await DiagnosticService.searchVehicles(q.trim());
      vehicleResults = results;
      searchingVehicle = false;
      notifyListeners();
    });
  }

  void selectVehicle(VehicleSummary v) {
    selectedVehicle = v;
    vehicleResults = [];
    vehicleSearchCtrl.clear();
    if (selectedCustomer == null && v.customer != null && !isWalkIn) {
      selectedCustomer = v.customer;
    }
    notifyListeners();
  }

  void clearVehicle() {
    selectedVehicle = null;
    vehicleSearchCtrl.clear();
    notifyListeners();
  }

  // ─── Submit ────────────────────────────────────────────────────────────────

  Future<AppointmentSummary?> submit() async {
    if (!canSubmit) return null;
    submitting = true;
    notifyListeners();

    final result = await _repo.createAppointment(
      branchId: selectedBranch!.id,
      requestedAt: requestedAt,
      customerId: selectedCustomer?.id,
      vehicleId: selectedVehicle?.id,
      phone: isWalkIn ? walkInPhoneCtrl.text.trim() : null,
      name: isWalkIn && walkInNameCtrl.text.trim().isNotEmpty
          ? walkInNameCtrl.text.trim()
          : null,
      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
    );

    submitting = false;
    notifyListeners();

    switch (result) {
      case Ok(:final value):
        return value;
      case Err(:final error):
        messageError(error.display);
        return null;
    }
  }

  static DateTime _defaultRequestedAt() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour + 1, 0);
  }
}
