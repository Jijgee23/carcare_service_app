import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/roles/domain/permission.dart';
import 'package:carcare_service/features/roles/domain/permission_catalog_repository.dart';

/// Hand-written fake for [PermissionCatalogRepository] — P6-F1, for later
/// widget tests. A fixed, deterministic catalogue — no hardcoded permission
/// code leaks out of this file into a screen or controller under test; a
/// widget test asserts against whatever this fake returns, exactly as it
/// would against the real server's response.
class FakePermissionCatalogRepository implements PermissionCatalogRepository {
  FakePermissionCatalogRepository({PermissionCatalog? catalog})
    : _catalog = catalog ?? defaultCatalog();

  final PermissionCatalog _catalog;

  static PermissionCatalog defaultCatalog() => const PermissionCatalog(
    groups: [
      PermissionGroup(
        group: 'orders',
        items: [
          PermissionItem(
            code: 'orders.view',
            label: 'Захиалга харах',
            group: 'orders',
          ),
          PermissionItem(
            code: 'orders.edit',
            label: 'Захиалга засах',
            group: 'orders',
          ),
        ],
      ),
      PermissionGroup(
        group: 'employees',
        items: [
          PermissionItem(
            code: 'employees.view',
            label: 'Ажилтан харах',
            group: 'employees',
          ),
          PermissionItem(
            code: 'employees.create',
            label: 'Ажилтан нэмэх',
            group: 'employees',
          ),
          PermissionItem(
            code: 'employees.edit',
            label: 'Ажилтан засах',
            group: 'employees',
          ),
          PermissionItem(
            code: 'employees.delete',
            label: 'Ажилтан устгах',
            group: 'employees',
          ),
        ],
      ),
    ],
    standalone: [
      PermissionItem(
        code: 'employees.schedule',
        label: 'Ажлын хувиар удирдах',
        group: 'employees',
      ),
    ],
  );

  @override
  Future<Result<PermissionCatalog>> getPermissions() async => Ok(_catalog);
}
