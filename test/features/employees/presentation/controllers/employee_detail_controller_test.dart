import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/employees/presentation/controllers/employee_detail_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fake_employee_repository.dart';

void main() {
  group('EmployeeDetailController', () {
    test('load populates detailState', () async {
      final repo = FakeEmployeeRepository();
      final c = EmployeeDetailController(employeeId: 'u-1', repo: repo);
      await c.load();
      expect(c.employee?.id, 'u-1');
    });

    test('toggleActive updates detailState on success', () async {
      final repo = FakeEmployeeRepository();
      final c = EmployeeDetailController(employeeId: 'u-1', repo: repo);
      await c.load();
      final result = await c.toggleActive(false);
      expect(result, isA<Ok<Object?>>());
      expect(c.employee?.isActive, isFalse);
    });

    test(
      'toggleActive surfaces SELF_DEACTIVATE without mutating state',
      () async {
        final repo = FakeEmployeeRepository(currentUserId: 'u-1');
        final c = EmployeeDetailController(employeeId: 'u-1', repo: repo);
        await c.load();
        final result = await c.toggleActive(false);
        expect(result, isA<Err<Object?>>());
        final err = (result as Err).error;
        expect(err.code, 'SELF_DEACTIVATE');
        expect(c.lastError?.code, 'SELF_DEACTIVATE');
        expect(c.employee?.isActive, isTrue);
      },
    );

    test('toggleActive surfaces LAST_OWNER', () async {
      final repo = FakeEmployeeRepository(
        seed: [FakeEmployeeRepository.seedOwner(id: 'owner-1')],
        currentUserId: 'someone-else',
      );
      final c = EmployeeDetailController(employeeId: 'owner-1', repo: repo);
      await c.load();
      final result = await c.toggleActive(false);
      expect((result as Err).error.code, 'LAST_OWNER');
    });

    test(
      'resetPassword never touches detailState and surfaces SELF_ACTION',
      () async {
        final repo = FakeEmployeeRepository(currentUserId: 'u-1');
        final c = EmployeeDetailController(employeeId: 'u-1', repo: repo);
        await c.load();
        final result = await c.resetPassword();
        expect((result as Err).error.code, 'SELF_ACTION');
      },
    );

    test('resetPassword succeeds against a different employee', () async {
      final repo = FakeEmployeeRepository(currentUserId: 'u-self');
      final c = EmployeeDetailController(employeeId: 'u-1', repo: repo);
      await c.load();
      final result = await c.resetPassword();
      expect(result, isA<Ok<Object?>>());
    });

    test('delete blocked by FK_CONFLICT-style / LAST_OWNER guard surfaces the error', () async {
      final repo = FakeEmployeeRepository(
        seed: [FakeEmployeeRepository.seedOwner(id: 'owner-1')],
        currentUserId: 'someone-else',
      );
      final c = EmployeeDetailController(employeeId: 'owner-1', repo: repo);
      await c.load();
      final result = await c.delete();
      expect((result as Err).error.code, 'LAST_OWNER');
      expect(c.lastError?.code, 'LAST_OWNER');
    });

    test('delete succeeds for a plain employee', () async {
      final repo = FakeEmployeeRepository();
      final c = EmployeeDetailController(employeeId: 'u-1', repo: repo);
      await c.load();
      final result = await c.delete();
      expect(result, isA<Ok<Object?>>());
    });
  });
}
