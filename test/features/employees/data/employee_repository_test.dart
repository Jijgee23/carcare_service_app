import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/employees/data/employee_repository.dart';
import 'package:carcare_service/features/employees/data/employees_data_source.dart';
import 'package:carcare_service/features/employees/domain/employee.dart';
import 'package:carcare_service/features/employees/domain/employees_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// P6-F1 — `RemoteEmployeesRepository` request/response contract, exercised
/// over a recording data source. Mirrors `service_repository_test.dart`'s
/// pattern.
void main() {
  group('request shaping', () {
    test('the default list query is page 1 / pageSize 50', () async {
      final ds = _RecordingDataSource(_listPayload);
      await RemoteEmployeesRepository(dataSource: ds).getEmployees();
      expect(ds.lastQuery, {'page': 1, 'pageSize': 50});
    });

    test('the list query sends only allow-listed, non-empty params', () async {
      final ds = _RecordingDataSource(_listPayload);
      await RemoteEmployeesRepository(dataSource: ds).getEmployees(
        query: const EmployeeListQuery(
          q: '  Бат  ',
          branchId: 'b-1',
          roleId: 'role-1',
          active: true,
          page: 2,
          pageSize: 25,
        ),
      );
      expect(ds.lastQuery, {
        'page': 2,
        'pageSize': 25,
        'q': 'Бат',
        'branchId': 'b-1',
        'roleId': 'role-1',
        'active': 'yes',
      });
    });

    test('active=false sends active=no', () async {
      final ds = _RecordingDataSource(_listPayload);
      await RemoteEmployeesRepository(dataSource: ds)
          .getEmployees(query: const EmployeeListQuery(active: false));
      expect(ds.lastQuery!['active'], 'no');
    });

    test('createEmployee sends isOwner only when true', () async {
      final ds = _RecordingDataSource({
        'employee': {'id': 'u-1'},
      });
      await RemoteEmployeesRepository(dataSource: ds).createEmployee(
        firstName: 'Бат',
        lastName: 'Дорж',
        email: 'bat@example.com',
        phone: '99001122',
      );
      expect(ds.lastCreateBody!.containsKey('isOwner'), isFalse);

      await RemoteEmployeesRepository(dataSource: ds).createEmployee(
        firstName: 'Бат',
        lastName: 'Дорж',
        email: 'bat@example.com',
        phone: '99001122',
        isOwner: true,
      );
      expect(ds.lastCreateBody!['isOwner'], isTrue);
    });

    test('updateEmployee sends every editable field explicitly, including '
        'nulls — whole-record replace, never a partial patch', () async {
      final ds = _RecordingDataSource({
        'employee': {'id': 'u-1'},
      });
      await RemoteEmployeesRepository(dataSource: ds).updateEmployee(
        'u-1',
        firstName: 'Бат',
        lastName: 'Дорж',
        email: 'bat@example.com',
        phone: '99001122',
      );
      expect(ds.lastUpdateId, 'u-1');
      expect(ds.lastUpdateBody, {
        'firstName': 'Бат',
        'lastName': 'Дорж',
        'email': 'bat@example.com',
        'phone': '99001122',
        'roleId': null,
        'branchId': null,
        'assignableBranchIds': const [],
        'isActive': true,
        'activeUntil': null,
      });
    });

    test('toggleActive sends the desired isActive verbatim', () async {
      final ds = _RecordingDataSource({
        'employee': {'id': 'u-1', 'isActive': false},
      });
      await RemoteEmployeesRepository(dataSource: ds)
          .toggleActive('u-1', isActive: false);
      expect(ds.lastToggleBody, {'isActive': false});
    });

    test('bulkUpdateRoleBranch omits empty roleId/branchId', () async {
      final ds = _RecordingDataSource({
        'succeeded': 1,
        'failed': 0,
        'errors': const [],
      });
      await RemoteEmployeesRepository(dataSource: ds).bulkUpdateRoleBranch(
        employeeIds: ['u-1', 'u-2'],
        roleId: 'role-1',
        branchId: '',
      );
      expect(ds.lastBulkBody, {
        'employeeIds': ['u-1', 'u-2'],
        'roleId': 'role-1',
      });
    });
  });

  group('response handling', () {
    test('getEmployees unwraps items, pagination, and meta', () async {
      final result = await RemoteEmployeesRepository(
        dataSource: _RecordingDataSource(_listPayload),
      ).getEmployees();
      final page = (result as Ok).value;
      expect(page.page.items.single.id, 'u-1');
      expect(page.meta.roles.single.id, 'role-1');
    });

    test('a parse failure becomes Err, never a thrown exception', () async {
      final result = await RemoteEmployeesRepository(
        dataSource: _RecordingDataSource({'wrong': 'envelope'}),
      ).getEmployees();
      expect(result, isA<Err>());
      expect((result as Err).error.kind, ErrorKind.unknown);
    });

    test('an AppError from the shared mapDioException mapper passes '
        'through verbatim — statusCode/code/fieldErrors intact', () async {
      const mapped = AppError(
        ErrorKind.unknown,
        'Сүүлийн идэвхтэй эзэмшигчийг идэвхгүй болгож болохгүй.',
        statusCode: 409,
        code: 'LAST_OWNER',
      );
      final result = await RemoteEmployeesRepository(
        dataSource: _ThrowingDataSource(mapped),
      ).toggleActive('u-1', isActive: false);
      final error = (result as Err).error;
      expect(identical(error, mapped), isTrue);
      expect(error.code, 'LAST_OWNER');
    });

    test(
      'a 422 VALIDATION/DUPLICATE rejection keeps its fieldErrors',
      () async {
        const mapped = AppError(
          ErrorKind.unknown,
          'Хүсэлт буруу.',
          statusCode: 422,
          code: 'DUPLICATE',
          fieldErrors: {'email': 'Энэ имэйл өөр хэрэглэгчид бүртгэлтэй байна.'},
        );
        final result =
            await RemoteEmployeesRepository(
              dataSource: _ThrowingDataSource(mapped),
            ).createEmployee(
              firstName: 'Бат',
              lastName: 'Дорж',
              email: 'dup@example.com',
              phone: '99001122',
            );
        final error = (result as Err).error;
        expect(error.statusCode, 422);
        expect(error.fieldErrors!['email'], isNotNull);
      },
    );

    test('a 404 NOT_FOUND on delete passes through', () async {
      const mapped = AppError(
        ErrorKind.notFound,
        'Олдсонгүй',
        statusCode: 404,
        code: 'NOT_FOUND',
      );
      final result = await RemoteEmployeesRepository(
        dataSource: _ThrowingDataSource(mapped),
      ).deleteEmployee('u-1');
      expect((result as Err).error.code, 'NOT_FOUND');
    });

    test('a 403 PLAN_LIMIT_REACHED on create passes through', () async {
      const mapped = AppError(
        ErrorKind.forbidden,
        'Ажилтны хязгаарт хүрсэн байна.',
        statusCode: 403,
        code: 'PLAN_LIMIT_REACHED',
      );
      final result =
          await RemoteEmployeesRepository(
            dataSource: _ThrowingDataSource(mapped),
          ).createEmployee(
            firstName: 'Бат',
            lastName: 'Дорж',
            email: 'bat@example.com',
            phone: '99001122',
          );
      expect((result as Err).error.code, 'PLAN_LIMIT_REACHED');
    });

    test('bulkUpdateRoleBranch unwraps the bare per-row result', () async {
      final result =
          await RemoteEmployeesRepository(
            dataSource: _RecordingDataSource({
              'succeeded': 1,
              'failed': 1,
              'errors': ['u-x: Олдсонгүй.'],
            }),
          ).bulkUpdateRoleBranch(
            employeeIds: const ['u-1', 'u-x'],
            roleId: 'role-1',
          );
      final value = (result as Ok).value;
      expect(value.succeeded, 1);
      expect(value.failed, 1);
    });
  });
}

