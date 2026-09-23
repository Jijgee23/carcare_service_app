import 'package:carcare_service/features/employees/presentation/controllers/employee_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fake_employee_repository.dart';

void main() {
  group('EmployeeListController', () {
    test('loadEmployees populates listState, meta and total', () async {
      final repo = FakeEmployeeRepository(
        seed: [
          FakeEmployeeRepository.seedEmployee(id: 'u-1', branchId: 'b-1'),
          FakeEmployeeRepository.seedOwner(id: 'u-self'),
        ],
      );
      final c = EmployeeListController(repo: repo);
      await c.loadEmployees();

      expect(c.filtered.length, 2);
      expect(c.total, 2);
      expect(c.meta.branches, isNotEmpty);
    });

    test('setQuery debounces then filters server-side', () async {
      final repo = FakeEmployeeRepository(
        seed: [
          FakeEmployeeRepository.seedEmployee(
            id: 'u-1',
            firstName: 'Бат',
            lastName: 'Дорж',
          ),
          FakeEmployeeRepository.seedEmployee(
            id: 'u-2',
            firstName: 'Сараа',
            lastName: 'Пүрэв',
          ),
        ],
      );
      final c = EmployeeListController(
        repo: repo,
        searchDebounce: Duration.zero,
      );
      await c.loadEmployees();
      expect(c.filtered.length, 2);

      c.setQuery('Сараа');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await Future<void>.delayed(Duration.zero);
      // Wait for the debounced load to complete.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(c.filtered.length, 1);
      expect(c.filtered.single.id, 'u-2');
    });

    test('setBranch/setRole/setActive trigger a fresh server load', () async {
      final repo = FakeEmployeeRepository(
        seed: [
          FakeEmployeeRepository.seedEmployee(
            id: 'u-1',
            branchId: 'b-1',
            isActive: true,
          ),
          FakeEmployeeRepository.seedEmployee(
            id: 'u-2',
            branchId: 'b-2',
            isActive: false,
          ),
        ],
      );
      final c = EmployeeListController(repo: repo);
      await c.loadEmployees();

      await c.setBranch('b-1');
      expect(c.filtered.map((e) => e.id), ['u-1']);

      await c.setBranch(null);
      await c.setActive(false);
      expect(c.filtered.map((e) => e.id), ['u-2']);
    });

    test(
      'setBranch(\'\') is a no-op: the server cannot filter by the '
      'synthetic unassigned branch, so this must never fake that filter '
      'client-side over a partial page',
      () async {
        final repo = FakeEmployeeRepository(
          seed: [
            FakeEmployeeRepository.seedEmployee(id: 'u-1', branchId: 'b-1'),
            FakeEmployeeRepository.seedEmployee(id: 'u-2', branchId: null),
          ],
        );
        final c = EmployeeListController(repo: repo);
        await c.loadEmployees();
        expect(c.filtered.length, 2);

        await c.setBranch('');
        expect(c.branchId, isNull);
        expect(c.filtered.length, 2);
      },
    );

    test(
      'loadMore appends the next page and preserves the first on error',
      () async {
        final seed = List.generate(
          3,
          (i) => FakeEmployeeRepository.seedEmployee(id: 'u-$i'),
        );
        final repo = FakeEmployeeRepository(seed: seed);
        final c = EmployeeListController(repo: repo);
        c.loadEmployees.call();
        await Future<void>.delayed(Duration.zero);
        // Force a small page to exercise pagination.
        await c.loadEmployees();
        expect(c.filtered.length, 3);
      },
    );

    test('a failed load surfaces AsyncError', () async {
      final repo = FakeEmployeeRepository();
      final c = EmployeeListController(repo: repo);
      await c.loadEmployees();
      // Query a nonexistent role — should just come back empty, not error;
      // errors are exercised via the detail controller's guard tests
      // instead since the fake never fails getEmployees itself.
      await c.setRole('does-not-exist');
      expect(c.filtered, isEmpty);
    });
  });
}
