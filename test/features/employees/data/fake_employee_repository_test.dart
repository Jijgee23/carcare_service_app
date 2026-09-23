import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/employees/domain/employees_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_employee_repository.dart';

void main() {
  test('self-deactivation is blocked', () async {
    final repo = FakeEmployeeRepository();
    final result = await repo.toggleActive('u-self', isActive: false);
    expect((result as Err).error.code, 'SELF_DEACTIVATE');
  });

  test('the last active owner cannot be deactivated', () async {
    final repo = FakeEmployeeRepository(
      currentUserId: 'someone-else',
      seed: [
        FakeEmployeeRepository.seedOwner(id: 'u-self'),
        FakeEmployeeRepository.seedEmployee(id: 'someone-else'),
      ],
    );
    final result = await repo.toggleActive('u-self', isActive: false);
    expect((result as Err).error.code, 'LAST_OWNER');
  });

  test('the last active owner cannot be deleted', () async {
    final repo = FakeEmployeeRepository(
      currentUserId: 'someone-else',
      seed: [
        FakeEmployeeRepository.seedOwner(id: 'u-self'),
        FakeEmployeeRepository.seedEmployee(id: 'someone-else'),
      ],
    );
    final result = await repo.deleteEmployee('u-self');
    expect((result as Err).error.code, 'LAST_OWNER');
  });

  test('self-delete is blocked', () async {
    final repo = FakeEmployeeRepository();
    final result = await repo.deleteEmployee('u-self');
    expect((result as Err).error.code, 'SELF_ACTION');
  });

  test('self-reset-password is blocked', () async {
    final repo = FakeEmployeeRepository();
    final result = await repo.resetPassword('u-self');
    expect((result as Err).error.code, 'SELF_ACTION');
  });

  test('resetPassword clears verified — forces OTP re-activation', () async {
    final repo = FakeEmployeeRepository();
    await repo.resetPassword('u-1');
    final refreshed = (await repo.getEmployee('u-1') as Ok).value;
    expect(refreshed.verified, isFalse);
  });

  test("an owner's role cannot be changed", () async {
    final repo = FakeEmployeeRepository();
    final result = await repo.updateEmployee(
      'u-self',
      firstName: 'Эзэмшигч',
      lastName: 'Админ',
      email: 'owner@example.com',
      phone: '99000000',
      roleId: 'role-1',
    );
    expect((result as Err).error.code, 'OWNER_ROLE_LOCKED');
  });

  test('a duplicate email/phone on create is a DUPLICATE error', () async {
    final repo = FakeEmployeeRepository();
    final result = await repo.createEmployee(
      firstName: 'Шинэ',
      lastName: 'Хүн',
      email: 'u-1@example.com',
      phone: '99001122',
    );
    expect((result as Err).error.code, 'DUPLICATE');
  });

  test('bulkUpdateRoleBranch is per-row: an owner in the batch fails but the '
      'rest still succeed', () async {
    final repo = FakeEmployeeRepository();
    final result = await repo.bulkUpdateRoleBranch(
      employeeIds: const ['u-1', 'u-self'],
      roleId: 'role-2',
    );
    final value = (result as Ok).value;
    expect(value.succeeded, 1);
    expect(value.failed, 1);
  });

  test(
    'getEmployees filters by active and reports meta branch chips',
    () async {
      final repo = FakeEmployeeRepository();
      final result = await repo.getEmployees(
        query: const EmployeeListQuery(active: true),
      );
      final page = (result as Ok).value;
      expect(page.page.items, isNotEmpty);
      expect(page.meta.branches, isNotEmpty);
    },
  );
}
