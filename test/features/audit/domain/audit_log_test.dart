import 'package:carcare_service/features/audit/domain/audit_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuditLogEntry.fromJson', () {
    test('parses a full row, including nullable before/after JSON maps', () {
      final entry = AuditLogEntry.fromJson({
        'id': 'a-1',
        'entity': 'ServiceOrder',
        'entityId': 'o-1',
        'action': 'STATUS_CHANGE',
        'summary': 'Төлөв өөрчлөгдсөн',
        'before': {'status': 'SCHEDULED'},
        'after': {'status': 'IN_PROGRESS'},
        'createdAt': '2026-09-20T10:00:00.000Z',
        'user': {
          'id': 'u-1',
          'firstName': 'Бат',
          'lastName': 'Дорж',
          'email': 'bat@example.com',
        },
        'branchId': 'b-1',
      });

      expect(entry.id, 'a-1');
      expect(entry.before, {'status': 'SCHEDULED'});
      expect(entry.after, {'status': 'IN_PROGRESS'});
      expect(entry.user!.displayName, 'Дорж Бат');
      expect(entry.branchId, 'b-1');
    });

    test('before/after are null when absent — never an empty map', () {
      final entry = AuditLogEntry.fromJson({'id': 'a-1'});
      expect(entry.before, isNull);
      expect(entry.after, isNull);
      expect(entry.user, isNull);
    });

    test('before/after null literal stays null, not skipped', () {
      final entry = AuditLogEntry.fromJson({
        'id': 'a-1',
        'before': null,
        'after': null,
      });
      expect(entry.before, isNull);
      expect(entry.after, isNull);
    });

    test('a missing id throws AuditParseException', () {
      expect(
        () => AuditLogEntry.fromJson({'entity': 'ServiceOrder'}),
        throwsA(isA<AuditParseException>()),
      );
    });
  });

  group('AuditListMeta.fromJson', () {
    test('parses vocab lists and user options', () {
      final meta = AuditListMeta.fromJson({
        'actions': ['CREATE', 'UPDATE'],
        'entities': ['ServiceOrder'],
        'users': [
          {'id': 'u-1', 'firstName': 'Бат', 'lastName': 'Дорж'},
        ],
      });
      expect(meta.actions, ['CREATE', 'UPDATE']);
      expect(meta.entities, ['ServiceOrder']);
      expect(meta.users.single.id, 'u-1');
    });

    test('a non-map meta degrades to empty lists', () {
      final meta = AuditListMeta.fromJson('garbage');
      expect(meta.actions, isEmpty);
      expect(meta.entities, isEmpty);
      expect(meta.users, isEmpty);
    });
  });
}
