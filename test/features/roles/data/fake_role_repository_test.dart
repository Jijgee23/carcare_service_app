import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/roles/domain/permission.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_permission_catalog_repository.dart';
import 'fake_role_repository.dart';

void main() {
  group('FakeRoleRepository', () {
    test('a non-owner caller is forbidden from every write', () async {
      final repo = FakeRoleRepository(callerIsOwner: false);
      expect(
        (await repo.createRole(
          name: 'X',
          permissions: const ['orders.view'],
        ) as Err).error.statusCode,
        403,
      );
      expect(
        (await repo.updateRole(
          'role-1',
          name: 'X',
          permissions: const [],
        ) as Err).error.statusCode,
        403,
      );
      expect((await repo.deleteRole('role-1') as Err).error.statusCode, 403);
    });

    test('an empty permissions list is rejected', () async {
      final repo = FakeRoleRepository();
      final result = await repo.createRole(name: 'X', permissions: const []);
      expect((result as Err).error.code, 'VALIDATION');
    });

    test('a duplicate name is rejected', () async {
      final repo = FakeRoleRepository();
      final result = await repo.createRole(
        name: 'Механик',
        permissions: const ['orders.view'],
      );
      expect((result as Err).error.code, 'DUPLICATE');
    });

    test('delete is blocked while a role is in use', () async {
      final repo = FakeRoleRepository();
      repo.userCountByRole['role-1'] = 2;
      final result = await repo.deleteRole('role-1');
      expect((result as Err).error.code, 'ROLE_IN_USE');
    });
  });

  group('FakePermissionCatalogRepository', () {
    test(
      'getPermissions returns a deterministic catalogue with no gaps',
      () async {
        final repo = FakePermissionCatalogRepository();
        final catalog = (await repo.getPermissions() as Ok).value;
        expect(catalog.all, isNotEmpty);
        final allCodesNonEmpty = catalog.all.every(
          (PermissionItem p) => p.code.isNotEmpty,
        );
        expect(allCodesNonEmpty, isTrue);
      },
    );
  });
}
