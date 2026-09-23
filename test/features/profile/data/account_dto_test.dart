import 'package:carcare_service/features/profile/data/account_dto.dart';
import 'package:flutter_test/flutter_test.dart';

const _pagination = {
  'page': 1,
  'pageSize': 20,
  'total': 0,
  'totalPages': 0,
  'hasPrev': false,
  'hasNext': false,
};

void main() {
  group('MeProfileDto.fromJson', () {
    test('parses a full /me-shaped payload', () {
      final dto = MeProfileDto.fromJson({
        'id': 'u-1',
        'email': 'a@b.mn',
        'firstName': 'Бат',
        'lastName': 'Болд',
        'phone': '99001122',
        'isOwner': true,
        'role': {'id': 'r-1', 'name': 'Manager', 'permissions': ['employees.view']},
        'tenant': {'id': 't-1', 'name': 'Карком'},
        'branch': {'id': 'b-1', 'name': 'Төв салбар'},
      });
      expect(dto.id, 'u-1');
      expect(dto.email, 'a@b.mn');
      expect(dto.firstName, 'Бат');
      expect(dto.isOwner, isTrue);
      expect(dto.branchId, 'b-1');
      expect(dto.role!.name, 'Manager');
      expect(dto.role!.permissions, ['employees.view']);
      expect(dto.tenant!.name, 'Карком');
    });

    test('a null role/tenant/branch degrades to null, never throws', () {
      final dto = MeProfileDto.fromJson({
        'id': 'u-1',
        'email': 'a@b.mn',
        'role': null,
        'tenant': null,
        'branch': null,
      });
      expect(dto.role, isNull);
      expect(dto.tenant, isNull);
      expect(dto.branchId, isNull);
    });

    test('phone as a non-string coerces via toString, matching MeRepository', () {
      final dto = MeProfileDto.fromJson({'id': 'u-1', 'phone': 99001122});
      expect(dto.phone, '99001122');
    });

    test('a non-map payload throws AccountParseException', () {
      expect(() => MeProfileDto.fromJson('nope'), throwsA(isA<AccountParseException>()));
    });
  });

  group('PasswordChangeResultDto.fromJson', () {
    test('parses {ok: true}', () {
      expect(PasswordChangeResultDto.fromJson({'ok': true}).value, isNotNull);
    });

    test('a non-map payload throws', () {
      expect(
        () => PasswordChangeResultDto.fromJson(null),
        throwsA(isA<AccountParseException>()),
      );
    });
  });

  group('AccountSessionsPageDto.fromJson', () {
    test('parses active/ended/otherActiveCount/pagination together', () {
      final dto = AccountSessionsPageDto.fromJson({
        'active': [
          {'id': 's-1', 'source': 'mobile', 'status': 'active', 'current': true},
          {'id': 's-2', 'source': 'web', 'status': 'active', 'current': false},
        ],
        'ended': [
          {'id': 's-3', 'source': 'web', 'status': 'revoked', 'current': false},
        ],
        'otherActiveCount': 1,
        'pagination': _pagination,
      });
      expect(dto.value.active, hasLength(2));
      expect(dto.value.ended, hasLength(1));
      expect(dto.value.otherActiveCount, 1);
      expect(dto.value.pagination.page, 1);
    });

    test('otherActiveCount defaults to 0 when missing/non-int', () {
      final dto = AccountSessionsPageDto.fromJson({
        'active': <Object>[],
        'ended': <Object>[],
        'pagination': _pagination,
      });
      expect(dto.value.otherActiveCount, 0);
    });

    test('a missing active/ended list throws', () {
      expect(
        () => AccountSessionsPageDto.fromJson({
          'active': null,
          'ended': <Object>[],
          'pagination': _pagination,
        }),
        throwsA(isA<AccountParseException>()),
      );
    });

    test('an item that fails row parsing throws (propagates from the model)', () {
      expect(
        () => AccountSessionsPageDto.fromJson({
          'active': [
            {'source': 'web'}, // missing id
          ],
          'ended': <Object>[],
          'pagination': _pagination,
        }),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('RevokeSessionAckDto.fromJson', () {
    test('parses {ok: true}', () {
      expect(RevokeSessionAckDto.fromJson({'ok': true}), isNotNull);
    });

    test('a non-map payload throws', () {
      expect(
        () => RevokeSessionAckDto.fromJson('nope'),
        throwsA(isA<AccountParseException>()),
      );
    });
  });

  group('RevokeOtherSessionsResultDto.fromJson', () {
    test('parses webRevoked/mobileRevoked', () {
      final dto = RevokeOtherSessionsResultDto.fromJson({
        'ok': true,
        'webRevoked': 2,
        'mobileRevoked': 1,
      });
      expect(dto.value.webRevoked, 2);
      expect(dto.value.mobileRevoked, 1);
    });

    test('missing counts default to 0', () {
      final dto = RevokeOtherSessionsResultDto.fromJson({'ok': true});
      expect(dto.value.webRevoked, 0);
      expect(dto.value.mobileRevoked, 0);
    });
  });
}
