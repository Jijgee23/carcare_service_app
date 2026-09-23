import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/profile/data/account_data_source.dart';
import 'package:carcare_service/features/profile/data/account_repository.dart';
import 'package:carcare_service/features/profile/domain/account_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/hive_test_setup.dart';

const _pagination = {
  'page': 1,
  'pageSize': 20,
  'total': 0,
  'totalPages': 0,
  'hasPrev': false,
  'hasNext': false,
};

User _storedUser() => User(
  accessToken: 'access-1',
  refreshToken: 'refresh-1',
  id: 'u-1',
  email: 'old@b.mn',
  firstName: 'Хуучин',
  lastName: 'Нэр',
  phone: '99000000',
  isOwner: false,
  branchId: 'b-old',
  role: UserRole('r-old', 'Ажилтан', const ['orders.read']),
  tenant: UserTenant('t-1', 'Карком'),
);

void main() {
  setUpAll(openTestHiveBoxes);

  setUp(() {
    Authenticator.user = _storedUser();
  });

  tearDown(() {
    Authenticator.clear();
  });

  group('updateProfile', () {
    test('sends the four whole-record fields', () async {
      final ds = _RecordingDataSource({
        'id': 'u-1',
        'email': 'new@b.mn',
        'firstName': 'Шинэ',
        'lastName': 'Нэр',
        'phone': '99001122',
        'isOwner': false,
      });
      await RemoteAccountRepository(dataSource: ds).updateProfile(
        firstName: 'Шинэ',
        lastName: 'Нэр',
        email: 'new@b.mn',
        phone: '99001122',
      );
      expect(ds.lastUpdateProfileBody, {
        'firstName': 'Шинэ',
        'lastName': 'Нэр',
        'email': 'new@b.mn',
        'phone': '99001122',
      });
    });

    test('merges the response into the stored Hive user, preserving tokens', () async {
      final ds = _RecordingDataSource({
        'id': 'u-1',
        'email': 'new@b.mn',
        'firstName': 'Шинэ',
        'lastName': 'Нэр',
        'phone': '99001122',
        'isOwner': false,
      });
      final result = await RemoteAccountRepository(dataSource: ds).updateProfile(
        firstName: 'Шинэ',
        lastName: 'Нэр',
        email: 'new@b.mn',
        phone: '99001122',
      );
      final updated = (result as Ok<User>).value;
      expect(updated.email, 'new@b.mn');
      expect(updated.firstName, 'Шинэ');
      // Tokens are never sent by /me, so they must survive from the stored user.
      expect(updated.accessToken, 'access-1');
      expect(updated.refreshToken, 'refresh-1');
      expect(Authenticator.user?.email, 'new@b.mn');
      expect(Authenticator.user?.accessToken, 'access-1');
    });

    test('a field omitted from the response falls back to the currently-stored value', () async {
      final ds = _RecordingDataSource({'id': 'u-1', 'email': 'new@b.mn'});
      final result = await RemoteAccountRepository(dataSource: ds).updateProfile(
        firstName: 'Шинэ',
        lastName: 'Нэр',
        email: 'new@b.mn',
        phone: '99001122',
      );
      final updated = (result as Ok<User>).value;
      expect(updated.email, 'new@b.mn');
      expect(updated.firstName, 'Хуучин'); // stored value survives
      expect(updated.phone, '99000000');
    });

    test('no signed-in user returns Err(unauthorized) without calling the data source', () async {
      Authenticator.clear();
      final ds = _RecordingDataSource({'id': 'u-1'});
      final result = await RemoteAccountRepository(dataSource: ds).updateProfile(
        firstName: 'A',
        lastName: 'B',
        email: 'a@b.mn',
        phone: '99001122',
      );
      expect((result as Err).error.kind, ErrorKind.unauthorized);
      expect(ds.lastUpdateProfileBody, isNull);
    });

    test('a 422 VALIDATION with fieldErrors passes through', () async {
      const mapped = AppError(
        ErrorKind.unknown,
        'Талбарын алдаа.',
        statusCode: 422,
        code: 'VALIDATION',
        fieldErrors: {'email': 'И-мэйл давхардаж байна.'},
      );
      final result = await RemoteAccountRepository(
        dataSource: _ThrowingDataSource(mapped),
      ).updateProfile(firstName: 'A', lastName: 'B', email: 'a@b.mn', phone: '99001122');
      expect((result as Err).error.fieldErrors, {'email': 'И-мэйл давхардаж байна.'});
    });
  });

  group('changePassword', () {
    test('sends the three fields verbatim', () async {
      final ds = _RecordingDataSource({'ok': true});
      await RemoteAccountRepository(dataSource: ds).changePassword(
        currentPassword: 'old-pass',
        newPassword: 'new-password',
        confirmPassword: 'new-password',
      );
      expect(ds.lastChangePasswordBody, {
        'currentPassword': 'old-pass',
        'newPassword': 'new-password',
        'confirmPassword': 'new-password',
      });
    });

    test('a 422 VALIDATION with fieldErrors passes through', () async {
      const mapped = AppError(
        ErrorKind.unknown,
        'Талбарын алдаа.',
        statusCode: 422,
        code: 'VALIDATION',
        fieldErrors: {'currentPassword': 'Одоогийн нууц үг буруу.'},
      );
      final result = await RemoteAccountRepository(
        dataSource: _ThrowingDataSource(mapped),
      ).changePassword(
        currentPassword: 'wrong',
        newPassword: 'new-password',
        confirmPassword: 'new-password',
      );
      final err = (result as Err).error;
      expect(err.code, 'VALIDATION');
      expect(err.fieldErrors, {'currentPassword': 'Одоогийн нууц үг буруу.'});
    });

    test('a 429 RATE_LIMITED is distinguishable from a 422', () async {
      const mapped = AppError(
        ErrorKind.unknown,
        'Хэт олон удаа буруу оролдсон.',
        statusCode: 429,
        code: 'RATE_LIMITED',
      );
      final result = await RemoteAccountRepository(
        dataSource: _ThrowingDataSource(mapped),
      ).changePassword(
        currentPassword: 'wrong',
        newPassword: 'new-password',
        confirmPassword: 'new-password',
      );
      final err = (result as Err).error;
      expect(err.statusCode, 429);
      expect(err.code, 'RATE_LIMITED');
    });

    test('success does not touch the stored user (no forced logout)', () async {
      final before = Authenticator.user;
      final ds = _RecordingDataSource({'ok': true});
      final result = await RemoteAccountRepository(dataSource: ds).changePassword(
        currentPassword: 'old-pass',
        newPassword: 'new-password',
        confirmPassword: 'new-password',
      );
      expect(result, isA<Ok>());
      expect(Authenticator.user?.accessToken, before?.accessToken);
    });
  });

  group('getSessions', () {
    test('sends page/pageSize', () async {
      final ds = _RecordingDataSource({
        'active': <Object>[],
        'ended': <Object>[],
        'otherActiveCount': 0,
        'pagination': _pagination,
      });
      await RemoteAccountRepository(dataSource: ds).getSessions(page: 2, pageSize: 10);
      expect(ds.lastGetSessionsQuery, {'page': 2, 'pageSize': 10});
    });

    test('unwraps active/ended/otherActiveCount/pagination', () async {
      final ds = _RecordingDataSource({
        'active': [
          {'id': 's-1', 'source': 'mobile', 'status': 'active', 'current': true},
        ],
        'ended': <Object>[],
        'otherActiveCount': 0,
        'pagination': _pagination,
      });
      final result = await RemoteAccountRepository(dataSource: ds).getSessions();
      final page = (result as Ok).value;
      expect(page.active, hasLength(1));
      expect(page.active.single.current, isTrue);
    });

    test('a parse failure becomes Err, never a thrown exception', () async {
      final result = await RemoteAccountRepository(
        dataSource: _RecordingDataSource({'wrong': 'envelope'}),
      ).getSessions();
      expect(result, isA<Err>());
      expect((result as Err).error.kind, ErrorKind.unknown);
    });
  });

  group('revokeSession', () {
    test('sends the source query param and id', () async {
      final ds = _RecordingDataSource({'ok': true});
      await RemoteAccountRepository(
        dataSource: ds,
      ).revokeSession('s-1', source: AccountSessionSource.mobile);
      expect(ds.lastRevokeSessionId, 's-1');
      expect(ds.lastRevokeSessionSource, 'mobile');
    });

    test('echoes isCurrent back as loggedOut on success', () async {
      final ds = _RecordingDataSource({'ok': true});
      final result = await RemoteAccountRepository(dataSource: ds).revokeSession(
        's-1',
        source: AccountSessionSource.mobile,
        isCurrent: true,
      );
      expect((result as Ok).value.loggedOut, isTrue);
    });

    test('isCurrent defaults to false, so loggedOut is false by default', () async {
      final ds = _RecordingDataSource({'ok': true});
      final result = await RemoteAccountRepository(
        dataSource: ds,
      ).revokeSession('s-1', source: AccountSessionSource.web);
      expect((result as Ok).value.loggedOut, isFalse);
    });

    test('a 404 NOT_FOUND (foreign/missing id) passes through', () async {
      const mapped = AppError(ErrorKind.notFound, 'Олдсонгүй', statusCode: 404, code: 'NOT_FOUND');
      final result = await RemoteAccountRepository(
        dataSource: _ThrowingDataSource(mapped),
      ).revokeSession('s-1', source: AccountSessionSource.web);
      expect((result as Err).error.code, 'NOT_FOUND');
    });
  });

  group('revokeOtherSessions', () {
    test('unwraps webRevoked/mobileRevoked', () async {
      final ds = _RecordingDataSource({'ok': true, 'webRevoked': 2, 'mobileRevoked': 1});
      final result = await RemoteAccountRepository(dataSource: ds).revokeOtherSessions();
      final value = (result as Ok).value;
      expect(value.webRevoked, 2);
      expect(value.mobileRevoked, 1);
      expect(ds.revokeOtherSessionsCalled, isTrue);
    });
  });
}

