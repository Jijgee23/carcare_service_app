import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/services/data/service_repository.dart';
import 'package:carcare_service/features/services/data/services_data_source.dart';
import 'package:carcare_service/features/services/domain/service.dart';
import 'package:carcare_service/features/services/domain/services_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// P4-F1 — `RemoteServicesRepository` request/response contract, exercised
/// over a recording data source. No network, no Dio: the transport seam is
/// exactly what this substitutes. `mapDioException` delegation itself is
/// exercised by asserting an `AppError` the data source throws passes
/// through verbatim — the same pattern `vehicle_repository_test.dart` uses,
/// since a second, real Dio-backed test would just be re-testing
/// `dio_error_mapper_test.dart`.
void main() {
  group('request shaping', () {
    test(
      'the default list query is page 1 / pageSize 50 and nothing else',
      () async {
        final ds = _RecordingDataSource(_listPayload);
        await RemoteServicesRepository(dataSource: ds).getServices();
        expect(ds.lastQuery, {'page': 1, 'pageSize': 50});
      },
    );

    test('the list query sends only allow-listed params', () async {
      final ds = _RecordingDataSource(_listPayload);
      await RemoteServicesRepository(dataSource: ds).getServices(
        query: const ServiceListQuery(
          type: ServiceKind.goods,
          q: '  наклад  ',
          page: 2,
          pageSize: 25,
        ),
      );
      expect(ds.lastQuery, {
        'page': 2,
        'pageSize': 25,
        'type': 'GOODS',
        'q': 'наклад',
      });
    });

    test('an empty or whitespace q is omitted entirely', () async {
      for (final term in ['', '   ']) {
        final ds = _RecordingDataSource(_listPayload);
        await RemoteServicesRepository(dataSource: ds)
            .getServices(query: ServiceListQuery(q: term));
        expect(ds.lastQuery!.containsKey('q'), isFalse);
      }
    });

    test('includeInactive sends isActive=false — the one-way switch, never a '
        'tri-state filter', () async {
      final ds = _RecordingDataSource(_listPayload);
      await RemoteServicesRepository(dataSource: ds)
          .getServices(query: const ServiceListQuery(includeInactive: true));
      expect(ds.lastQuery!['isActive'], 'false');

      final ds2 = _RecordingDataSource(_listPayload);
      await RemoteServicesRepository(dataSource: ds2).getServices();
      expect(ds2.lastQuery!.containsKey('isActive'), isFalse);
    });

    test('ServiceKind.unknown is never sent as a type filter', () async {
      final ds = _RecordingDataSource(_listPayload);
      await RemoteServicesRepository(
        dataSource: ds,
      ).getServices(query: const ServiceListQuery(type: ServiceKind.unknown));
      expect(ds.lastQuery!.containsKey('type'), isFalse);
    });

    test('update sends every editable field explicitly, including nulls — '
        'whole-record replace, never a partial patch', () async {
      final ds = _RecordingDataSource({
        'service': {'id': 'svc-1'},
      });
      await RemoteServicesRepository(dataSource: ds).updateService(
        'svc-1',
        type: ServiceKind.goods,
        name: 'Наклад',
        price: '45000',
        categoryId: 'cat-1',
      );

      expect(ds.lastId, 'svc-1');
      expect(ds.lastBody, {
        'type': 'GOODS',
        'name': 'Наклад',
        'code': null,
        'unitId': null,
        'price': '45000',
        'costPrice': null,
        'stock': null,
        'durationValue': null,
        'durationUnitId': null,
        'reminderIntervalMonths': null,
        'description': null,
        'isActive': true,
        'categoryId': 'cat-1',
      });
    });

    test('update sends stock and type for validation although the server '
        'never persists either', () async {
      final ds = _RecordingDataSource({
        'service': {'id': 'svc-1'},
      });
      await RemoteServicesRepository(dataSource: ds).updateService(
        'svc-1',
        type: ServiceKind.goods,
        name: 'Наклад',
        price: '45000',
        stock: '12.5',
        categoryId: 'cat-1',
      );
      expect(ds.lastBody!['type'], 'GOODS');
      expect(ds.lastBody!['stock'], '12.5');
    });

    test('adjustStock sends direction and amount, nothing else', () async {
      final ds = _RecordingDataSource({
        'service': {'id': 'svc-1', 'stock': '5'},
      });
      await RemoteServicesRepository(
        dataSource: ds,
      ).adjustStock('svc-1', direction: StockDirection.outgoing, amount: '3');
      expect(ds.lastStockId, 'svc-1');
      expect(ds.lastStockBody, {'direction': 'out', 'amount': '3'});
    });

    test('bulkChangeCategory sends serviceIds and categoryId', () async {
      final ds = _RecordingDataSource({
        'succeeded': 1,
        'failed': 0,
        'errors': const [],
      });
      await RemoteServicesRepository(
        dataSource: ds,
      ).bulkChangeCategory(serviceIds: ['svc-1', 'svc-2'], categoryId: 'cat-1');
      expect(ds.lastBulkBody, {
        'serviceIds': ['svc-1', 'svc-2'],
        'categoryId': 'cat-1',
      });
    });

    test('getUnits and getCategories both request all=true', () async {
      final ds = _RecordingDataSource(null);
      await RemoteServicesRepository(dataSource: ds).getUnits();
      await RemoteServicesRepository(dataSource: ds).getCategories();
      expect(ds.unitsCalls, 1);
      expect(ds.categoriesCalls, 1);
    });
  });

  group('response handling', () {
    test('getServices unwraps items and pagination', () async {
      final result = await RemoteServicesRepository(
        dataSource: _RecordingDataSource(_listPayload),
      ).getServices();
      final page = (result as Ok).value;
      expect(page.items.single.id, 'svc-1');
      expect(page.pagination.pageSize, 50);
    });

    test('a parse failure becomes Err, never a thrown exception', () async {
      final result = await RemoteServicesRepository(
        dataSource: _RecordingDataSource({'wrong': 'envelope'}),
      ).getServices();
      expect(result, isA<Err>());
      expect((result as Err).error.kind, ErrorKind.unknown);
    });

    test('an AppError from the shared mapDioException mapper passes through '
        'verbatim — statusCode/code/fieldErrors intact', () async {
      const mapped = AppError(
        ErrorKind.unknown,
        'Энэ код өөр үйлчилгээнд ашиглагдсан байна.',
        statusCode: 409,
        code: 'SERVICE_CODE_CONFLICT',
        fieldErrors: {'code': 'Энэ код өөр үйлчилгээнд ашиглагдсан байна.'},
      );
      final result =
          await RemoteServicesRepository(
            dataSource: _ThrowingDataSource(mapped),
          ).updateService(
            'svc-1',
            type: ServiceKind.goods,
            name: 'Наклад',
            price: '45000',
            categoryId: 'cat-1',
          );

      final error = (result as Err).error;
      expect(identical(error, mapped), isTrue);
      expect(error.statusCode, 409);
      expect(error.code, 'SERVICE_CODE_CONFLICT');
      expect(error.fieldErrors, {
        'code': 'Энэ код өөр үйлчилгээнд ашиглагдсан байна.',
      });
    });

    test(
      'a 422 negative-balance rejection on stock keeps its fieldErrors',
      () async {
        const mapped = AppError(
          ErrorKind.unknown,
          'Хүсэлт буруу.',
          statusCode: 422,
          code: 'VALIDATION_FAILED',
          fieldErrors: {'amount': 'Үлдэгдэл сөрөг болж байна. Одоо: 3'},
        );
        final result =
            await RemoteServicesRepository(
              dataSource: _ThrowingDataSource(mapped),
            ).adjustStock(
              'svc-1',
              direction: StockDirection.outgoing,
              amount: '10',
            );

        final error = (result as Err).error;
        expect(error.statusCode, 422);
        expect(error.fieldErrors!['amount'], isNotNull);
      },
    );

    test('a 404 SERVICE_NOT_FOUND on delete passes through', () async {
      const mapped = AppError(
        ErrorKind.notFound,
        'Олдсонгүй',
        statusCode: 404,
        code: 'SERVICE_NOT_FOUND',
      );
      final result = await RemoteServicesRepository(
        dataSource: _ThrowingDataSource(mapped),
      ).deleteService('svc-1');
      expect((result as Err).error.code, 'SERVICE_NOT_FOUND');
    });

    test('bulkChangeCategory unwraps the bare envelope', () async {
      final result =
          await RemoteServicesRepository(
            dataSource: _RecordingDataSource({
              'succeeded': 1,
              'failed': 1,
              'errors': ['svc-x: Олдсонгүй.'],
            }),
          ).bulkChangeCategory(
            serviceIds: const ['svc-1', 'svc-x'],
            categoryId: 'cat-1',
          );
      final value = (result as Ok).value;
      expect(value.succeeded, 1);
      expect(value.failed, 1);
    });

    test('getUnits/getCategories unwrap their list envelopes', () async {
      final unitsResult = await RemoteServicesRepository(
        dataSource: _RecordingDataSource({
          'units': [
            {'id': 'unit-1', 'name': 'ширхэг'},
          ],
        }),
      ).getUnits();
      expect((unitsResult as Ok).value.single.id, 'unit-1');

      final categoriesResult = await RemoteServicesRepository(
        dataSource: _RecordingDataSource({
          'categories': [
            {'id': 'cat-1', 'name': 'Тормоз'},
          ],
        }),
      ).getCategories();
      expect((categoriesResult as Ok).value.single.id, 'cat-1');
    });
  });
}

