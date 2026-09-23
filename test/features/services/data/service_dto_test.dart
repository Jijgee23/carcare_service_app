import 'package:carcare_service/features/services/data/service_dto.dart';
import 'package:carcare_service/features/services/domain/service.dart';
import 'package:flutter_test/flutter_test.dart';

/// P4-F1 — envelope contract for the Services DTOs. Field-level tolerance is
/// covered by `service_test.dart`; this file only exercises the envelope
/// unwrapping and the handful of structurally-required pieces (pagination
/// integers, the presence of the wrapper key itself).
void main() {
  group('ServicePageDto', () {
    test('parses the measured list envelope', () {
      final dto = ServicePageDto.fromJson({
        'services': [
          {'id': 'svc-1', 'type': 'GOODS', 'name': 'Наклад'},
        ],
        'pagination': _pagination,
      });
      expect(dto.items.single.id, 'svc-1');
      expect(dto.pagination.total, 1);
    });

    test('skips non-map rows instead of throwing', () {
      final dto = ServicePageDto.fromJson({
        'services': [
          'garbage',
          42,
          {'id': 'svc-1'},
        ],
        'pagination': _pagination,
      });
      expect(dto.items.map((s) => s.id), ['svc-1']);
    });

    test('a row with no id throws', () {
      expect(
        () => ServicePageDto.fromJson({
          'services': [
            {'name': 'Наклад'},
          ],
          'pagination': _pagination,
        }),
        throwsA(isA<ServiceParseException>()),
      );
    });

    test('a missing or non-list services key throws', () {
      expect(
        () => ServicePageDto.fromJson({'pagination': _pagination}),
        throwsA(isA<ServiceParseException>()),
      );
      expect(
        () => ServicePageDto.fromJson({
          'services': {'id': 'svc-1'},
          'pagination': _pagination,
        }),
        throwsA(isA<ServiceParseException>()),
      );
    });

    test('a non-map envelope throws', () {
      expect(
        () => ServicePageDto.fromJson('nope'),
        throwsA(isA<ServiceParseException>()),
      );
      expect(
        () => ServicePageDto.fromJson(null),
        throwsA(isA<ServiceParseException>()),
      );
    });

    test('malformed pagination throws', () {
      for (final bad in <Object?>[
        null,
        'x',
        {'page': 1},
        {
          'page': 0,
          'pageSize': 50,
          'total': 0,
          'totalPages': 1,
          'hasPrev': false,
          'hasNext': false,
        },
      ]) {
        expect(
          () => ServicePageDto.fromJson({
            'services': const [],
            'pagination': bad,
          }),
          throwsA(isA<ServiceParseException>()),
          reason: 'pagination=$bad must be rejected',
        );
      }
    });
  });

  group('ServiceDto', () {
    test('parses the measured GET detail envelope', () {
      final s = ServiceDto.fromJson({
        'service': {
          'id': 'svc-1',
          'type': 'GOODS',
          'name': 'Наклад',
          'unit': {'id': 'unit-1', 'name': 'ширхэг'},
          'category': {'id': 'cat-1', 'name': 'Тормоз'},
          'updatedAt': '2026-09-20T00:00:00.000Z',
          '_count': {'items': 3},
        },
      }).value;
      expect(s.unit?.id, 'unit-1');
      expect(s.orderItemCount, 3);
    });

    test(
      'parses the measured PATCH envelope, which carries flat ids not refs',
      () {
        final s = ServiceDto.fromJson({
          'service': {
            'id': 'svc-1',
            'type': 'GOODS',
            'name': 'Наклад',
            'unitId': 'unit-1',
            'categoryId': 'cat-1',
            'reminderIntervalMonths': 6,
          },
        }).value;
        expect(s.unit, isNull);
        expect(s.unitId, 'unit-1');
        expect(s.categoryId, 'cat-1');
        expect(s.reminderIntervalMonths, 6);
      },
    );

    test('a missing service envelope key throws', () {
      expect(
        () => ServiceDto.fromJson(<String, dynamic>{}),
        throwsA(isA<ServiceParseException>()),
      );
      expect(
        () => ServiceDto.fromJson({'service': 'garbage'}),
        throwsA(isA<ServiceParseException>()),
      );
    });
  });

  group('ServiceDeleteResultDto', () {
    test('parses the measured delete envelope', () {
      final r = ServiceDeleteResultDto.fromJson({
        'service': {
          'id': 'svc-1',
          'name': 'Наклад',
          'type': 'GOODS',
          'outcome': 'archived',
        },
      }).value;
      expect(r.outcome, ServiceDeleteOutcome.archived);
    });

    test('a missing id throws', () {
      expect(
        () => ServiceDeleteResultDto.fromJson({
          'service': {'outcome': 'deleted'},
        }),
        throwsA(isA<ServiceParseException>()),
      );
    });
  });

  group('ServiceStockResultDto', () {
    test('parses the measured stock envelope', () {
      final r = ServiceStockResultDto.fromJson({
        'service': {'id': 'svc-1', 'stock': '17'},
      }).value;
      expect(r.id, 'svc-1');
      expect(r.stock, '17');
    });

    test('a missing id throws', () {
      expect(
        () => ServiceStockResultDto.fromJson({
          'service': {'stock': '17'},
        }),
        throwsA(isA<ServiceParseException>()),
      );
    });
  });

  group('BulkCategoryResultDto', () {
    test('parses the measured BARE envelope — no wrapper key', () {
      final r = BulkCategoryResultDto.fromJson({
        'succeeded': 2,
        'failed': 1,
        'errors': ['svc-x: Олдсонгүй.'],
      }).value;
      expect(r.succeeded, 2);
      expect(r.failed, 1);
    });

    test('a non-map payload degrades to an empty result, never throws', () {
      expect(BulkCategoryResultDto.fromJson('garbage').value.succeeded, 0);
      expect(BulkCategoryResultDto.fromJson(null).value.errors, isEmpty);
    });
  });

  group('UnitListDto', () {
    test('parses the measured lookup envelope', () {
      final dto = UnitListDto.fromJson({
        'units': [
          {'id': 'unit-1', 'name': 'ширхэг', 'code': 'ШИР', 'isActive': true},
        ],
      });
      expect(dto.items.single.id, 'unit-1');
    });

    test('a missing or non-list units key throws', () {
      expect(
        () => UnitListDto.fromJson(<String, dynamic>{}),
        throwsA(isA<ServiceParseException>()),
      );
    });

    test('a unit row with no id throws', () {
      expect(
        () => UnitListDto.fromJson({
          'units': [
            {'name': 'ширхэг'},
          ],
        }),
        throwsA(isA<ServiceParseException>()),
      );
    });
  });

  group('CategoryListDto', () {
    test('parses the measured lookup envelope', () {
      final dto = CategoryListDto.fromJson({
        'categories': [
          {'id': 'cat-1', 'name': 'Тормоз', 'isActive': true},
        ],
      });
      expect(dto.items.single.id, 'cat-1');
    });

    test('a missing or non-list categories key throws', () {
      expect(
        () => CategoryListDto.fromJson(<String, dynamic>{}),
        throwsA(isA<ServiceParseException>()),
      );
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
