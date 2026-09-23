import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/roles/domain/role.dart';

/// `GET /api/v1/roles` supports only standard pagination (`page`,
/// `pageSize`/`limit`) — no `q`/filter params exist on this route.
class RoleListQuery {
  final int page;
  final int pageSize;
  const RoleListQuery({this.page = 1, this.pageSize = 50});
}

/// One frozen repository contract for the Roles feature — P6-F1.
///
/// **Owner-only for every write** (D-171): [createRole], [updateRole], and
/// [deleteRole] all 403 for a non-owner caller before any validation runs.
/// [getRoles]/[getRole] are readable by any of `employees.view`/`.create`/
/// `.edit`, matching the employee form's role picker.
///
/// [updateRole] is a whole-record replace — `name`, `description`,
/// `permissions`, and `isActive` are all required/explicit arguments, same
/// discipline as [EmployeesRepository.updateEmployee].
///
/// Errors:
/// * `403` — not an owner (writes), or missing read permission (reads).
/// * `404 NOT_FOUND`.
/// * `409 ROLE_IN_USE` — [deleteRole] while any employee still holds it.
/// * `422 VALIDATION` / `DUPLICATE` — name conflict, empty permission list,
///   name over 60 chars, or a scope rule violation (e.g. `orders.edit`
///   without `orders.view` — mirrored client-side as a hint only; the
///   server remains authoritative).
abstract interface class RolesRepository {
  /// `GET /api/v1/roles`.
  Future<Result<PagedResult<Role>>> getRoles({RoleListQuery? query});

  /// `GET /api/v1/roles/[id]`.
  Future<Result<Role>> getRole(String roleId);

  /// `POST /api/v1/roles`. [permissions] must be non-empty; the server
  /// rejects both an empty list and a name already used in the tenant.
  Future<Result<Role>> createRole({
    required String name,
    String? description,
    required List<String> permissions,
    bool isActive = true,
  });

  /// `PATCH /api/v1/roles/[id]` — whole-record replace.
  Future<Result<Role>> updateRole(
    String roleId, {
    required String name,
    String? description,
    required List<String> permissions,
    bool isActive = true,
  });

  /// `DELETE /api/v1/roles/[id]` — blocked (409 `ROLE_IN_USE`) while
  /// `_count.users > 0`.
  Future<Result<RoleIdResult>> deleteRole(String roleId);
}