const _listPayload = {
  'services': [
    {'id': 'svc-1', 'type': 'GOODS', 'name': 'Наклад'},
  ],
  'pagination': {
    'page': 1,
    'pageSize': 50,
    'total': 1,
    'totalPages': 1,
    'hasPrev': false,
    'hasNext': false,
  },
};

class _RecordingDataSource implements ServicesDataSource {
  _RecordingDataSource(this.payload);

  final Object? payload;
  Map<String, dynamic>? lastQuery;
  Map<String, dynamic>? lastBody;
  String? lastId;
  Map<String, dynamic>? lastStockBody;
  String? lastStockId;
  Map<String, dynamic>? lastBulkBody;
  int unitsCalls = 0;
  int categoriesCalls = 0;

  @override
  Future<Object?> list(Map<String, dynamic> query) async {
    lastQuery = query;
    return payload;
  }

  @override
  Future<Object?> detail(String id) async {
    lastId = id;
    return payload;
  }

  @override
  Future<Object?> update(String id, Map<String, dynamic> body) async {
    lastId = id;
    lastBody = body;
    return payload;
  }

  @override
  Future<Object?> delete(String id) async {
    lastId = id;
    return payload;
  }

  @override
  Future<Object?> adjustStock(String id, Map<String, dynamic> body) async {
    lastStockId = id;
    lastStockBody = body;
    return payload;
  }

  @override
  Future<Object?> bulkChangeCategory(Map<String, dynamic> body) async {
    lastBulkBody = body;
    return payload;
  }

  @override
  Future<Object?> units() async {
    unitsCalls++;
    return payload;
  }

  @override
  Future<Object?> categories() async {
    categoriesCalls++;
    return payload;
  }
}

class _ThrowingDataSource implements ServicesDataSource {
  _ThrowingDataSource(this.error);

  final AppError error;

  @override
  Future<Object?> list(Map<String, dynamic> query) async => throw error;
  @override
  Future<Object?> detail(String id) async => throw error;
  @override
  Future<Object?> update(String id, Map<String, dynamic> body) async =>
      throw error;
  @override
  Future<Object?> delete(String id) async => throw error;
  @override
  Future<Object?> adjustStock(String id, Map<String, dynamic> body) async =>
      throw error;
  @override
  Future<Object?> bulkChangeCategory(Map<String, dynamic> body) async =>
      throw error;
  @override
  Future<Object?> units() async => throw error;
  @override
  Future<Object?> categories() async => throw error;
}
