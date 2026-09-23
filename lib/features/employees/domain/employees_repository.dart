import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/employees/domain/employee.dart';

/// Server-side filters supported by `GET /api/v1/employees`, measured
/// against `app/api/v1/employees/route.ts`. The route rejects any
/// unlisted query key with a 422 (`rejectUnknownParams`), so this class stays
/// a closed allow-list mirroring `ALLOWED_PARAMS` exactly: `q`, `branchId`,
/// `roleId`, `active`, `page`, `pageSize`.
class EmployeeListQuery {
  final String? q;
  final String? branchId;
  final String? roleId;

  /// `?active=yes|no` — `null` sends neither and returns both.
  final bool? active;
  final int page;
  final int pageSize;

  const EmployeeListQuery({
    this.q,
    this.branchId,
    this.roleId,
    this.active,
    this.page = 1,
    this.pageSize = 50,
  });
}

/// `meta` block on `GET /api/v1/employees` — branch chip counts (stable,
/// independent of the current filter) and the tenant's active role labels.
class EmployeeListMeta {
  final List<EmployeeBranchChip> branches;
  final List<EmployeeRoleOption> roles;

  const EmployeeListMeta({this.branches = const [], this.roles = const []});
}

/// The full `GET /api/v1/employees` response — the paged rows plus the
/// filter-independent `meta` block, returned together since a single call
/// produces both and a screen needs both to render its chips.
class EmployeePage {
  final PagedResult<Employee> page;
  final EmployeeListMeta meta;

  const EmployeePage({required this.page, required this.meta});
}

/// One frozen repository contract for the Employees feature — P6-F1.
///
/// `PATCH /api/v1/employees/[id]` is a **whole-record replace**, matching
/// the `PATCH /services/[id]` / `PATCH /vehicles/[id]` convention this
/// codebase already uses: [updateEmployee] takes the complete editable
/// record so no caller can silently clear a field by omitting it. `roleId`
/// cannot move an *owner* — the server returns `OWNER_ROLE_LOCKED` (409) for
/// that target regardless of what this method sends; `isOwner` itself is
/// not part of this method's signature at all (the route contract excludes
/// it from PATCH — only [createEmployee] can set it, and only for a caller
/// who is themselves an owner).
///
/// Errors a caller must expect and cannot prevent locally, surfaced as
/// `Err(AppError)` with `statusCode`/`code`/`fieldErrors` preserved by the
/// shared `mapDioException`:
/// * `403` — `employees.view`/`.create`/`.edit`/`.delete` as appropriate,
///   `SUBSCRIPTION_EXPIRED`, or `PLAN_LIMIT_REACHED` ([createEmployee]).
/// * `404 NOT_FOUND` — no row for this tenant.
/// * `409` — `OWNER_ROLE_LOCKED` / `SELF_DEACTIVATE` / `SELF_ACTION` /
///   `LAST_OWNER` / `FK_CONFLICT` (delete of a referenced row).
/// * `422 VALIDATION` / `DUPLICATE` — carries `fieldErrors`.
abstract interface class EmployeesRepository {
  /// `GET /api/v1/employees` — the paged rows and the `meta` block together,
  /// since one call produces both.
  Future<Result<EmployeePage>> getEmployees({EmployeeListQuery? query});

  /// `GET /api/v1/employees/[id]`.
  Future<Result<Employee>> getEmployee(String employeeId);

  /// `POST /api/v1/employees`. `isOwner: true` is honoured by the server
  /// only when the caller is itself an owner; sending it as a non-owner is
  /// not rejected client-side — the server enforces this and returns the
  /// created row with `isOwner: false` in that case.
  Future<Result<Employee>> createEmployee({
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
  });

  /// `PATCH /api/v1/employees/[id]` — whole-record replace. See the class
  /// doc comment: every editable field is a required or explicitly-sent
  /// argument, and an omitted optional one is sent as `null`/absent and
  /// clears the stored value.
  Future<Result<Employee>> updateEmployee(
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
  });

  /// `DELETE /api/v1/employees/[id]`. Blocked (409) for self, the last
  /// active owner, or a row with an FK reference the server maps to a
  /// friendly `FK_CONFLICT` message.
  Future<Result<EmployeeIdResult>> deleteEmployee(String employeeId);

  /// `POST /api/v1/employees/[id]/toggle-active`. [isActive] is the desired
  /// next state, mirroring the web form's checkbox semantics. Blocked (409)
  /// for self-deactivation and for the last active owner.
  Future<Result<EmployeeToggleResult>> toggleActive(
    String employeeId, {
    required bool isActive,
  });

  /// `POST /api/v1/employees/[id]/reset-password`. Never generates or
  /// returns a password — it only invalidates the current credential,
  /// forcing OTP re-activation on next login. Blocked (409 `SELF_ACTION`)
  /// against oneself.
  Future<Result<EmployeeIdResult>> resetPassword(String employeeId);

  /// `POST /api/v1/employees/bulk` — per-row role/branch reassignment, never
  /// all-or-nothing. At least one of [roleId]/[branchId] and at least one
  /// [employeeIds] entry is required; violating either is a whole-request
  /// 422, never reflected in the returned [EmployeeBulkResult].
  Future<Result<EmployeeBulkResult>> bulkUpdateRoleBranch({
    required List<String> employeeIds,
    String? roleId,
    String? branchId,
  });
}