class _RecordingDataSource implements AccountDataSource {
  _RecordingDataSource(this.payload);
  final Object? payload;

  Map<String, dynamic>? lastUpdateProfileBody;
  Map<String, dynamic>? lastChangePasswordBody;
  Map<String, dynamic>? lastGetSessionsQuery;
  String? lastRevokeSessionId;
  String? lastRevokeSessionSource;
  bool revokeOtherSessionsCalled = false;

  @override
  Future<Object?> updateProfile(Map<String, dynamic> body) async {
    lastUpdateProfileBody = body;
    return payload;
  }

  @override
  Future<Object?> changePassword(Map<String, dynamic> body) async {
    lastChangePasswordBody = body;
    return payload;
  }

  @override
  Future<Object?> getSessions(Map<String, dynamic> query) async {
    lastGetSessionsQuery = query;
    return payload;
  }

  @override
  Future<Object?> revokeSession(String id, {required String source}) async {
    lastRevokeSessionId = id;
    lastRevokeSessionSource = source;
    return payload;
  }

  @override
  Future<Object?> revokeOtherSessions() async {
    revokeOtherSessionsCalled = true;
    return payload;
  }
}

class _ThrowingDataSource implements AccountDataSource {
  _ThrowingDataSource(this.error);
  final AppError error;

  @override
  Future<Object?> updateProfile(Map<String, dynamic> body) async => throw error;

  @override
  Future<Object?> changePassword(Map<String, dynamic> body) async => throw error;

  @override
  Future<Object?> getSessions(Map<String, dynamic> query) async => throw error;

  @override
  Future<Object?> revokeSession(String id, {required String source}) async => throw error;

  @override
  Future<Object?> revokeOtherSessions() async => throw error;
}
