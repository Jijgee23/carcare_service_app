import 'package:carcare_service/features/vehicles/data/vehicle_dto.dart';
import 'package:carcare_service/features/vehicles/domain/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

/// P3-F1 — defensive-parse contract for the Vehicles DTOs.
///
/// The bar these tests encode: a structurally missing `id` throws
/// [VehicleParseException]; everything else degrades. Payloads below are
/// copied from the measured route shapes in `app/api/v1/vehicles/`.
void main() {
  group('VehiclePageDto', () {
    test('parses the measured list shape', () {
      final dto = VehiclePageDto.fromJson({
        'vehicles': [
          {
            'id': 'veh-1',
            'plate': '1234 УБА',
            'vin': 'JTD1',
            'make': 'Toyota',
            'model': 'Prius 30',
            'year': 2012,
            'mileage': 180000,
            'customerId': 'cust-1',
            'customer': {
              'id': 'cust-1',
              'fullName': 'Бат',
              'phone': '99001122',
            },
          },
        ],
        'pagination': {
          'page': 1,
          'pageSize': 50,
          'total': 1,
          'totalPages': 1,
          'hasPrev': false,
          'hasNext': false,
        },
      });

      expect(dto.items, hasLength(1));
      final v = dto.items.single;
      expect(v.id, 'veh-1');
      expect(v.plate, '1234 УБА');
      expect(v.year, 2012);
      expect(v.customer?.fullName, 'Бат');
      expect(v.hasOwner, isTrue);
      // The list serializer carries none of the extended block.
      expect(v.fuelType, isNull);
      expect(v.isPostpaid, isFalse);
      expect(dto.pagination.total, 1);
    });

    test('an unowned link parses with a null customer block', () {
      final dto = VehiclePageDto.fromJson({
        'vehicles': [
          {
            'id': 'veh-2',
            'plate': '5678 УБА',
            'customerId': null,
            'customer': null,
          },
        ],
        'pagination': _pagination,
      });
      expect(dto.items.single.customer, isNull);
      expect(dto.items.single.hasOwner, isFalse);
    });

    test('skips non-map rows instead of throwing', () {
      final dto = VehiclePageDto.fromJson({
        'vehicles': [
          'garbage',
          42,
          {'id': 'veh-1'},
        ],
        'pagination': _pagination,
      });
      expect(dto.items.map((v) => v.id), ['veh-1']);
    });

    test('a row with no id throws — it cannot be opened or refreshed', () {
      expect(
        () => VehiclePageDto.fromJson({
          'vehicles': [
            {'plate': '1234 УБА'},
          ],
          'pagination': _pagination,
        }),
        throwsA(isA<VehicleParseException>()),
      );
    });

    test('a blank or non-string id throws', () {
      for (final bad in <Object?>['', '   ', 7, null, <String, dynamic>{}]) {
        expect(
          () => VehiclePageDto.fromJson({
            'vehicles': [
              {'id': bad},
            ],
            'pagination': _pagination,
          }),
          throwsA(isA<VehicleParseException>()),
          reason: 'id=$bad must be rejected',
        );
      }
    });

    test('a missing or non-list vehicles key throws', () {
      expect(
        () => VehiclePageDto.fromJson({'pagination': _pagination}),
        throwsA(isA<VehicleParseException>()),
      );
      expect(
        () => VehiclePageDto.fromJson({
          'vehicles': {'id': 'veh-1'},
          'pagination': _pagination,
        }),
        throwsA(isA<VehicleParseException>()),
      );
    });

    test('a non-map envelope throws', () {
      expect(
        () => VehiclePageDto.fromJson('nope'),
        throwsA(isA<VehicleParseException>()),
      );
      expect(
        () => VehiclePageDto.fromJson(null),
        throwsA(isA<VehicleParseException>()),
      );
    });

    test('malformed pagination throws', () {
      for (final bad in <Object?>[
        null,
        'x',
        {'page': 1},
        {
          'page': '1',
          'pageSize': 50,
          'total': 0,
          'totalPages': 1,
          'hasPrev': false,
          'hasNext': false,
        },
        {
          'page': 0,
          'pageSize': 50,
          'total': 0,
          'totalPages': 1,
          'hasPrev': false,
          'hasNext': false,
        },
        {
          'page': 1,
          'pageSize': 50,
          'total': -1,
          'totalPages': 1,
          'hasPrev': false,
          'hasNext': false,
        },
        {
          'page': 1,
          'pageSize': 50,
          'total': 0,
          'totalPages': 1,
          'hasPrev': 'no',
          'hasNext': false,
        },
      ]) {
        expect(
          () => VehiclePageDto.fromJson({
            'vehicles': const [],
            'pagination': bad,
          }),
          throwsA(isA<VehicleParseException>()),
          reason: 'pagination=$bad must be rejected',
        );
      }
    });
  });

  group('VehicleDto', () {
    test('parses the full detail shape including the extended block', () {
      final v = VehicleDto.fromJson({
        'vehicle': {
          'id': 'veh-1',
          'plate': '1234 УБА',
          'vin': 'JTD1',
          'make': 'Toyota',
          'model': 'Prius 30',
          'year': 2012,
          'mileage': 180000,
          'fuelType': 'Хайбрид',
          'wheelPosition': 'Баруун',
          'colorName': 'Цагаан',
          'capacity': 1797,
          'purpose': 'Суудал',
          'ownerRegnum': 'УБ99112233',
          'customerId': 'cust-1',
          'customer': {'id': 'cust-1', 'fullName': 'Бат', 'phone': '99001122'},
          'isPostpaid': true,
        },
      }).value;

      expect(v.wheelPosition, 'Баруун');
      expect(v.capacity, 1797);
      expect(v.ownerRegnum, 'УБ99112233');
      expect(v.isPostpaid, isTrue);
      expect(v.displayName, 'Toyota Prius 30');
    });

    test('POST/PATCH shapes parse although they omit the customer block', () {
      // POST /api/v1/vehicles — seven fields, no nested customer, no
      // isPostpaid. The reported customerId is the link's real owner.
      final created = VehicleDto.fromJson({
        'vehicle': {
          'id': 'veh-9',
          'plate': '1234 УБА',
          'vin': null,
          'make': 'Toyota',
          'model': 'Prius 30',
          'year': null,
          'mileage': null,
          'customerId': 'cust-OTHER',
        },
      }).value;
      expect(created.customerId, 'cust-OTHER');
      expect(created.customer, isNull);
      expect(created.isPostpaid, isFalse);
    });

    test('every optional field degrades to null', () {
      final v = VehicleDto.fromJson({
        'vehicle': {
          'id': 'veh-1',
          'plate': 42,
          'vin': <String, dynamic>{},
          'make': null,
          'model': '   ',
          'year': 'not-a-year',
          'mileage': 1.5,
          'fuelType': false,
          'capacity': <Object>[],
          'customer': 'garbage',
          'isPostpaid': 'yes',
        },
      }).value;

      expect(v.id, 'veh-1');
      expect(v.plate, isNull);
      expect(v.vin, isNull);
      expect(v.make, isNull);
      expect(v.model, isNull);
      expect(v.year, isNull);
      // 1.5 is not losslessly an int — truncating would be a wrong odometer.
      expect(v.mileage, isNull);
      expect(v.fuelType, isNull);
      expect(v.capacity, isNull);
      expect(v.customer, isNull);
      // Only a real `true` counts.
      expect(v.isPostpaid, isFalse);
      expect(v.displayName, '');
    });

    test('numeric strings and whole doubles are accepted for int fields', () {
      final v = VehicleDto.fromJson({
        'vehicle': {'id': 'veh-1', 'year': '2012', 'mileage': 1800.0},
      }).value;
      expect(v.year, 2012);
      expect(v.mileage, 1800);
    });

    test('a missing vehicle envelope key throws', () {
      expect(
        () => VehicleDto.fromJson(<String, dynamic>{}),
        throwsA(isA<VehicleParseException>()),
      );
      expect(
        () => VehicleDto.fromJson({'vehicle': 'garbage'}),
        throwsA(isA<VehicleParseException>()),
      );
    });
  });

  group('VehicleDeletionResultDto', () {
    test('parses the measured delete shape', () {
      final v = VehicleDeletionResultDto.fromJson({
        'vehicle': {
          'id': 'veh-1',
          'plate': '1234 УБА',
          'make': 'Toyota',
          'model': 'Prius 30',
        },
      }).value;
      expect(v.id, 'veh-1');
      expect(v.plate, '1234 УБА');
    });

    test('tolerates the all-null lookup the command allows', () {
      final v = VehicleDeletionResultDto.fromJson({
        'vehicle': {'id': 'veh-1', 'plate': null, 'make': null, 'model': null},
      }).value;
      expect(v.plate, isNull);
      expect(v.make, isNull);
    });

    test('a missing id throws', () {
      expect(
        () => VehicleDeletionResultDto.fromJson({
          'vehicle': {'plate': '1234 УБА'},
        }),
        throwsA(isA<VehicleParseException>()),
      );
    });
  });

  group('VehicleHistoryDto', () {
    test('parses the measured history shape', () {
      final h = VehicleHistoryDto.fromJson({
        'orders': [
          {
            'id': 'ord-1',
            'number': 'A-0001',
            'status': 'COMPLETED',
            'paymentStatus': 'PAID',
            'scheduledAt': '2026-09-20T03:00:00.000Z',
            'completedAt': null,
            'createdAt': '2026-09-19T03:00:00.000Z',
            'totalAmount': '150000.00',
            'branch': {'name': 'Толгойт салбар'},
            'itemCount': 3,
          },
        ],
        'appointments': [
          {
            'id': 'appt-1',
            'status': 'CONFIRMED',
            'requestedAt': '2026-09-22T02:00:00.000Z',
            'note': 'Дугуй солих',
            'branch': {'name': 'Толгойт салбар'},
            'category': {'name': 'Оношилгоо'},
          },
        ],
        'diagnosticReportCount': 2,
        'ownerLocked': true,
      }).value;

      expect(h.orders.single.number, 'A-0001');
      // A money value stays a raw decimal string, never a double.
      expect(h.orders.single.totalAmount, '150000.00');
      expect(h.orders.single.branchName, 'Толгойт салбар');
      expect(h.orders.single.itemCount, 3);
      expect(h.orders.single.completedAt, isNull);
      expect(h.orders.single.createdAt, isNotNull);
      expect(h.appointments.single.categoryName, 'Оношилгоо');
      expect(h.diagnosticReportCount, 2);
      expect(h.ownerLocked, isTrue);
    });

    test('an empty history is a normal response, not an error', () {
      final h = VehicleHistoryDto.fromJson({
        'orders': const [],
        'appointments': const [],
        'diagnosticReportCount': 0,
        'ownerLocked': false,
      }).value;
      expect(h.orders, isEmpty);
      expect(h.ownerLocked, isFalse);
    });

    test('missing or malformed lists and counters degrade', () {
      final h = VehicleHistoryDto.fromJson({
        'orders': 'garbage',
        'diagnosticReportCount': '2',
        'ownerLocked': 'true',
      }).value;
      expect(h.orders, isEmpty);
      expect(h.appointments, isEmpty);
      expect(h.diagnosticReportCount, 0);
      // Degrades to the permissive value — the server still rejects a
      // blocked owner change with 422.
      expect(h.ownerLocked, isFalse);
    });

    test('an unknown status string does not throw', () {
      final h = VehicleHistoryDto.fromJson({
        'orders': [
          {'id': 'ord-1', 'status': 'A_STATUS_FROM_THE_FUTURE'},
        ],
        'appointments': const [],
      }).value;
      expect(h.orders.single.status, 'A_STATUS_FROM_THE_FUTURE');
    });

    test('a history row with no id throws', () {
      expect(
        () => VehicleHistoryDto.fromJson({
          'orders': [
            {'number': 'A-0001'},
          ],
        }),
        throwsA(isA<VehicleParseException>()),
      );
    });

    test('a non-map envelope throws', () {
      expect(
        () => VehicleHistoryDto.fromJson(const []),
        throwsA(isA<VehicleParseException>()),
      );
    });
  });

  group('VehicleHurRefreshDto', () {
    test('parses the measured refresh shape — no id, no counts', () {
      final r = VehicleHurRefreshDto.fromJson({
        'vehicle': {
          'plate': '1234 УБА',
          'make': 'Toyota',
          'model': 'Prius 30',
          'year': 2013,
          'vin': 'JTD1',
          'fuelType': 'Хайбрид',
          'wheelPosition': 'Баруун',
          'colorName': 'Мөнгөлөг',
          'capacity': 1797,
          'purpose': 'Суудал',
        },
      }).value;
      expect(r.year, 2013);
      expect(r.colorName, 'Мөнгөлөг');
    });

    test('missing fields degrade — the envelope alone is enough', () {
      final r = VehicleHurRefreshDto.fromJson({'vehicle': <String, dynamic>{}})
          .value;
      expect(r.make, isNull);
      expect(r.year, isNull);
    });

    test('a missing vehicle key throws', () {
      expect(
        () => VehicleHurRefreshDto.fromJson(<String, dynamic>{}),
        throwsA(isA<VehicleParseException>()),
      );
    });

    test('applyTo keeps fields the refresh never speaks about', () {
      const base = Vehicle(
        id: 'veh-1',
        plate: '1234 УБА',
        make: 'Toyota',
        model: 'Prius 30',
        mileage: 180000,
        colorName: 'Цагаан',
        ownerRegnum: 'УБ99112233',
        customerId: 'cust-1',
        isPostpaid: true,
      );
      const refresh = VehicleHurRefresh(
        plate: 'SOMETHING ELSE',
        colorName: 'Мөнгөлөг',
      );

      final merged = refresh.applyTo(base);
      expect(merged.id, 'veh-1');
      // The plate is never changed by a refresh — not even if HUR reports a
      // different one.
      expect(merged.plate, '1234 УБА');
      expect(merged.colorName, 'Мөнгөлөг');
      // Untouched by the refresh payload.
      expect(merged.mileage, 180000);
      expect(merged.ownerRegnum, 'УБ99112233');
      expect(merged.customerId, 'cust-1');
      expect(merged.isPostpaid, isTrue);
    });

    test('a null in the refresh means "no new information", never "clear"', () {
      const base = Vehicle(
        id: 'veh-1',
        make: 'Toyota',
        model: 'Prius 30',
        fuelType: 'Хайбрид',
      );
      const refresh = VehicleHurRefresh(model: 'Prius 40');

      final merged = refresh.applyTo(base);
      expect(merged.make, 'Toyota');
      expect(merged.model, 'Prius 40');
      expect(merged.fuelType, 'Хайбрид');
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
