import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/employees/domain/employee.dart';
import 'package:carcare_service/features/employees/presentation/controllers/employee_form_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fake_employee_repository.dart';

Employee _seedWithActiveUntil({required String id, DateTime? activeUntil}) =>
    Employee(
      id: id,
      firstName: 'Бат',
      lastName: 'Дорж',
      email: '$id@example.com',
      phone: '99001234',
      roleId: 'role-1',
      roleName: 'Механик',
      branchId: 'b-1',
      isActive: true,
      activeUntil: activeUntil,
      verified: true,
    );

void main() {
  group('EmployeeFormController', () {
    test(
      'submitCreate sends every field and returns the created employee',
      () async {
        final repo = FakeEmployeeRepository();
        final c = EmployeeFormController(repo: repo);
        final result = await c.submitCreate(
          firstName: 'Оюунаа',
          lastName: 'Батаа',
          email: 'oyunaa@example.test',
          phone: '99112233',
          roleId: 'role-1',
          branchId: 'b-1',
          assignableBranchIds: const ['b-1', 'b-2'],
        );
        expect(result, isA<Ok<Object?>>());
        final employee = (result as Ok).value;
        expect(employee.firstName, 'Оюунаа');
        expect(employee.assignableBranchIds, ['b-1', 'b-2']);
        expect(c.submitting, isFalse);
      },
    );

    test('submitCreate surfaces DUPLICATE with fieldErrors', () async {
      final repo = FakeEmployeeRepository();
      final c = EmployeeFormController(repo: repo);
      final result = await c.submitCreate(
        firstName: 'Дупликат',
        lastName: 'Тест',
        // Matches the default seeded employee's email.
        email: 'u-1@example.com',
        phone: '90009000',
      );
      final err = (result as Err).error;
      expect(err.code, 'DUPLICATE');
      expect(err.fieldErrors, isNotEmpty);
    });

    test(
      'submitUpdate is a whole-record replace and blocks OWNER_ROLE_LOCKED',
      () async {
        final repo = FakeEmployeeRepository();
        final c = EmployeeFormController(repo: repo);
        final result = await c.submitUpdate(
          'u-self',
          firstName: 'Эзэмшигч',
          lastName: 'Админ',
          email: 'owner@example.com',
          phone: '99000000',
          roleId: 'some-other-role',
        );
        expect((result as Err).error.code, 'OWNER_ROLE_LOCKED');
      },
    );

    test('submitUpdate succeeds for a non-owner target', () async {
      final repo = FakeEmployeeRepository();
      final c = EmployeeFormController(repo: repo);
      final result = await c.submitUpdate(
        'u-1',
        firstName: 'Шинэ',
        lastName: 'Нэр',
        email: 'new-email@example.test',
        phone: '95959595',
        branchId: 'b-2',
        isActive: false,
      );
      expect(result, isA<Ok<Object?>>());
      final employee = (result as Ok).value;
      expect(employee.firstName, 'Шинэ');
      expect(employee.branchId, 'b-2');
      expect(employee.isActive, isFalse);
    });

    test(
      'submitUpdate: editing only the name keeps the original activeUntil '
      'unchanged (whole-record PATCH must not wipe it)',
      () async {
        final existingExpiry = DateTime.utc(2027, 3, 15);
        final repo = FakeEmployeeRepository(
          seed: [
            _seedWithActiveUntil(id: 'u-1', activeUntil: existingExpiry),
          ],
        );
        final c = EmployeeFormController(repo: repo);
        final result = await c.submitUpdate(
          'u-1',
          firstName: 'Шинэ нэр',
          lastName: 'Дорж',
          email: 'u-1@example.com',
          phone: '99001234',
          activeUntil: existingExpiry,
        );
        expect(result, isA<Ok<Object?>>());
        final employee = (result as Ok).value;
        expect(employee.firstName, 'Шинэ нэр');
        expect(employee.activeUntil, existingExpiry);
      },
    );

    test(
      'submitUpdate: clearing activeUntil sends null and the server drops it',
      () async {
        final existingExpiry = DateTime.utc(2027, 3, 15);
        final repo = FakeEmployeeRepository(
          seed: [
            _seedWithActiveUntil(id: 'u-1', activeUntil: existingExpiry),
          ],
        );
        final c = EmployeeFormController(repo: repo);
        final result = await c.submitUpdate(
          'u-1',
          firstName: 'Бат',
          lastName: 'Дорж',
          email: 'u-1@example.com',
          phone: '99001234',
          activeUntil: null,
        );
        expect(result, isA<Ok<Object?>>());
        final employee = (result as Ok).value;
        expect(employee.activeUntil, isNull);
      },
    );
  });
}
