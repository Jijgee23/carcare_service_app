import 'package:carcare_service/features/customers/data/customer_dto.dart';
import 'package:carcare_service/features/customers/domain/customer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Defensive-parse coverage for the P3-F1 customers envelopes and domain
/// models, measured against `app/api/v1/customers/**` and the shared modules
/// (`customer-commands.ts`, `customer-history.ts`, `pagination.ts`).
///
/// The governing rule, inherited from P2-F1: a typed
/// [CustomerParseException] is thrown ONLY for a structurally missing id (or
/// a structurally unusable envelope/pagination block). Every other malformed
/// or absent field degrades.
void main() {
  Map<String, dynamic> pagination({
    int page = 1,
    int pageSize = 50,
    int total = 1,
    int totalPages = 1,
  }) => {
    'page': page,
    'pageSize': pageSize,
    'total': total,
    'totalPages': totalPages,
    'hasPrev': page > 1,
    'hasNext': page < totalPages,
  };

  group('Customer.fromJson', () {
    test('parses the full CUSTOMER_SELECT shape', () {
      final customer = Customer.fromJson({
        'id': 'c1',
        'fullName': 'Бат',
        'phone': '99001122',
        'email': 'bat@example.mn',
        'note': 'VIP',
        'createdAt': '2026-09-01T08:00:00.000Z',
      });

      expect(customer.id, 'c1');
      expect(customer.fullName, 'Бат');
      expect(customer.phone, '99001122');
      expect(customer.email, 'bat@example.mn');
      expect(customer.note, 'VIP');
      expect(customer.createdAt, isNotNull);
    });

    test('throws only for a structurally missing id', () {
      expect(
        () => Customer.fromJson({'fullName': 'Бат'}),
        throwsA(isA<CustomerParseException>()),
      );
      expect(
        () => Customer.fromJson({'id': 123}),
        throwsA(isA<CustomerParseException>()),
      );
      expect(
        () => Customer.fromJson({'id': '   '}),
        throwsA(isA<CustomerParseException>()),
      );
    });

    test('tolerates every optional field being absent, null or mistyped', () {
      final absent = Customer.fromJson({'id': 'c1'});
      expect(absent.fullName, isNull);
      expect(absent.phone, isNull);
      expect(absent.email, isNull);
      expect(absent.note, isNull);
      expect(absent.createdAt, isNull);

      final malformed = Customer.fromJson({
        'id': 'c1',
        'fullName': 42,
        'phone': ['99001122'],
        'email': null,
        'note': {'a': 1},
        'createdAt': 'not-a-date',
      });
      expect(malformed.fullName, isNull);
      expect(malformed.phone, isNull);
      expect(malformed.email, isNull);
      expect(malformed.note, isNull);
      expect(malformed.createdAt, isNull);
    });

    test('an empty fullName normalises to null and displayName falls back', () {
      // `validateCustomerInput` only requires `phone`, so an empty
      // `fullName` is a legitimate server value, not a malformed one.
      final phoneOnly = Customer.fromJson({'id': 'c1', 'phone': '99001122'});
      expect(phoneOnly.fullName, isNull);
      expect(phoneOnly.displayName, '99001122');

      final blank = Customer.fromJson({'id': 'c1', 'fullName': '  '});
      expect(blank.fullName, isNull);
      expect(blank.displayName, 'Нэргүй');
    });

    test('PATCH response without createdAt still parses', () {
      // `updateCustomerCommand` returns `NormalizedCustomerData & {id}` —
      // there is genuinely no `createdAt` on this response.
      final patched = Customer.fromJson({
        'id': 'c1',
        'fullName': 'Бат',
        'phone': '99001122',
        'email': null,
        'note': null,
      });
      expect(patched.id, 'c1');
      expect(patched.createdAt, isNull);
    });
  });

  group('CustomerVehicleLink / CustomerVehicleRef', () {
    test('parses a vehicles[] row and keeps the link id distinct', () {
      final link = CustomerVehicleLink.fromJson({
        'id': 'tv-1',
        'isPostpaid': true,
        'orderCount': 3,
        'vehicle': {
          'id': 'v-1',
          'plate': '1234УБА',
          'vin': 'VIN123',
          'make': 'Toyota',
          'model': 'Prius',
          'year': 2019,
          'mileage': 120000,
        },
      });

      expect(link.id, 'tv-1');
      expect(link.isPostpaid, isTrue);
      expect(link.orderCount, 3);
      expect(link.vehicle?.id, 'v-1');
      expect(link.vehicle?.displayName, 'Toyota Prius');
    });

    test('a malformed nested vehicle degrades to null, link survives', () {
      final link = CustomerVehicleLink.fromJson({
        'id': 'tv-1',
        'vehicle': {'plate': '1234УБА'}, // no vehicle id
      });
      expect(link.id, 'tv-1');
      expect(link.vehicle, isNull);
      expect(link.isPostpaid, isFalse);
      expect(link.orderCount, 0);
    });

    test('a missing link id still throws', () {
      expect(
        () => CustomerVehicleLink.fromJson({'isPostpaid': true}),
        throwsA(isA<CustomerParseException>()),
      );
    });

    test('numeric tolerance: whole doubles and numeric strings', () {
      final ref = CustomerVehicleRef.fromJson({
        'id': 'v-1',
        'year': 2019.0,
        'mileage': '120000',
      });
      expect(ref.year, 2019);
      expect(ref.mileage, 120000);

      final bad = CustomerVehicleRef.fromJson({
        'id': 'v-1',
        'year': 'twenty nineteen',
        'mileage': true,
      });
      expect(bad.year, isNull);
      expect(bad.mileage, isNull);
      expect(bad.displayName, 'Тодорхойгүй');
    });
  });

  group('CustomerPageDto', () {
    test('parses the list envelope with buildMeta pagination', () {
      final dto = CustomerPageDto.fromJson({
        'customers': [
          {'id': 'c1', 'fullName': 'Бат'},
          {'id': 'c2', 'fullName': 'Дорж'},
        ],
        'pagination': pagination(total: 2),
      });

      expect(dto.items.map((c) => c.id), ['c1', 'c2']);
      expect(dto.pagination.total, 2);
      expect(dto.pagination.hasNext, isFalse);
    });

    test('skips malformed rows instead of blanking the page', () {
      final dto = CustomerPageDto.fromJson({
        'customers': [
          {'id': 'c1'},
          'not-a-map',
          {'fullName': 'no id'},
          {'id': 'c2'},
        ],
        'pagination': pagination(total: 4),
      });

      expect(dto.items.map((c) => c.id), ['c1', 'c2']);
    });

    test('throws for a non-map envelope or a non-list customers', () {
      expect(
        () => CustomerPageDto.fromJson('nope'),
        throwsA(isA<CustomerParseException>()),
      );
      expect(
        () => CustomerPageDto.fromJson({
          'customers': {'id': 'c1'},
          'pagination': pagination(),
        }),
        throwsA(isA<CustomerParseException>()),
      );
    });

    test('throws for a missing or nonsensical pagination block', () {
      expect(
        () => CustomerPageDto.fromJson({'customers': const []}),
        throwsA(isA<CustomerParseException>()),
      );
      expect(
        () => CustomerPageDto.fromJson({
          'customers': const [],
          'pagination': pagination(page: 0),
        }),
        throwsA(isA<CustomerParseException>()),
      );
      expect(
        () => CustomerPageDto.fromJson({
          'customers': const [],
          'pagination': {
            'page': 1,
            'pageSize': 50,
            'total': 0,
            'totalPages': 1,
            'hasPrev': 'no',
            'hasNext': false,
          },
        }),
        throwsA(isA<CustomerParseException>()),
      );
    });
  });

  group('CustomerEnvelopeDto', () {
    test('unwraps {customer}', () {
      final dto = CustomerEnvelopeDto.fromJson({
        'customer': {'id': 'c1', 'phone': '99001122'},
      });
      expect(dto.value.id, 'c1');
    });

    test('throws when the customer key is absent or not a map', () {
      expect(
        () => CustomerEnvelopeDto.fromJson({'ok': true}),
        throwsA(isA<CustomerParseException>()),
      );
      expect(
        () => CustomerEnvelopeDto.fromJson({'customer': 'c1'}),
        throwsA(isA<CustomerParseException>()),
      );
    });
  });

  group('CustomerDetailDto', () {
    test('parses {customer, vehicles}', () {
      final dto = CustomerDetailDto.fromJson({
        'customer': {'id': 'c1', 'fullName': 'Бат'},
        'vehicles': [
          {
            'id': 'tv-1',
            'isPostpaid': false,
            'orderCount': 2,
            'vehicle': {'id': 'v-1', 'plate': '1234УБА'},
          },
        ],
      });

      expect(dto.value.customer.id, 'c1');
      expect(dto.value.vehicles.single.vehicle?.plate, '1234УБА');
    });

    test('a missing or malformed vehicles degrades to an empty list', () {
      expect(
        CustomerDetailDto.fromJson({
          'customer': {'id': 'c1'},
        }).value.vehicles,
        isEmpty,
      );
      expect(
        CustomerDetailDto.fromJson({
          'customer': {'id': 'c1'},
          'vehicles': 'nope',
        }).value.vehicles,
        isEmpty,
      );
    });

    test('still throws when the customer itself is unusable', () {
      expect(
        () => CustomerDetailDto.fromJson({'vehicles': const []}),
        throwsA(isA<CustomerParseException>()),
      );
    });
  });

  group('CustomerDeleteResultDto', () {
    test('parses {ok, id, fullName}', () {
      final dto = CustomerDeleteResultDto.fromJson({
        'ok': true,
        'id': 'c1',
        'fullName': 'Бат',
      }, requestedId: 'c1');
      expect(dto.value.id, 'c1');
      expect(dto.value.fullName, 'Бат');
      expect(dto.value.ok, isTrue);
    });

    test('falls back to the requested id, tolerates a null fullName', () {
      // `deleteCustomerCommand` types `fullName` as `string | null`.
      final dto = CustomerDeleteResultDto.fromJson({
        'ok': true,
        'fullName': null,
      }, requestedId: 'c9');
      expect(dto.value.id, 'c9');
      expect(dto.value.fullName, isNull);
    });
  });

  group('CustomerHistoryPageDto', () {
    test('parses {orders, meta} — note the meta key, not pagination', () {
      final dto = CustomerHistoryPageDto.fromJson({
        'orders': [
          {
            'id': 'o1',
            'number': 'SO-001',
            'status': 'COMPLETED',
            'paymentStatus': 'PAID',
            'scheduledAt': null,
            'completedAt': '2026-09-10T10:00:00.000Z',
            'createdAt': '2026-09-09T10:00:00.000Z',
            'totalAmount': '150000',
            'branch': {'name': 'Толгойт'},
            'itemCount': 4,
            'vehicle': {
              'id': 'v-1',
              'plate': '1234УБА',
              'make': 'Toyota',
              'model': 'Prius',
            },
          },
        ],
        'meta': pagination(total: 1),
      });

      final order = dto.items.single;
      expect(order.id, 'o1');
      expect(order.number, 'SO-001');
      // Raw strings, deliberately not the Orders feature's enums.
      expect(order.status, 'COMPLETED');
      expect(order.paymentStatus, 'PAID');
      expect(order.scheduledAt, isNull);
      expect(order.completedAt, isNotNull);
      // Raw decimal string, never a parsed double.
      expect(order.totalAmount, '150000');
      expect(order.branchName, 'Толгойт');
      expect(order.itemCount, 4);
      expect(order.vehicle?.plate, '1234УБА');
      expect(dto.pagination.total, 1);
    });

    test('a null vehicle and a missing branch degrade', () {
      final dto = CustomerHistoryPageDto.fromJson({
        'orders': [
          {'id': 'o1', 'vehicle': null},
        ],
        'meta': pagination(),
      });
      final order = dto.items.single;
      expect(order.vehicle, isNull);
      expect(order.branchName, isNull);
      expect(order.itemCount, 0);
      expect(order.totalAmount, isNull);
    });

    test('a pagination block under the wrong key throws', () {
      expect(
        () => CustomerHistoryPageDto.fromJson({
          'orders': const [],
          'pagination': pagination(),
        }),
        throwsA(isA<CustomerParseException>()),
      );
    });
  });

  group('broadcast envelopes', () {
    test('parses {recipientCount} and {notified}', () {
      expect(
        BroadcastRecipientCountDto.fromJson({'recipientCount': 12}).value,
        12,
      );
      expect(
        CustomerBroadcastResultDto.fromJson({'notified': 0}).value.notified,
        0,
      );
    });

    test('a missing or non-int count throws — there is no safe default', () {
      expect(
        () => BroadcastRecipientCountDto.fromJson(const {}),
        throwsA(isA<CustomerParseException>()),
      );
      expect(
        () => CustomerBroadcastResultDto.fromJson({'notified': '3'}),
        throwsA(isA<CustomerParseException>()),
      );
    });
  });

  group('CustomerFailure.classify', () {
    test('maps the measured wire shapes to distinct typed failures', () {
      expect(
        CustomerFailure.classify(statusCode: 403),
        CustomerFailure.forbidden,
      );
      expect(
        CustomerFailure.classify(statusCode: 400),
        CustomerFailure.badRequest,
      );
      expect(
        CustomerFailure.classify(statusCode: 404),
        CustomerFailure.notFound,
      );
      expect(
        CustomerFailure.classify(
          statusCode: 422,
          fieldErrors: const {'phone': 'x'},
        ),
        CustomerFailure.validation,
      );
      expect(
        CustomerFailure.classify(
          statusCode: 409,
          fieldErrors: const {'phone': 'x'},
        ),
        CustomerFailure.phoneConflict,
      );
      expect(
        CustomerFailure.classify(
          statusCode: 409,
          code: CustomerErrorCode.customerInUse,
        ),
        CustomerFailure.inUse,
      );
      expect(CustomerFailure.classify(statusCode: 500), CustomerFailure.other);
    });

    test('a 422 without fieldErrors is a plan limit, code or not', () {
      // MAX_CUSTOMERS from `POST /customers` — the route drops the code, so
      // absence of fieldErrors is the only available discriminator.
      expect(
        CustomerFailure.classify(statusCode: 422),
        CustomerFailure.planLimit,
      );
      expect(
        CustomerFailure.classify(statusCode: 422, fieldErrors: const {}),
        CustomerFailure.planLimit,
      );
      // DAILY_LIMIT_REACHED from `POST /customers/notify` — same shape, and
      // here the code IS present.
      expect(
        CustomerFailure.classify(
          statusCode: 422,
          code: CustomerErrorCode.dailyLimitReached,
        ),
        CustomerFailure.planLimit,
      );
    });
  });
}
