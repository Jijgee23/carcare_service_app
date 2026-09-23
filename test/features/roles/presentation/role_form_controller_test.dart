import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/features/roles/domain/permission.dart';
import 'package:carcare_service/features/roles/presentation/controllers/role_form_controller.dart';

import '../data/fake_permission_catalog_repository.dart';
import '../data/fake_role_repository.dart';

void main() {
  group('RoleFormController', () {
    test('init() loads the catalog from the repository only', () async {
      final controller = RoleFormController(
        rolesRepo: FakeRoleRepository(),
        catalogRepo: FakePermissionCatalogRepository(),
      );
      await controller.init();

      expect(controller.loadingCatalog, isFalse);
      expect(controller.catalogError, isNull);
      expect(controller.catalog.groups, isNotEmpty);
    });

    test('toggleGroup selects/deselects every item in a group', () {
      final controller = RoleFormController(
        rolesRepo: FakeRoleRepository(),
        catalogRepo: FakePermissionCatalogRepository(),
      );
      final catalog = FakePermissionCatalogRepository.defaultCatalog();
      final ordersGroup = catalog.groups.firstWhere((g) => g.group == 'orders');

      expect(controller.isGroupFullySelected(ordersGroup.items), isFalse);
      controller.toggleGroup(ordersGroup.items, true);
      expect(controller.isGroupFullySelected(ordersGroup.items), isTrue);
      for (final item in ordersGroup.items) {
        expect(controller.isSelected(item.code), isTrue);
      }

      controller.toggleGroup(ordersGroup.items, false);
      expect(controller.isGroupFullySelected(ordersGroup.items), isFalse);
      for (final item in ordersGroup.items) {
        expect(controller.isSelected(item.code), isFalse);
      }
    });

    test('isGroupPartiallySelected is true with a mixed selection', () {
      final controller = RoleFormController(
        rolesRepo: FakeRoleRepository(),
        catalogRepo: FakePermissionCatalogRepository(),
      );
      const items = [
        PermissionItem(code: 'orders.view'),
        PermissionItem(code: 'orders.edit'),
      ];
      controller.toggle('orders.view', true);
      expect(controller.isGroupPartiallySelected(items), isTrue);
      expect(controller.isGroupFullySelected(items), isFalse);
    });

    group('orderScopeHint (mirrors validateOrderScopes)', () {
      test('null when no orders permissions are selected', () {
        final controller = RoleFormController(
          rolesRepo: FakeRoleRepository(),
          catalogRepo: FakePermissionCatalogRepository(),
        );
        expect(controller.orderScopeHint, isNull);
      });

      test('edit without any view hints the general message', () {
        final controller = RoleFormController(
          rolesRepo: FakeRoleRepository(),
          catalogRepo: FakePermissionCatalogRepository(),
        );
        controller.toggle('orders.editOwn', true);
        expect(controller.orderScopeHint, isNotNull);
      });

      test('orders.edit without orders.view hints the branch-scope message '
          'even when orders.viewOwn is present', () {
        final controller = RoleFormController(
          rolesRepo: FakeRoleRepository(),
          catalogRepo: FakePermissionCatalogRepository(),
        );
        controller.toggle('orders.viewOwn', true);
        controller.toggle('orders.edit', true);
        expect(
          controller.orderScopeHint,
          'Салбарын засах эрхэд Салбарын харах эрх шаардлагатай.',
        );
      });

      test('no hint once orders.view and orders.edit are both selected', () {
        final controller = RoleFormController(
          rolesRepo: FakeRoleRepository(),
          catalogRepo: FakePermissionCatalogRepository(),
        );
        controller.toggle('orders.view', true);
        controller.toggle('orders.edit', true);
        expect(controller.orderScopeHint, isNull);
      });
    });

    test('hasAtLeastOnePermission reflects the selection', () {
      final controller = RoleFormController(
        rolesRepo: FakeRoleRepository(),
        catalogRepo: FakePermissionCatalogRepository(),
      );
      expect(controller.hasAtLeastOnePermission, isFalse);
      controller.toggle('orders.view', true);
      expect(controller.hasAtLeastOnePermission, isTrue);
    });

    test(
      'submit() create succeeds and reports through the repository',
      () async {
        final repo = FakeRoleRepository(seed: const []);
        final controller = RoleFormController(
          rolesRepo: repo,
          catalogRepo: FakePermissionCatalogRepository(),
        );
        controller.toggle('orders.view', true);

        final ok = await controller.submit(name: 'Механик', description: null);
        expect(ok, isTrue);
        expect(controller.lastError, isNull);
      },
    );

    test('submit() surfaces DUPLICATE from the repository', () async {
      final repo = FakeRoleRepository(
        seed: [FakeRoleRepository.seedRole(id: 'r1', name: 'Механик')],
      );
      final controller = RoleFormController(
        rolesRepo: repo,
        catalogRepo: FakePermissionCatalogRepository(),
      );
      controller.toggle('orders.view', true);

      final ok = await controller.submit(name: 'Механик', description: null);
      expect(ok, isFalse);
      expect(controller.lastError?.code, 'DUPLICATE');
      expect(controller.fieldErrors['name'], isNotNull);
    });

    test(
      'submit() as a non-owner surfaces the repository forbidden error',
      () async {
        final repo = FakeRoleRepository(callerIsOwner: false, seed: const []);
        final controller = RoleFormController(
          rolesRepo: repo,
          catalogRepo: FakePermissionCatalogRepository(),
        );
        controller.toggle('orders.view', true);

        final ok = await controller.submit(name: 'Механик', description: null);
        expect(ok, isFalse);
        expect(controller.lastError, isNotNull);
      },
    );

    test('submit() edit replaces the whole record', () async {
      final repo = FakeRoleRepository(
        seed: [
          FakeRoleRepository.seedRole(
            id: 'r1',
            name: 'Механик',
            permissions: ['orders.view'],
          ),
        ],
      );
      final existing = (await repo.getRole('r1')).valueOrNull!;
      final controller = RoleFormController(
        existing: existing,
        rolesRepo: repo,
        catalogRepo: FakePermissionCatalogRepository(),
      );
      controller.toggle('orders.edit', true);

      final ok = await controller.submit(
        name: 'Механик ахлах',
        description: 'шинэ тайлбар',
      );
      expect(ok, isTrue);
      final updated = (await repo.getRole('r1')).valueOrNull!;
      expect(updated.name, 'Механик ахлах');
      expect(updated.permissions, contains('orders.edit'));
    });
  });
}
