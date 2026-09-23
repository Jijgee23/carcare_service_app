import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/roles/data/role_dto.dart';
import 'package:carcare_service/features/roles/data/roles_data_source.dart';
import 'package:carcare_service/features/roles/domain/role.dart';
import 'package:carcare_service/features/roles/domain/roles_repository.dart';

/// Remote adapter for [RolesRepository] — P6-F1.
class RemoteRolesRepository implements RolesRepository {
  RemoteRolesRepository({RolesDataSource? dataSource})
    : _dataSource = dataSource ?? RemoteRolesDataSource();

  final RolesDataSource _dataSource;

  @override
  Future<Result<PagedResult<Role>>> getRoles({RoleListQuery? query}) async {
    final effective = query ?? const RoleListQuery();
    try {
      final parsed = RolePageDto.fromJson(
        await _dataSource.list({
          'page': effective.page,
          'pageSize': effective.pageSize,
        }),
      );
      return Ok(
        PagedResult(items: parsed.items, pagination: parsed.pagination),
      );
    } catch (error) {
      return Err(_error(error, 'Үүргийн жагсаалт ачаалж чадсангүй'));
    }
  }

  @override
  Future<Result<Role>> getRole(String roleId) async {
    try {
      return Ok(RoleDto.fromJson(await _dataSource.detail(roleId)).value);
    } catch (error) {
      return Err(_error(error, 'Үүргийн мэдээлэл ачаалж чадсангүй'));
    }
  }

  @override
  Future<Result<Role>> createRole({
    required String name,
    String? description,
    required List<String> permissions,
    bool isActive = true,
  }) async {
    try {
      return Ok(
        RoleDto.fromJson(
          await _dataSource.create({
            'name': name,
            'description': description,
            'permissions': permissions,
            'isActive': isActive,
          }),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Үүрэг үүсгэж чадсангүй'));
    }
  }

  @override
  Future<Result<Role>> updateRole(
    String roleId, {
    required String name,
    String? description,
    required List<String> permissions,
    bool isActive = true,
  }) async {
    try {
      return Ok(
        RoleDto.fromJson(
          await _dataSource.update(roleId, {
            'name': name,
            'description': description,
            'permissions': permissions,
            'isActive': isActive,
          }),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Үүрэг хадгалж чадсангүй'));
    }
  }

  @override
  Future<Result<RoleIdResult>> deleteRole(String roleId) async {
    try {
      return Ok(
        RoleIdResultDto.fromJson(await _dataSource.delete(roleId)).value,
      );
    } catch (error) {
      return Err(_error(error, 'Үүрэг устгаж чадсангүй'));
    }
  }
}

AppError _error(Object error, String fallback) => switch (error) {
  AppError value => value,
  RoleParseException value => AppError(ErrorKind.unknown, value.message),
  _ => AppError(ErrorKind.unknown, fallback),
};
