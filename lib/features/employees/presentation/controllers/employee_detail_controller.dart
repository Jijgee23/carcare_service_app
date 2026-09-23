import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/employees/data/employee_repository.dart';
import 'package:carcare_service/features/employees/domain/employee.dart';
import 'package:carcare_service/features/employees/domain/employees_repository.dart';

/// Owns one employee's detail fetch (by id), toggle-active, reset-password
/// and delete — P6-F2. Mirrors `CustomerDetailController`'s
/// generation-guarded load and `mutating`/`lastError` shape for actions.
///
/// Every mutation returns the raw [Result] to its caller (so a screen can
/// show a per-action confirmation/snackbar with the exact server message
/// and `code`) *and* updates [detailState] in place on success, so the
/// screen never has to reload the whole record after e.g. a toggle.
class EmployeeDetailController extends ChangeNotifier {
  EmployeeDetailController({
    required this.employeeId,
    EmployeesRepository? repo,
  }) : _repo = repo ?? RemoteEmployeesRepository();

  final String employeeId;
  final EmployeesRepository _repo;

  EmployeesRepository get repository => _repo;

  int _generation = 0;
  bool _disposed = false;

  AsyncValue<Employee> detailState = const AsyncLoading();

  bool mutating = false;
  AppError? lastError;

  Employee? get employee => detailState.valueOrNull;

  Future<void> load() async {
    final generation = ++_generation;
    detailState = const AsyncLoading();
    notifyListeners();
    final result = await _repo.getEmployee(employeeId);
    if (_disposed || generation != _generation) return;
    switch (result) {
      case Ok(:final value):
        detailState = AsyncData(value);
      case Err(:final error):
        detailState = AsyncError(error);
    }
    notifyListeners();
  }

  Future<void> refresh() => load();

  Future<Result<EmployeeToggleResult>> toggleActive(bool isActive) async {
    mutating = true;
    lastError = null;
    notifyListeners();
    final result = await _repo.toggleActive(employeeId, isActive: isActive);
    if (_disposed) return result;
    switch (result) {
      case Ok(:final value):
        final current = employee;
        if (current != null) {
          detailState = AsyncData(_withActive(current, value.isActive));
        }
      case Err(:final error):
        lastError = error;
    }
    mutating = false;
    notifyListeners();
    return result;
  }

  /// Never returns/reveals a password — see `EmployeesRepository.
  /// resetPassword`'s doc comment. Only invalidates the credential so the
  /// employee re-activates via OTP on next login.
  Future<Result<EmployeeIdResult>> resetPassword() async {
    mutating = true;
    lastError = null;
    notifyListeners();
    final result = await _repo.resetPassword(employeeId);
    if (_disposed) return result;
    if (result case Err(:final error)) lastError = error;
    mutating = false;
    notifyListeners();
    return result;
  }

  Future<Result<EmployeeIdResult>> delete() async {
    mutating = true;
    lastError = null;
    notifyListeners();
    final result = await _repo.deleteEmployee(employeeId);
    if (_disposed) return result;
    if (result case Err(:final error)) lastError = error;
    mutating = false;
    notifyListeners();
    return result;
  }

  Employee _withActive(Employee e, bool isActive) => Employee(
    id: e.id,
    firstName: e.firstName,
    lastName: e.lastName,
    email: e.email,
    phone: e.phone,
    isOwner: e.isOwner,
    roleId: e.roleId,
    roleName: e.roleName,
    isActive: isActive,
    activeUntil: e.activeUntil,
    tenantId: e.tenantId,
    branchId: e.branchId,
    assignableBranchIds: e.assignableBranchIds,
    verified: e.verified,
  );

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