const _listPayload = {
  'employees': [
    {'id': 'u-1', 'firstName': 'Бат', 'lastName': 'Дорж'},
  ],
  'pagination': {
    'page': 1,
    'pageSize': 50,
    'total': 1,
    'totalPages': 1,
    'hasPrev': false,
    'hasNext': false,
  },
  'meta': {
    'branches': <Object>[],
    'roles': [
      {'id': 'role-1', 'name': 'Механик'},
    ],
  },
};

class _RecordingDataSource implements EmployeesDataSource {
  _RecordingDataSource(this.payload);

  final Object? payload;
  Map<String, dynamic>? lastQuery;
  Map<String, dynamic>? lastCreateBody;
  String? lastUpdateId;
  Map<String, dynamic>? lastUpdateBody;
  Map<String, dynamic>? lastToggleBody;
  Map<String, dynamic>? lastBulkBody;

  @override
  Future<Object?> list(Map<String, dynamic> query) async {
    lastQuery = query;
    return payload;
  }

  @override
  Future<Object?> detail(String id) async => payload;

  @override
  Future<Object?> create(Map<String, dynamic> body) async {
    lastCreateBody = body;
    return payload;
  }

  @override
  Future<Object?> update(String id, Map<String, dynamic> body) async {
    lastUpdateId = id;
    lastUpdateBody = body;
    return payload;
  }

  @override
  Future<Object?> delete(String id) async => payload;

  @override
  Future<Object?> toggleActive(String id, Map<String, dynamic> body) async {
    lastToggleBody = body;
    return payload;
  }

  @override
  Future<Object?> resetPassword(String id) async => payload;

  @override
  Future<Object?> bulk(Map<String, dynamic> body) async {
    lastBulkBody = body;
    return payload;
  }
}

class _ThrowingDataSource implements EmployeesDataSource {
  _ThrowingDataSource(this.error);
  final AppError error;

  @override
  Future<Object?> list(Map<String, dynamic> query) async => throw error;
  @override
  Future<Object?> detail(String id) async => throw error;
  @override
  Future<Object?> create(Map<String, dynamic> body) async => throw error;
  @override
  Future<Object?> update(String id, Map<String, dynamic> body) async =>
      throw error;
  @override
  Future<Object?> delete(String id) async => throw error;
  @override
  Future<Object?> toggleActive(String id, Map<String, dynamic> body) async =>
      throw error;
  @override
  Future<Object?> resetPassword(String id) async => throw error;
  @override
  Future<Object?> bulk(Map<String, dynamic> body) async => throw error;
}
