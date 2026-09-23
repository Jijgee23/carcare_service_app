import 'package:carcare_service/features/audit/data/audit_dto.dart';
import 'package:carcare_service/features/audit/domain/audit_log.dart';
import 'package:flutter_test/flutter_test.dart';

const _pagination = {
  'page': 1,
  'pageSize': 50,
  'total': 1,
  'totalPages': 1,
  'hasPrev': false,
  'hasNext': false,
};

void main() {
  group('AuditPageDto.fromJson', () {
    test('unwraps items, pagination, and meta', () {
      final dto = AuditPageDto.fromJson({
        'items': [
          {'id': 'a-1', 'entity': 'ServiceOrder'},
        ],
        'pagination': _pagination,
        'meta': {
          'actions': ['CREATE'],
          'entities': ['ServiceOrder'],
          'users': <Object>[],
        },
      });
      expect(dto.value.items.single.id, 'a-1');
      expect(dto.value.pagination.total, 1);
      expect(dto.value.meta.actions, ['CREATE']);
    });

    test('a non-map entry in items is skipped, not thrown', () {
      final dto = AuditPageDto.fromJson({
        'items': [
          {'id': 'a-1'},
          'garbage',
        ],
        'pagination': _pagination,
      });
      expect(dto.value.items, hasLength(1));
    });

    test('a row missing id still throws (never silently dropped)', () {
      expect(
        () => AuditPageDto.fromJson({
          'items': [
            {'entity': 'ServiceOrder'},
          ],
          'pagination': _pagination,
        }),
        throwsA(isA<AuditParseException>()),
      );
    });

    test('items not a List throws AuditParseException', () {
      expect(
        () => AuditPageDto.fromJson({'items': 'nope', 'pagination': _pagination}),
        throwsA(isA<AuditParseException>()),
      );
    });

    test('malformed pagination throws AuditParseException', () {
      expect(
        () => AuditPageDto.fromJson({
          'items': <Object>[],
          'pagination': {'page': 0, 'pageSize': 50, 'total': 0, 'totalPages': 0, 'hasPrev': false, 'hasNext': false},
        }),
        throwsA(isA<AuditParseException>()),
      );
    });
  });
}
