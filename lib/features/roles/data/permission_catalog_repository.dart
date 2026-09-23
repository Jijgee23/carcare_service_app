import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/roles/data/permission_catalog_data_source.dart';
import 'package:carcare_service/features/roles/data/permission_dto.dart';
import 'package:carcare_service/features/roles/domain/permission.dart';
import 'package:carcare_service/features/roles/domain/permission_catalog_repository.dart';

/// Remote adapter for [PermissionCatalogRepository] — P6-F1. No permission
/// code is hardcoded here or anywhere else in this feature; every code this
/// client can display or send comes from the server's response.
class RemotePermissionCatalogRepository implements PermissionCatalogRepository {
  RemotePermissionCatalogRepository({PermissionCatalogDataSource? dataSource})
    : _dataSource = dataSource ?? RemotePermissionCatalogDataSource();

  final PermissionCatalogDataSource _dataSource;

  @override
  Future<Result<PermissionCatalog>> getPermissions() async {
    try {
      return Ok(PermissionCatalogDto.fromJson(await _dataSource.get()).value);
    } catch (error) {
      return Err(_error(error, 'Эрхийн жагсаалт ачаалж чадсангүй'));
    }
  }
}

AppError _error(Object error, String fallback) => switch (error) {
  AppError value => value,
  PermissionParseException value => AppError(ErrorKind.unknown, value.message),
  _ => AppError(ErrorKind.unknown, fallback),
};
