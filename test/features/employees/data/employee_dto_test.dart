import 'package:carcare_service/features/employees/data/employee_dto.dart';
import 'package:carcare_service/features/employees/domain/employee.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmployeePageDto', () {
    test('parses the measured list envelope with meta', () {
      final dto = EmployeePageDto.fromJson({
        'employees': [
          {'id': 'u-1', 'firstName': 'Бат', 'lastName': 'Дорж'},
        ],
        'pagination': _pagination,
        'meta': {
          'branches': [
            {'id': 'b-1', 'name': 'Салбар 1', 'count': 2},
            {'id': '', 'name': 'Хуваарилагдаагүй', 'count': 1},
          ],
          'roles': [
            {'id': 'role-1', 'name': 'Механик'},
          ],
        },
      });
      expect(dto.value.page.items.single.id, 'u-1');
      expect(dto.value.meta.branches.length, 2);
      expect(dto.value.meta.branches.last.isUnassigned, isTrue);
      expect(dto.value.meta.roles.single.name, 'Механик');
    });

    test('a missing meta degrades to empty lists, never throws', () {
      final dto = EmployeePageDto.fromJson({
        'employees': const [],
        'pagination': _pagination,
      });
      expect(dto.value.meta.branches, isEmpty);
      expect(dto.value.meta.roles, isEmpty);
    });

    test('a row with no id throws', () {
      expect(
        () => EmployeePageDto.fromJson({
          'employees': [
            {'firstName': 'Бат'},
          ],
          'pagination': _pagination,
        }),
        throwsA(isA<EmployeeParseException>()),
      );
    });

    test('a missing or non-list employees key throws', () {
      expect(
        () => EmployeePageDto.fromJson({'pagination': _pagination}),
        throwsA(isA<EmployeeParseException>()),
      );
    });
  });

  group('EmployeeDto', () {
    test('parses the measured detail envelope', () {
      final e = EmployeeDto.fromJson({
        'employee': {'id': 'u-1', 'roleId': 'role-1'},
      }).value;
      expect(e.roleId, 'role-1');
    });

    test('a missing employee envelope key throws', () {
      expect(
        () => EmployeeDto.fromJson(<String, dynamic>{}),
        throwsA(isA<EmployeeParseException>()),
      );
    });
  });

  group('EmployeeIdResultDto', () {
    test('parses {employee:{id}}', () {
      final r = EmployeeIdResultDto.fromJson({
        'employee': {'id': 'u-1'},
      }).value;
      expect(r.id, 'u-1');
    });
  });

  group('EmployeeToggleResultDto', () {
    test('parses {employee:{id,isActive}}', () {
      final r = EmployeeToggleResultDto.fromJson({
        'employee': {'id': 'u-1', 'isActive': true},
      }).value;
      expect(r.isActive, isTrue);
    });
  });

  group('EmployeeBulkResultDto', () {
    test('parses the bare envelope — no wrapper key', () {
      final r = EmployeeBulkResultDto.fromJson({
        'succeeded': 1,
        'failed': 1,
        'errors': ['u-x: Олдсонгүй.'],
      }).value;
      expect(r.succeeded, 1);
      expect(r.failed, 1);
    });

    test('a non-map payload degrades to an empty result', () {
      expect(EmployeeBulkResultDto.fromJson('garbage').value.succeeded, 0);
      expect(EmployeeBulkResultDto.fromJson(null).value.errors, isEmpty);
    });
  });
}

const _pagination = {
  'page': 1,
  'pageSize': 50,
  'total': 1,
  'totalPages': 1,
  'hasPrev': false,
  'hasNext': false,
};
