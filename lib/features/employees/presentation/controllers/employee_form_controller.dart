import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/employees/data/employee_repository.dart';
import 'package:carcare_service/features/employees/domain/employee.dart';
import 'package:carcare_service/features/employees/domain/employees_repository.dart';

/// Create/edit form submission for one employee — P6-F2.
///
/// `PATCH /employees/[id]` is a whole-record replace (see
/// `EmployeesRepository.updateEmployee`'s doc comment): [submitUpdate]
/// always sends every editable field explicitly, never a partial diff, so
/// a caller cannot accidentally clear a field by omitting it. `roleId` is
/// still sent for an owner target — the server silently keeps the owner's
/// role regardless (`OWNER_ROLE_LOCKED` only fires if the *value differs*
/// from what the row already holds in some server paths; this client never
/// tries to special-case that locally beyond disabling the picker — see the
/// form screen's owner handling).
///
/// `isOwner` is accepted only by [submitCreate] — the frozen contract
/// excludes it from the PATCH signature entirely (an owner's flag cannot be
/// changed through this form at all, matching the web form).
class EmployeeFormController extends ChangeNotifier {
  EmployeeFormController({EmployeesRepository? repo})
    : _repo = repo ?? RemoteEmployeesRepository();

  final EmployeesRepository _repo;
  bool submitting = false;

  Future<Result<Employee>> submitCreate({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    String? roleId,
    String? branchId,
    List<String> assignableBranchIds = const [],
    bool isActive = true,
    DateTime? activeUntil,
    bool isOwner = false,
  }) async {
    submitting = true;
    notifyListeners();
    final result = await _repo.createEmployee(
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      roleId: roleId,
      branchId: branchId,
      assignableBranchIds: assignableBranchIds,
      isActive: isActive,
      activeUntil: activeUntil,
      isOwner: isOwner,
    );
    submitting = false;
    notifyListeners();
    return result;
  }

  Future<Result<Employee>> submitUpdate(
    String employeeId, {
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    String? roleId,
    String? branchId,
    List<String> assignableBranchIds = const [],
    bool isActive = true,
    DateTime? activeUntil,
  }) async {
    submitting = true;
    notifyListeners();
    final result = await _repo.updateEmployee(
      employeeId,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      roleId: roleId,
      branchId: branchId,
      assignableBranchIds: assignableBranchIds,
      isActive: isActive,
      activeUntil: activeUntil,
    );
    submitting = false;
    notifyListeners();
    return result;
  }
}
