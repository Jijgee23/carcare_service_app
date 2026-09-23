import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/roles/domain/permission.dart';

/// Backs `GET /api/v1/permissions` — the sole source of permission codes,
/// labels, and grouping this client ever uses. No permission code is
/// hardcoded anywhere else in the Employees/Roles/Schedules features; a
/// screen that needs to render or validate a permission picker must go
/// through this repository. Same read gate as `GET /api/v1/roles`: any of
/// `employees.view`/`.create`/`.edit`.
abstract interface class PermissionCatalogRepository {
  /// `GET /api/v1/permissions`.
  Future<Result<PermissionCatalog>> getPermissions();
}
