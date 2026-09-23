import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/roles/domain/role.dart';
import 'package:carcare_service/features/roles/domain/roles_repository.dart';

/// Hand-written fake for [RolesRepository] — P6-F1. `isOwner` on the caller
/// is modelled with a constructor flag rather than reading it off a shared
/// session, matching this feature's owner-only write gate (D-171).
class FakeRoleRepository implements RolesRepository {
  FakeRoleRepository({List<Role>? seed, this.callerIsOwner = true})
    : _roles = [
        ...(seed ?? [seedRole()]),
      ];

  final List<Role> _roles;
  final bool callerIsOwner;

  /// Simulates `_count.users` for [deleteRole]'s in-use guard: any role id
  /// present here with a positive count blocks the delete.
  final Map<String, int> userCountByRole = {};

  static Role seedRole({
    String id = 'role-1',
    String name = 'Механик',
    List<String> permissions = const ['orders.view', 'orders.edit'],
    bool isActive = true,
  }) => Role(id: id, name: name, permissions: permissions, isActive: isActive);

  int _indexOf(String id) => _roles.indexWhere((r) => r.id == id);

  AppError _notFound() => const AppError(
    ErrorKind.notFound,
    'Үүрэг олдсонгүй.',
    statusCode: 404,
    code: 'NOT_FOUND',
  );

  AppError _forbidden() => const AppError(
    ErrorKind.forbidden,
    'Зөвхөн тенант админ үүргийг удирдана.',
    statusCode: 403,
  );

  @override
  Future<Result<PagedResult<Role>>> getRoles({RoleListQuery? query}) async {
    final q = query ?? const RoleListQuery();
    final total = _roles.length;
    final totalPages = (total / q.pageSize).ceil().clamp(1, 1 << 30);
    final page = q.page.clamp(1, totalPages);
    final skip = (page - 1) * q.pageSize;
    final items = _roles.skip(skip).take(q.pageSize).toList(growable: false);
    return Ok(
      PagedResult(
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
    );
  }

  @override
  Future<Result<Role>> getRole(String roleId) async {
    final index = _indexOf(roleId);
    if (index < 0) return Err(_notFound());
    return Ok(_roles[index]);
  }

  @override
  Future<Result<Role>> createRole({
    required String name,
    String? description,
    required List<String> permissions,
    bool isActive = true,
  }) async {
    if (!callerIsOwner) return Err(_forbidden());
    if (name.trim().isEmpty || name.trim().length > 60) {
      return Err(
        const AppError(
          ErrorKind.unknown,
          'Нэр буруу байна.',
          statusCode: 422,
          code: 'VALIDATION',
          fieldErrors: {'name': 'Нэр 1-60 тэмдэгт байна.'},
        ),
      );
    }
    if (permissions.isEmpty) {
      return Err(
        const AppError(
          ErrorKind.unknown,
          'Дор хаяж нэг эрх сонгоно уу.',
          statusCode: 422,
          code: 'VALIDATION',
          fieldErrors: {'permissions': 'Дор хаяж нэг эрх сонгоно уу.'},
        ),
      );
    }
    if (_roles.any((r) => r.name == name.trim())) {
      return Err(
        const AppError(
          ErrorKind.unknown,
          'Энэ нэртэй үүрэг өмнө нь бүртгэгдсэн байна.',
          statusCode: 422,
          code: 'DUPLICATE',
          fieldErrors: {'name': 'Давхардсан нэр.'},
        ),
      );
    }
    final created = Role(
      id: 'role-${_roles.length + 1}',
      name: name.trim(),
      description: description,
      permissions: permissions,
      isActive: isActive,
    );
    _roles.add(created);
    return Ok(created);
  }

  @override
  Future<Result<Role>> updateRole(
    String roleId, {
    required String name,
    String? description,
    required List<String> permissions,
    bool isActive = true,
  }) async {
    if (!callerIsOwner) return Err(_forbidden());
    final index = _indexOf(roleId);
    if (index < 0) return Err(_notFound());
    if (permissions.isEmpty) {
      return Err(
        const AppError(
          ErrorKind.unknown,
          'Дор хаяж нэг эрх сонгоно уу.',
          statusCode: 422,
          code: 'VALIDATION',
        ),
      );
    }
    final updated = Role(
      id: roleId,
      name: name.trim(),
      description: description,
      permissions: permissions,
      isActive: isActive,
    );
    _roles[index] = updated;
    return Ok(updated);
  }

  @override
  Future<Result<RoleIdResult>> deleteRole(String roleId) async {
    if (!callerIsOwner) return Err(_forbidden());
    final index = _indexOf(roleId);
    if (index < 0) return Err(_notFound());
    if ((userCountByRole[roleId] ?? 0) > 0) {
      return Err(
        const AppError(
          ErrorKind.unknown,
          'Энэ үүрэг хэрэглэгдэж байгаа тул устгах боломжгүй.',
          statusCode: 409,
          code: 'ROLE_IN_USE',
        ),
      );
    }
    _roles.removeAt(index);
    return Ok(RoleIdResult(id: roleId));
  }
}
