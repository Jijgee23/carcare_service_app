/// Employees domain model — P6-F1.
///
/// Measured against `carcare.mn` after `P6-B0`/`P6-B2`:
/// * `app/api/v1/employees/route.ts` (GET list, POST create),
/// * `app/api/v1/employees/[id]/route.ts` (GET/PATCH/DELETE),
/// * `app/api/v1/employees/[id]/toggle-active/route.ts`,
/// * `app/api/v1/employees/[id]/reset-password/route.ts`,
/// * `app/api/v1/employees/bulk/route.ts`,
/// * `lib/employees/dto.ts` (`toEmployeeDto`, explicit-whitelist — never
///   emits `passwordHash`/OTP/lock fields).
///
/// `id` is the only structurally-required field on [Employee] — everything
/// else degrades to `null`/a safe default rather than throwing, matching the
/// Services/Diagnostics idiom (`P4-F1`). [EmployeeParseException] is thrown
/// only when a response cannot be used at all (see `employee_dto.dart`).
library;

class EmployeeParseException implements Exception {
  const EmployeeParseException(this.message);
  final String message;

  @override
  String toString() => 'EmployeeParseException: $message';
}

/// `meta.branches[]` entry on `GET /api/v1/employees` — the tenant's active
/// branches with a stable (filter-independent) employee count, plus the
/// synthetic `id: ""` "Хуваарилагдаагүй" chip when unassigned count > 0.
class EmployeeBranchChip {
  final String id;
  final String? name;
  final int count;

  const EmployeeBranchChip({required this.id, this.name, this.count = 0});

  factory EmployeeBranchChip.fromJson(Map<String, dynamic> j) =>
      EmployeeBranchChip(
        id: _optString(j['id']) ?? '',
        name: _optString(j['name']),
        count: _optInt(j['count']) ?? 0,
      );

  /// `id == ""` marks the synthetic "unassigned" chip — there is no real
  /// branch row behind it.
  bool get isUnassigned => id.isEmpty;
}

/// `meta.roles[]` entry on `GET /api/v1/employees` — for building the
/// role-label filter/picker. Distinct from the full `RoleDto`
/// (`features/roles`) — this is only `{id, name}`.
class EmployeeRoleOption {
  final String id;
  final String? name;

  const EmployeeRoleOption({required this.id, this.name});

  factory EmployeeRoleOption.fromJson(Map<String, dynamic> j) =>
      EmployeeRoleOption(id: _reqString(j, 'id'), name: _optString(j['name']));
}

/// One tenant employee row — the shape `toEmployeeDto` builds, used
/// identically by list, detail, create, and update responses.
///
/// Structurally cannot carry `passwordHash`, failed-login counters, lock
/// state, or OTP material: this class's `fromJson` never reads any of those
/// keys, mirroring the server DTO's explicit whitelist (Phase 6 invariant:
/// "no response ever carries a secret field").
class Employee {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final bool isOwner;
  final String? roleId;
  final String? roleName;
  final bool isActive;
  final DateTime? activeUntil;
  final String? tenantId;
  final String? branchId;
  final List<String> assignableBranchIds;

  /// Whether the employee has completed OTP activation. Not a secret itself
  /// — unlike the fields this class deliberately never models.
  final bool verified;

  const Employee({
    required this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.isOwner = false,
    this.roleId,
    this.roleName,
    this.isActive = true,
    this.activeUntil,
    this.tenantId,
    this.branchId,
    this.assignableBranchIds = const [],
    this.verified = false,
  });

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
    id: _reqString(j, 'id'),
    firstName: _optString(j['firstName']),
    lastName: _optString(j['lastName']),
    email: _optString(j['email']),
    phone: _optString(j['phone']),
    isOwner: _optBool(j['isOwner']) ?? false,
    roleId: _optString(j['roleId']),
    roleName: _optString(j['roleName']),
    isActive: _optBool(j['isActive']) ?? true,
    activeUntil: _optDate(j['activeUntil']),
    tenantId: _optString(j['tenantId']),
    branchId: _optString(j['branchId']),
    assignableBranchIds: _stringList(j['assignableBranchIds']),
    verified: _optBool(j['verified']) ?? false,
  );

  /// `"Овог Нэр"`, or whichever half is present, or a placeholder — never
  /// empty, so a list row always renders something.
  String get displayName {
    final hasFirst = firstName != null && firstName!.isNotEmpty;
    final hasLast = lastName != null && lastName!.isNotEmpty;
    if (hasLast && hasFirst) return '$lastName $firstName';
    if (hasFirst) return firstName!;
    if (hasLast) return lastName!;
    return 'Нэргүй';
  }
}

/// `DELETE /api/v1/employees/[id]`, `POST /reset-password` — both
/// `{employee:{id}}`.
class EmployeeIdResult {
  final String id;
  const EmployeeIdResult({required this.id});

  factory EmployeeIdResult.fromJson(Map<String, dynamic> j) =>
      EmployeeIdResult(id: _reqString(j, 'id'));
}

/// `POST /api/v1/employees/[id]/toggle-active` — `{employee:{id,isActive}}`.
class EmployeeToggleResult {
  final String id;
  final bool isActive;
  const EmployeeToggleResult({required this.id, this.isActive = false});

  factory EmployeeToggleResult.fromJson(Map<String, dynamic> j) =>
      EmployeeToggleResult(
        id: _reqString(j, 'id'),
        isActive: _optBool(j['isActive']) ?? false,
      );
}

/// `POST /api/v1/employees/bulk` — `{succeeded, failed, errors}`. Per-row,
/// never all-or-nothing: a 200 always carries this shape, even when every
/// row failed — the per-row reasons are display strings only, with no
/// structural link back to which id failed.
class EmployeeBulkResult {
  final int succeeded;
  final int failed;
  final List<String> errors;

  const EmployeeBulkResult({
    this.succeeded = 0,
    this.failed = 0,
    this.errors = const [],
  });

  factory EmployeeBulkResult.fromJson(Map<String, dynamic> j) {
    final errors = j['errors'];
    return EmployeeBulkResult(
      succeeded: _optInt(j['succeeded']) ?? 0,
      failed: _optInt(j['failed']) ?? 0,
      errors: errors is List
          ? errors.whereType<String>().toList(growable: false)
          : const [],
    );
  }
}

// ─── Parse helpers ─────────────────────────────────────────────────────────

String _reqString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw EmployeeParseException('$key талбар буруу байна.');
  }
  return value.trim();
}

String? _optString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool? _optBool(Object? value) => value is bool ? value : null;

int? _optInt(Object? value) {
  if (value is int) return value;
  if (value is double) {
    return value == value.roundToDouble() ? value.toInt() : null;
  }
  if (value is String) return int.tryParse(value.trim());
  return null;
}

DateTime? _optDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toLocal();
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}
