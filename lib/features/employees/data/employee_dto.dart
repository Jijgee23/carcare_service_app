/// Envelope parsing for Employees — P6-F1. Field-level tolerance lives on
/// the domain models (`employee.dart`); this file only unwraps the
/// top-level response envelopes and enforces the handful of structurally
/// required pieces.
library;

import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/features/employees/domain/employee.dart';
import 'package:carcare_service/features/employees/domain/employees_repository.dart';

typedef JsonMap = Map<String, dynamic>;

JsonMap _map(Object? value, String label) {
  if (value is! Map) throw EmployeeParseException('$label буруу байна.');
  return Map<String, dynamic>.from(value);
}

int _requiredInt(JsonMap json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw EmployeeParseException('$key буруу байна.');
}

bool _requiredBool(JsonMap json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw EmployeeParseException('$key буруу байна.');
}

PaginationMeta _pagination(Object? raw) {
  final json = _map(raw, 'pagination');
  final page = _requiredInt(json, 'page');
  final pageSize = _requiredInt(json, 'pageSize');
  final total = _requiredInt(json, 'total');
  final totalPages = _requiredInt(json, 'totalPages');
  if (page < 1 || pageSize < 1 || total < 0 || totalPages < 0) {
    throw const EmployeeParseException('Хуудаслалтын мэдээлэл буруу байна.');
  }
  return PaginationMeta(
    page: page,
    pageSize: pageSize,
    total: total,
    totalPages: totalPages,
    hasPrev: _requiredBool(json, 'hasPrev'),
    hasNext: _requiredBool(json, 'hasNext'),
  );
}

EmployeeListMeta _meta(Object? raw) {
  if (raw is! Map) return const EmployeeListMeta();
  final json = Map<String, dynamic>.from(raw);
  final branches = json['branches'];
  final roles = json['roles'];
  return EmployeeListMeta(
    branches: branches is List
        ? branches
              .whereType<Map>()
              .map(
                (b) =>
                    EmployeeBranchChip.fromJson(Map<String, dynamic>.from(b)),
              )
              .toList(growable: false)
        : const [],
    roles: roles is List
        ? roles
              .whereType<Map>()
              .map(
                (r) =>
                    EmployeeRoleOption.fromJson(Map<String, dynamic>.from(r)),
              )
              .toList(growable: false)
        : const [],
  );
}

/// `GET /api/v1/employees` — `{employees:[...], pagination, meta}`.
///
/// A non-map entry in `employees` is skipped rather than throwing; a row
/// whose `id` is missing still throws — an employee with no id cannot be
/// opened, edited or deleted, and silently dropping it would hide a real
/// server defect behind a short list.
class EmployeePageDto {
  const EmployeePageDto(this.value);
  final EmployeePage value;

  factory EmployeePageDto.fromJson(Object? raw) {
    final json = _map(raw, 'employees response');
    final list = json['employees'];
    if (list is! List) {
      throw const EmployeeParseException('Ажилтны жагсаалт буруу байна.');
    }
    final items = list
        .whereType<Map>()
        .map((item) => Employee.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    return EmployeePageDto(
      EmployeePage(
        page: PagedResult(
          items: items,
          pagination: _pagination(json['pagination']),
        ),
        meta: _meta(json['meta']),
      ),
    );
  }
}

/// `GET/POST/PATCH` employee detail — all `{employee:{...}}`.
class EmployeeDto {
  const EmployeeDto(this.value);
  final Employee value;

  factory EmployeeDto.fromJson(Object? raw) {
    final json = _map(raw, 'employee response');
    return EmployeeDto(Employee.fromJson(_map(json['employee'], 'employee')));
  }
}

/// `DELETE /api/v1/employees/[id]`, `POST /reset-password` —
/// `{employee:{id}}`.
class EmployeeIdResultDto {
  const EmployeeIdResultDto(this.value);
  final EmployeeIdResult value;

  factory EmployeeIdResultDto.fromJson(Object? raw) {
    final json = _map(raw, 'employee id response');
    return EmployeeIdResultDto(
      EmployeeIdResult.fromJson(_map(json['employee'], 'employee')),
    );
  }
}

/// `POST /api/v1/employees/[id]/toggle-active` — `{employee:{id,isActive}}`.
class EmployeeToggleResultDto {
  const EmployeeToggleResultDto(this.value);
  final EmployeeToggleResult value;

  factory EmployeeToggleResultDto.fromJson(Object? raw) {
    final json = _map(raw, 'employee toggle response');
    return EmployeeToggleResultDto(
      EmployeeToggleResult.fromJson(_map(json['employee'], 'employee')),
    );
  }
}

/// `POST /api/v1/employees/bulk` — a **bare** `{succeeded, failed, errors}`,
/// no wrapping envelope key. Deliberately tolerant of a malformed payload,
/// same reasoning as `BulkCategoryResultDto` (Services, `P4-F1`): nothing in
/// [EmployeeBulkResult] is an id a caller acts on directly.
class EmployeeBulkResultDto {
  const EmployeeBulkResultDto(this.value);
  final EmployeeBulkResult value;

  factory EmployeeBulkResultDto.fromJson(Object? raw) => EmployeeBulkResultDto(
    raw is Map
        ? EmployeeBulkResult.fromJson(Map<String, dynamic>.from(raw))
        : const EmployeeBulkResult(),
  );
}
