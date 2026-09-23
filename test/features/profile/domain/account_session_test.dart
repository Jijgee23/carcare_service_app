import 'package:carcare_service/features/profile/domain/account_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountSession.fromJson', () {
    test('parses a full web row', () {
      final s = AccountSession.fromJson({
        'id': 's-1',
        'source': 'web',
        'deviceLabel': 'Chrome · Windows',
        'ip': '1.2.3.4',
        'createdAt': '2026-09-01T00:00:00.000Z',
        'lastActivityAt': '2026-09-20T00:00:00.000Z',
        'expiresAt': '2026-10-01T00:00:00.000Z',
        'revokedAt': null,
        'status': 'active',
        'current': true,
      });
      expect(s.id, 's-1');
      expect(s.source, AccountSessionSource.web);
      expect(s.deviceLabel, 'Chrome · Windows');
      expect(s.ip, '1.2.3.4');
      expect(s.status, AccountSessionStatus.active);
      expect(s.current, isTrue);
      expect(s.revokedAt, isNull);
      expect(s.createdAt, isNotNull);
    });

    test('parses a mobile row with nulls degrading gracefully', () {
      final s = AccountSession.fromJson({
        'id': 's-2',
        'source': 'mobile',
        'deviceLabel': null,
        'ip': null,
        'createdAt': null,
        'lastActivityAt': null,
        'expiresAt': null,
        'revokedAt': '2026-09-10T00:00:00.000Z',
        'status': 'revoked',
        'current': false,
      });
      expect(s.source, AccountSessionSource.mobile);
      expect(s.deviceLabel, '');
      expect(s.ip, isNull);
      expect(s.status, AccountSessionStatus.revoked);
      expect(s.current, isFalse);
      expect(s.revokedAt, isNotNull);
    });

    test('an unrecognised status degrades to unknown, not a throw', () {
      final s = AccountSession.fromJson({
        'id': 's-3',
        'source': 'web',
        'status': 'something-new',
      });
      expect(s.status, AccountSessionStatus.unknown);
    });

    test('missing current defaults to false', () {
      final s = AccountSession.fromJson({'id': 's-4', 'source': 'web'});
      expect(s.current, isFalse);
    });

    test('a missing id throws AccountSessionParseException', () {
      expect(
        () => AccountSession.fromJson({'source': 'web'}),
        throwsA(isA<AccountSessionParseException>()),
      );
    });

    test('a blank id throws', () {
      expect(
        () => AccountSession.fromJson({'id': '  ', 'source': 'web'}),
        throwsA(isA<AccountSessionParseException>()),
      );
    });

    test('a missing/invalid source throws', () {
      expect(
        () => AccountSession.fromJson({'id': 's-5', 'source': 'desktop'}),
        throwsA(isA<AccountSessionParseException>()),
      );
      expect(
        () => AccountSession.fromJson({'id': 's-6'}),
        throwsA(isA<AccountSessionParseException>()),
      );
    });
  });
}
