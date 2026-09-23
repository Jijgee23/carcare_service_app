import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/employees/domain/employee.dart';
import 'package:carcare_service/features/employees/domain/employees_repository.dart';

/// Hand-written fake for [EmployeesRepository] — P6-F1, for later widget
/// tests (`P6-F2`). Mirrors the server guards this repository binds to:
///
/// * self-deactivate/self-delete/self-reset-password are all blocked
///   (`SELF_DEACTIVATE`/`SELF_ACTION`);
/// * the last active owner cannot be deactivated or deleted (`LAST_OWNER`);
/// * an owner's role cannot be changed (`OWNER_ROLE_LOCKED`);
/// * a duplicate email/phone is a 409-style `DUPLICATE`;
/// * bulk role/branch is per-row, never all-or-nothing.
class FakeEmployeeRepository implements EmployeesRepository {
  FakeEmployeeRepository({List<Employee>? seed, this.currentUserId = 'u-self'})
    : _employees = [
        ...(seed ?? [seedEmployee(), seedOwner()]),
      ];

  final List<Employee> _employees;

  /// The id [EmployeesRepository] treats as "the caller" for the
  /// self-action guards.
  final String currentUserId;

  int listCalls = 0;

  static Employee seedEmployee({
    String id = 'u-1',
    String firstName = 'Бат',
    String lastName = 'Дорж',
    String? roleId = 'role-1',
    String? roleName = 'Механик',
    String? branchId = 'b-1',
    bool isActive = true,
    bool isOwner = false,
  }) => Employee(
    id: id,
    firstName: firstName,
    lastName: lastName,
    email: '$id@example.com',
    phone: '9900${id.hashCode.abs() % 10000}',
    isOwner: isOwner,
    roleId: roleId,
    roleName: roleName,
    isActive: isActive,
    branchId: branchId,
    verified: true,
  );

  static Employee seedOwner({String id = 'u-self'}) => Employee(
    id: id,
    firstName: 'Эзэмшигч',
    lastName: 'Админ',
    email: 'owner@example.com',
    phone: '99000000',
    isOwner: true,
    isActive: true,
    verified: true,
  );

  int _indexOf(String id) => _employees.indexWhere((e) => e.id == id);

  AppError _notFound() => const AppError(
    ErrorKind.notFound,
    'Ажилтан олдсонгүй.',
    statusCode: 404,
    code: 'NOT_FOUND',
  );

  bool _matchesSearch(Employee e, String q) {
    final lower = q.toLowerCase();
    bool ci(String? v) => v != null && v.toLowerCase().contains(lower);
    return ci(e.firstName) || ci(e.lastName) || ci(e.email) || ci(e.phone);
  }

  @override
  Future<Result<EmployeePage>> getEmployees({EmployeeListQuery? query}) async {
    listCalls++;
    final q = query ?? const EmployeeListQuery();
    var rows = _employees.toList();
    if (q.branchId != null && q.branchId!.isNotEmpty) {
      rows = rows.where((e) => e.branchId == q.branchId).toList();
    }
    if (q.roleId != null && q.roleId!.isNotEmpty) {
      rows = rows.where((e) => e.roleId == q.roleId).toList();
    }
    if (q.active != null) {
      rows = rows.where((e) => e.isActive == q.active).toList();
    }
    final term = q.q?.trim();
    if (term != null && term.isNotEmpty) {
      rows = rows.where((e) => _matchesSearch(e, term)).toList();
    }

    final total = rows.length;
    final totalPages = (total / q.pageSize).ceil().clamp(1, 1 << 30);
    final page = q.page.clamp(1, totalPages);
    final skip = (page - 1) * q.pageSize;
    final items = rows.skip(skip).take(q.pageSize).toList(growable: false);

    final branchCounts = <String, int>{};
    for (final e in _employees) {
      final key = e.branchId ?? '';
      branchCounts[key] = (branchCounts[key] ?? 0) + 1;
    }
    final branches = branchCounts.entries
        .map(
          (e) => EmployeeBranchChip(
            id: e.key,
            name: e.key.isEmpty ? 'Хуваарилагдаагүй' : 'Салбар ${e.key}',
            count: e.value,
          ),
        )
        .toList(growable: false);
    final roles = _employees
        .where((e) => e.roleId != null)
        .map((e) => EmployeeRoleOption(id: e.roleId!, name: e.roleName))
        .toSet()
        .toList(growable: false);

    return Ok(
      EmployeePage(
        page: PagedResult(
          items: items,
          pagination: PaginationMeta(
            page: page,
            pageSize: q.pageSize,
            total: total,
            totalPages: totalPages,
            hasPrev: page > 1,
            hasNext: page < totalPages,
          ),
        ),
        meta: EmployeeListMeta(branches: branches, roles: roles),
      ),
    );
  }

