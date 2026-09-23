import 'package:carcare_service/features/services/domain/service.dart';
import 'package:flutter_test/flutter_test.dart';

/// P4-F1 — defensive-parse contract for the Services domain models.
///
/// The bar these tests encode: a structurally missing `id` throws
/// [ServiceParseException]; everything else — including an unknown `type`
/// string — degrades. Payloads below are copied from the measured route
/// shapes in `app/api/v1/services*`, `app/api/v1/units`,
/// `app/api/v1/labor-categories`.
void main() {
  group('ServiceKind', () {
    test('parses the three known wire values', () {
      expect(ServiceKind.fromWire('LABOR'), ServiceKind.labor);
      expect(ServiceKind.fromWire('GOODS'), ServiceKind.goods);
      expect(ServiceKind.fromWire('DIAGNOSTIC'), ServiceKind.diagnostic);
    });

    test(
      'an unrecognised or missing value degrades to unknown, never throws',
      () {
        expect(
          ServiceKind.fromWire('SOMETHING_FROM_THE_FUTURE'),
          ServiceKind.unknown,
        );
        expect(ServiceKind.fromWire(null), ServiceKind.unknown);
        expect(ServiceKind.fromWire(42), ServiceKind.unknown);
      },
    );

    test('wire round-trips for the three known kinds', () {
      expect(ServiceKind.labor.wire, 'LABOR');
      expect(ServiceKind.goods.wire, 'GOODS');
      expect(ServiceKind.diagnostic.wire, 'DIAGNOSTIC');
      expect(ServiceKind.unknown.wire, '');
    });
  });

  group('Service.fromJson — GET shape (list and detail)', () {
    test('parses the measured list-route shape', () {
      final s = Service.fromJson({
        'id': 'svc-1',
        'type': 'GOODS',
        'name': 'Тормозны наклад',
        'code': 'BRK-001',
        'price': '45000.00',
        'costPrice': '30000.00',
        'stock': '12.5',
        'description': 'Урд тормоз',
        'isActive': true,
        'durationValue': null,
        'unit': {'id': 'unit-1', 'name': 'ширхэг', 'code': 'ШИР'},
        'durationUnit': null,
        'category': {'id': 'cat-1', 'name': 'Тормозны систем'},
        'createdAt': '2026-09-01T00:00:00.000Z',
      });

      expect(s.id, 'svc-1');
      expect(s.type, ServiceKind.goods);
      expect(s.name, 'Тормозны наклад');
      expect(s.code, 'BRK-001');
      expect(s.price, '45000.00');
      expect(s.costPrice, '30000.00');
      expect(s.stock, '12.5');
      expect(s.isActive, isTrue);
      expect(s.unit?.name, 'ширхэг');
      expect(s.unitId, 'unit-1');
      expect(s.category?.name, 'Тормозны систем');
      expect(s.categoryId, 'cat-1');
      expect(s.createdAt, isNotNull);
      // The list route never selects _count or reminderIntervalMonths.
      expect(s.orderItemCount, isNull);
      expect(s.reminderIntervalMonths, isNull);
      expect(s.updatedAt, isNull);
      expect(s.isStockAdjustable, isTrue);
    });

    test('parses the measured detail-route extras', () {
      final s = Service.fromJson({
        'id': 'svc-1',
        'type': 'LABOR',
        'name': 'Тос солих',
        'price': '20000',
        'isActive': true,
        'updatedAt': '2026-09-20T00:00:00.000Z',
        '_count': {'items': 7},
      });
      expect(s.updatedAt, isNotNull);
      expect(s.orderItemCount, 7);
      expect(s.isStockAdjustable, isFalse);
    });

    test('the measured PATCH echo — flat ids, no nested refs, no stock, '
        'reminderIntervalMonths present', () {
      final s = Service.fromJson({
        'id': 'svc-1',
        'type': 'GOODS',
        'name': 'Тормозны наклад',
        'code': 'BRK-001',
        'unitId': 'unit-1',
        'price': '45000.00',
        'costPrice': '30000.00',
        'durationValue': null,
        'durationUnitId': null,
        'reminderIntervalMonths': 6,
        'description': 'Урд тормоз',
        'isActive': true,
        'categoryId': 'cat-1',
      });

      expect(s.unit, isNull);
      expect(s.durationUnit, isNull);
      expect(s.category, isNull);
      // But the flat ids survive — a caller re-submitting an edit or
      // re-resolving a label from a cached picker list still has them.
      expect(s.unitId, 'unit-1');
      expect(s.categoryId, 'cat-1');
      expect(s.reminderIntervalMonths, 6);
      // PATCH never echoes stock/createdAt/updatedAt/_count.
      expect(s.stock, isNull);
      expect(s.createdAt, isNull);
      expect(s.updatedAt, isNull);
      expect(s.orderItemCount, isNull);
    });

    test('a numeric price/stock/durationValue is converted, not truncated', () {
      final s = Service.fromJson({
        'id': 'svc-1',
        'price': 45000,
        'stock': 12.5,
      });
      expect(s.price, '45000');
      expect(s.stock, '12.5');
    });

    test('every optional field degrades on the wrong type', () {
      final s = Service.fromJson({
        'id': 'svc-1',
        'type': 123,
        'name': null,
        'code': 7,
        'price': <Object>[],
        'isActive': 'yes',
        'unit': 'garbage',
        'category': 42,
        '_count': 'garbage',
      });
      expect(s.type, ServiceKind.unknown);
      expect(s.name, isNull);
      expect(s.code, isNull);
      expect(s.price, isNull);
      // Only a real `true` counts; malformed degrades to the permissive
      // default, matching the legacy catalogue model's own convention.
      expect(s.isActive, isTrue);
      expect(s.unit, isNull);
      expect(s.category, isNull);
      expect(s.orderItemCount, isNull);
      expect(s.displayName, 'Нэргүй');
    });

    test('a missing id throws — it cannot be opened, edited or stocked', () {
      expect(
        () => Service.fromJson({'name': 'Тос солих'}),
        throwsA(isA<ServiceParseException>()),
      );
    });

    test('a blank or non-string id throws', () {
      for (final bad in <Object?>['', '   ', 7, null, <String, dynamic>{}]) {
        expect(
          () => Service.fromJson({'id': bad}),
          throwsA(isA<ServiceParseException>()),
          reason: 'id=$bad must be rejected',
        );
      }
    });

    test('displayName combines code and name, falling back gracefully', () {
      expect(
        Service.fromJson({'id': 'x', 'code': 'BRK-001', 'name': 'Наклад'})
            .displayName,
        'BRK-001 · Наклад',
      );
      expect(
        Service.fromJson({'id': 'x', 'name': 'Наклад'}).displayName,
        'Наклад',
      );
      expect(
        Service.fromJson({'id': 'x', 'code': 'BRK-001'}).displayName,
        'BRK-001',
      );
      expect(Service.fromJson({'id': 'x'}).displayName, 'Нэргүй');
    });
  });

  group('ServiceDeleteResult', () {
    test('parses the measured archived/deleted outcomes', () {
      expect(
        ServiceDeleteResult.fromJson({
          'id': 'svc-1',
          'name': 'Тос солих',
          'type': 'LABOR',
          'outcome': 'archived',
        }).outcome,
        ServiceDeleteOutcome.archived,
      );
      expect(
        ServiceDeleteResult.fromJson({'id': 'svc-1', 'outcome': 'deleted'})
            .outcome,
        ServiceDeleteOutcome.deleted,
      );
    });

    test('an unrecognised outcome degrades to unknown, never throws', () {
      expect(
        ServiceDeleteResult.fromJson({
          'id': 'svc-1',
          'outcome': 'something-new',
        }).outcome,
        ServiceDeleteOutcome.unknown,
      );
    });

    test('a missing id throws', () {
      expect(
        () => ServiceDeleteResult.fromJson({'outcome': 'deleted'}),
        throwsA(isA<ServiceParseException>()),
      );
    });
  });

  group('ServiceStockResult', () {
    test('parses the measured shape', () {
      final r = ServiceStockResult.fromJson({'id': 'svc-1', 'stock': '17'});
      expect(r.id, 'svc-1');
      expect(r.stock, '17');
    });

    test('a missing id throws', () {
      expect(
        () => ServiceStockResult.fromJson({'stock': '17'}),
        throwsA(isA<ServiceParseException>()),
      );
    });
  });

  group('StockDirection', () {
    test('wire values are exactly in/out', () {
      expect(StockDirection.incoming.wire, 'in');
      expect(StockDirection.outgoing.wire, 'out');
    });
  });

  group('BulkCategoryResult', () {
    test('parses the measured per-item shape', () {
      final r = BulkCategoryResult.fromJson({
        'succeeded': 2,
        'failed': 1,
        'errors': ['svc-x: Олдсонгүй.'],
      });
      expect(r.succeeded, 2);
      expect(r.failed, 1);
      expect(r.errors, ['svc-x: Олдсонгүй.']);
    });

    test('a malformed payload degrades to an empty result, never throws', () {
      expect(BulkCategoryResult.fromJson({}).succeeded, 0);
      expect(
        BulkCategoryResult.fromJson({'errors': 'not-a-list'}).errors,
        isEmpty,
      );
      expect(
        BulkCategoryResult.fromJson({
          'errors': [1, 'ok', null],
        }).errors,
        ['ok'],
      );
    });
  });

  group('Unit', () {
    test('parses the measured lookup-row shape', () {
      final u = Unit.fromJson({
        'id': 'unit-1',
        'name': 'ширхэг',
        'code': 'ШИР',
        'isActive': false,
      });
      expect(u.id, 'unit-1');
      expect(u.isActive, isFalse);
    });

    test('isActive defaults to true when absent/malformed', () {
      expect(Unit.fromJson({'id': 'unit-1'}).isActive, isTrue);
      expect(
        Unit.fromJson({'id': 'unit-1', 'isActive': 'no'}).isActive,
        isTrue,
      );
    });

    test('a missing id throws — it cannot be selected in a picker', () {
      expect(
        () => Unit.fromJson({'name': 'ширхэг'}),
        throwsA(isA<ServiceParseException>()),
      );
    });
  });

  group('Category', () {
    test('parses the measured lookup-row shape', () {
      final c = Category.fromJson({
        'id': 'cat-1',
        'name': 'Тормозны систем',
        'description': 'Бэлдэц',
        'isActive': true,
      });
      expect(c.id, 'cat-1');
      expect(c.description, 'Бэлдэц');
    });

    test('a missing id throws', () {
      expect(
        () => Category.fromJson({'name': 'Тормозны систем'}),
        throwsA(isA<ServiceParseException>()),
      );
    });
  });
}
