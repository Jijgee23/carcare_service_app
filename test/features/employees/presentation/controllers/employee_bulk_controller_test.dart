import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/employees/presentation/controllers/employee_bulk_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fake_employee_repository.dart';

void main() {
  group('EmployeeBulkController', () {
    test('load populates items from every page (defensive cap)', () async {
      final seed = List.generate(
        3,
        (i) => FakeEmployeeRepository.seedEmployee(id: 'u-$i'),
      );
      final repo = FakeEmployeeRepository(seed: seed);
      final c = EmployeeBulkController(repo: repo);
      await c.load();
      expect(c.items.length, 3);
    });

    test(
      'apply rejects an empty selection without calling the repository',
      () async {
        final repo = FakeEmployeeRepository();
        final c = EmployeeBulkController(repo: repo);
        await c.load();
        final result = await c.apply(roleId: 'role-2');
        expect((result as Err).error.code, 'VALIDATION');
      },
    );

    test('apply is per-row: a partial failure is surfaced via lastResult, '
        'not thrown', () async {
      final repo = FakeEmployeeRepository(
        seed: [
          FakeEmployeeRepository.seedEmployee(id: 'u-1'),
          FakeEmployeeRepository.seedOwner(id: 'owner-1'),
        ],
      );
      final c = EmployeeBulkController(repo: repo);
      await c.load();
      c.selection.toggle('u-1');
      c.selection.toggle('owner-1');

      final result = await c.apply(roleId: 'role-2');
      expect(result, isA<Ok<Object?>>());
      expect(c.lastResult?.succeeded, 1);
      expect(c.lastResult?.failed, 1);
      expect(c.lastResult?.errors, isNotEmpty);
      // Selection is cleared and the list reloaded after a submit.
      expect(c.selection.isEmpty, isTrue);
    });

    test('pruneMissing keeps the selection in sync after a reload', () async {
      final repo = FakeEmployeeRepository(
        seed: [FakeEmployeeRepository.seedEmployee(id: 'u-1')],
      );
      final c = EmployeeBulkController(repo: repo);
      await c.load();
      c.selection.toggle('u-1');
      c.selection.toggle('gone');
      await c.load();
      expect(c.selection.selected, {'u-1'});
    });
  });
}
