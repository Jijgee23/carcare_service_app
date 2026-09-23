import 'package:carcare_service/features/employees/domain/employee.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Employee', () {
    test('parses the measured full row', () {
      final e = Employee.fromJson({
        'id': 'u-1',
        'firstName': 'Бат',
        'lastName': 'Дорж',
        'email': 'bat@example.com',
        'phone': '99001122',
        'isOwner': false,
        'roleId': 'role-1',
        'roleName': 'Механик',
        'isActive': true,
        'activeUntil': '2026-12-01T00:00:00.000Z',
        'tenantId': 't-1',
        'branchId': 'b-1',
        'assignableBranchIds': ['b-1', 'b-2'],
        'verified': true,
      });
      expect(e.id, 'u-1');
      expect(e.displayName, 'Дорж Бат');
      expect(e.roleName, 'Механик');
      expect(e.assignableBranchIds, ['b-1', 'b-2']);
      expect(e.verified, isTrue);
    });

    test('a missing id throws', () {
      expect(
        () => Employee.fromJson({'firstName': 'Бат'}),
        throwsA(isA<EmployeeParseException>()),
      );
    });

    test('everything but id degrades tolerantly', () {
      final e = Employee.fromJson({'id': 'u-1'});
      expect(e.firstName, isNull);
      expect(e.isActive, isTrue);
      expect(e.isOwner, isFalse);
      expect(e.assignableBranchIds, isEmpty);
      expect(e.displayName, 'Нэргүй');
    });

    test('passwordHash/lock/OTP-shaped keys never surface — the model has '
        'no field to read them into', () {
      final e = Employee.fromJson({
        'id': 'u-1',
        'passwordHash': 'secret',
        'failedLoginAttempts': 5,
        'lockedAt': '2026-09-01T00:00:00.000Z',
      });
      // No getter exists for any of these — this test documents the
      // structural guarantee, not a runtime check.
      expect(e.id, 'u-1');
    });
  });

  group('EmployeeBranchChip', () {
    test('the synthetic unassigned chip is id == ""', () {
      final chip = EmployeeBranchChip.fromJson({
        'id': '',
        'name': 'Хуваарилагдаагүй',
        'count': 3,
      });
      expect(chip.isUnassigned, isTrue);
      expect(chip.count, 3);
    });
  });

  group('EmployeeBulkResult', () {
    test('parses succeeded/failed/errors', () {
      final r = EmployeeBulkResult.fromJson({
        'succeeded': 2,
        'failed': 1,
        'errors': ['u-3: Олдсонгүй.'],
      });
      expect(r.succeeded, 2);
      expect(r.failed, 1);
      expect(r.errors, ['u-3: Олдсонгүй.']);
    });

    test('a malformed errors list degrades to empty', () {
      final r = EmployeeBulkResult.fromJson({'succeeded': 1, 'failed': 0});
      expect(r.errors, isEmpty);
    });
  });

  group('EmployeeToggleResult / EmployeeIdResult', () {
    test('toggle result parses id + isActive', () {
      final r = EmployeeToggleResult.fromJson({'id': 'u-1', 'isActive': false});
      expect(r.id, 'u-1');
      expect(r.isActive, isFalse);
    });

    test('id result requires id', () {
      expect(
        () => EmployeeIdResult.fromJson({}),
        throwsA(isA<EmployeeParseException>()),
      );
    });
  });
}
