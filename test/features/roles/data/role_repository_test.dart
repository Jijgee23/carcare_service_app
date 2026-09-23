import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/roles/data/permission_catalog_data_source.dart';
import 'package:carcare_service/features/roles/data/permission_catalog_repository.dart';
import 'package:carcare_service/features/roles/data/role_repository.dart';
import 'package:carcare_service/features/roles/data/roles_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RemoteRolesRepository', () {
    test('createRole/updateRole send the whole record', () async {
      final ds = _RecordingRolesDataSource({
        'role': {'id': 'role-1'},
      });
      await RemoteRolesRepository(dataSource: ds)
          .createRole(name: 'Механик', permissions: const ['orders.view']);
      expect(ds.lastCreateBody, {
        'name': 'Механик',
        'description': null,
        'permissions': ['orders.view'],
        'isActive': true,
      });

      await RemoteRolesRepository(dataSource: ds)
          .updateRole('role-1', name: 'Механик 2', permissions: const []);
      expect(ds.lastUpdateId, 'role-1');
      expect(ds.lastUpdateBody!['name'], 'Механик 2');
    });

    test('a 403 not-owner rejection passes through verbatim', () async {
      const mapped = AppError(
        ErrorKind.forbidden,
        'Зөвхөн тенант админ үүргийг удирдана.',
        statusCode: 403,
      );
      final result = await RemoteRolesRepository(
        dataSource: _ThrowingRolesDataSource(mapped),
      ).createRole(name: 'Механик', permissions: const ['orders.view']);
      expect((result as Err).error.statusCode, 403);
    });

    test('a 409 ROLE_IN_USE on delete passes through', () async {
      const mapped = AppError(
        ErrorKind.unknown,
        'Энэ үүрэг хэрэглэгдэж байгаа тул устгах боломжгүй.',
        statusCode: 409,
        code: 'ROLE_IN_USE',
      );
      final result = await RemoteRolesRepository(
        dataSource: _ThrowingRolesDataSource(mapped),
      ).deleteRole('role-1');
      expect((result as Err).error.code, 'ROLE_IN_USE');
    });

    test('getRoles unwraps items and pagination', () async {
      final result = await RemoteRolesRepository(
        dataSource: _RecordingRolesDataSource({
          'roles': [
            {'id': 'role-1'},
          ],
          'pagination': _pagination,
        }),
      ).getRoles();
      expect((result as Ok).value.items.single.id, 'role-1');
    });
  });

  group('RemotePermissionCatalogRepository', () {
    test('getPermissions unwraps the catalogue', () async {
      final result = await RemotePermissionCatalogRepository(
        dataSource: _RecordingPermissionsDataSource({
          'groups': const [],
          'standalone': [
            {'code': 'employees.schedule'},
          ],
        }),
      ).getPermissions();
      expect((result as Ok).value.standalone.single.code, 'employees.schedule');
    });

    test('an AppError from mapDioException passes through', () async {
      const mapped = AppError(
        ErrorKind.forbidden,
        'Хандах эрх байхгүй',
        statusCode: 403,
      );
      final result = await RemotePermissionCatalogRepository(
        dataSource: _ThrowingPermissionsDataSource(mapped),
      ).getPermissions();
      expect((result as Err).error.statusCode, 403);
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

class _RecordingRolesDataSource implements RolesDataSource {
  _RecordingRolesDataSource(this.payload);
  final Object? payload;
  Map<String, dynamic>? lastCreateBody;
  String? lastUpdateId;
  Map<String, dynamic>? lastUpdateBody;

  @override
  Future<Object?> list(Map<String, dynamic> query) async => payload;
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
}

class _ThrowingRolesDataSource implements RolesDataSource {
  _ThrowingRolesDataSource(this.error);
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
}

class _RecordingPermissionsDataSource implements PermissionCatalogDataSource {
  _RecordingPermissionsDataSource(this.payload);
  final Object? payload;
  @override
  Future<Object?> get() async => payload;
}

class _ThrowingPermissionsDataSource implements PermissionCatalogDataSource {
  _ThrowingPermissionsDataSource(this.error);
  final AppError error;
  @override
  Future<Object?> get() async => throw error;
}
