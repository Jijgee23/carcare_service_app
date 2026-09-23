import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/features/roles/presentation/controllers/role_list_controller.dart';

import '../data/fake_role_repository.dart';

void main() {
  group('RoleListController', () {
    test('load() populates listState from the repository', () async {
      final repo = FakeRoleRepository(
        seed: [FakeRoleRepository.seedRole(id: 'r1', name: 'A')],
      );
      final controller = RoleListController(repo: repo);
      await controller.load();

      final state = controller.listState;
      expect(state, isA<AsyncData<List<dynamic>>>());
      expect((state as AsyncData).value.length, 1);
    });

    test('deleteRole() removes the row on success', () async {
      final repo = FakeRoleRepository(
        seed: [FakeRoleRepository.seedRole(id: 'r1', name: 'A')],
      );
      final controller = RoleListController(repo: repo);
      await controller.load();

      final ok = await controller.deleteRole('r1');
      expect(ok, isTrue);
      final state = controller.listState as AsyncData;
      expect(state.value, isEmpty);
      expect(controller.deleteError, isNull);
    });

    test('deleteRole() surfaces ROLE_IN_USE and keeps the row', () async {
      final repo = FakeRoleRepository(
        seed: [FakeRoleRepository.seedRole(id: 'r1', name: 'A')],
      );
      repo.userCountByRole['r1'] = 2;
      final controller = RoleListController(repo: repo);
      await controller.load();

      final ok = await controller.deleteRole('r1');
      expect(ok, isFalse);
      expect(controller.deleteError?.code, 'ROLE_IN_USE');
      final state = controller.listState as AsyncData;
      expect(state.value.length, 1);
    });
  });
}