  @override
  Future<Result<Employee>> getEmployee(String employeeId) async {
    final index = _indexOf(employeeId);
    if (index < 0) return Err(_notFound());
    return Ok(_employees[index]);
  }

  @override
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
  }) async {
    if (_employees.any((e) => e.email == email || e.phone == phone)) {
      return Err(
        const AppError(
          ErrorKind.unknown,
          'Энэ имэйл/утас өөр хэрэглэгчид бүртгэлтэй байна.',
          statusCode: 422,
          code: 'DUPLICATE',
          fieldErrors: {'email': 'Давхардсан утга.'},
        ),
      );
    }
    // Only an owner caller may create another owner — mirrors
    // `prepareCreateEmployee`'s server-side gate.
    final caller = _employees.firstWhere(
      (e) => e.id == currentUserId,
      orElse: () => seedOwner(id: currentUserId),
    );
    final grantOwner = isOwner && caller.isOwner;

    final created = Employee(
      id: 'u-${_employees.length + 1}',
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      roleId: grantOwner ? null : roleId,
      branchId: branchId,
      assignableBranchIds: assignableBranchIds,
      isActive: isActive,
      activeUntil: activeUntil,
      isOwner: grantOwner,
      verified: false,
    );
    _employees.add(created);
    return Ok(created);
  }

  @override
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
  }) async {
    final index = _indexOf(employeeId);
    if (index < 0) return Err(_notFound());
    final current = _employees[index];

    if (current.isOwner && roleId != current.roleId) {
      return Err(
        const AppError(
          ErrorKind.unknown,
          'Эзэмшигчийн үүргийг өөрчлөх боломжгүй.',
          statusCode: 409,
          code: 'OWNER_ROLE_LOCKED',
        ),
      );
    }
    if (_employees.any(
      (e) => e.id != employeeId && (e.email == email || e.phone == phone),
    )) {
      return Err(
        const AppError(
          ErrorKind.unknown,
          'Энэ имэйл/утас өөр хэрэглэгчид бүртгэлтэй байна.',
          statusCode: 422,
          code: 'DUPLICATE',
          fieldErrors: {'email': 'Давхардсан утга.'},
        ),
      );
    }

    final updated = Employee(
      id: current.id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      isOwner: current.isOwner,
      roleId: current.isOwner ? current.roleId : roleId,
      roleName: current.roleName,
      branchId: branchId,
      assignableBranchIds: assignableBranchIds,
      isActive: isActive,
      activeUntil: activeUntil,
      tenantId: current.tenantId,
      verified: current.verified,
    );
    _employees[index] = updated;
    return Ok(updated);
  }

  @override
  Future<Result<EmployeeIdResult>> deleteEmployee(String employeeId) async {
    final index = _indexOf(employeeId);
    if (index < 0) return Err(_notFound());
    if (employeeId == currentUserId) {
      return Err(
        const AppError(
          ErrorKind.unknown,
          'Өөрийгөө устгах боломжгүй.',
          statusCode: 409,
          code: 'SELF_ACTION',
        ),
      );
    }
    final current = _employees[index];
    if (current.isOwner && _activeOwnerCount() <= 1) {
      return Err(
        const AppError(
          ErrorKind.unknown,
          'Сүүлийн идэвхтэй эзэмшигчийг устгах боломжгүй.',
          statusCode: 409,
          code: 'LAST_OWNER',
        ),
      );
    }
    _employees.removeAt(index);
    return Ok(EmployeeIdResult(id: current.id));
  }

  int _activeOwnerCount() =>
      _employees.where((e) => e.isOwner && e.isActive).length;

  @override
  Future<Result<EmployeeToggleResult>> toggleActive(
    String employeeId, {
    required bool isActive,
  }) async {
    final index = _indexOf(employeeId);
    if (index < 0) return Err(_notFound());
    if (!isActive && employeeId == currentUserId) {
      return Err(
        const AppError(
          ErrorKind.unknown,
          'Өөрийгөө идэвхгүй болгох боломжгүй.',
          statusCode: 409,
          code: 'SELF_DEACTIVATE',
        ),
      );
    }
    final current = _employees[index];
    if (!isActive && current.isOwner && _activeOwnerCount() <= 1) {
      return Err(
        const AppError(
          ErrorKind.unknown,
          'Сүүлийн идэвхтэй эзэмшигчийг идэвхгүй болгох боломжгүй.',
          statusCode: 409,
          code: 'LAST_OWNER',
        ),
      );
    }
    _employees[index] = Employee(
      id: current.id,
      firstName: current.firstName,
      lastName: current.lastName,
      email: current.email,
      phone: current.phone,
      isOwner: current.isOwner,
      roleId: current.roleId,
      roleName: current.roleName,
      isActive: isActive,
      activeUntil: current.activeUntil,
      tenantId: current.tenantId,
      branchId: current.branchId,
      assignableBranchIds: current.assignableBranchIds,
      verified: current.verified,
    );
    return Ok(EmployeeToggleResult(id: current.id, isActive: isActive));
  }

  @override
  Future<Result<EmployeeIdResult>> resetPassword(String employeeId) async {
    final index = _indexOf(employeeId);
    if (index < 0) return Err(_notFound());
    if (employeeId == currentUserId) {
      return Err(
        const AppError(
          ErrorKind.unknown,
          'Өөрийн нууц үгийг дахин тохируулах боломжгүй.',
          statusCode: 409,
          code: 'SELF_ACTION',
        ),
      );
    }
    final current = _employees[index];
    _employees[index] = Employee(
      id: current.id,
      firstName: current.firstName,
      lastName: current.lastName,
      email: current.email,
      phone: current.phone,
      isOwner: current.isOwner,
      roleId: current.roleId,
      roleName: current.roleName,
      isActive: current.isActive,
      activeUntil: current.activeUntil,
      tenantId: current.tenantId,
      branchId: current.branchId,
      assignableBranchIds: current.assignableBranchIds,
      verified: false,
    );
    return Ok(EmployeeIdResult(id: current.id));
  }

  @override
  Future<Result<EmployeeBulkResult>> bulkUpdateRoleBranch({
    required List<String> employeeIds,
    String? roleId,
    String? branchId,
  }) async {
    if (employeeIds.isEmpty) {
      return Err(
        const AppError(
          ErrorKind.unknown,
          'Дор хаяж нэг ажилтан сонгоно уу.',
          statusCode: 422,
          code: 'VALIDATION',
        ),
      );
    }
    var succeeded = 0;
    final errors = <String>[];
    for (final id in employeeIds) {
      final index = _indexOf(id);
      if (index < 0) {
        errors.add('$id: Олдсонгүй.');
        continue;
      }
      final current = _employees[index];
      if (current.isOwner) {
        errors.add('$id: Эзэмшигчийг өөрчлөх боломжгүй.');
        continue;
      }
      _employees[index] = Employee(
        id: current.id,
        firstName: current.firstName,
        lastName: current.lastName,
        email: current.email,
        phone: current.phone,
        isOwner: current.isOwner,
        roleId: roleId ?? current.roleId,
        roleName: current.roleName,
        isActive: current.isActive,
        activeUntil: current.activeUntil,
        tenantId: current.tenantId,
        branchId: branchId ?? current.branchId,
        assignableBranchIds: current.assignableBranchIds,
        verified: current.verified,
      );
      succeeded++;
    }
    return Ok(
      EmployeeBulkResult(
        succeeded: succeeded,
        failed: errors.length,
        errors: errors,
      ),
    );
  }
}
