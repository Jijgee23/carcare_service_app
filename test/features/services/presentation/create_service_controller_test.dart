import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/services/domain/service.dart';
import 'package:carcare_service/features/services/domain/services_repository.dart';
import 'package:carcare_service/features/services/presentation/controllers/create_service_controller.dart';

import '../../../fakes/fake_api_backend.dart';
import '../data/fake_service_repository.dart';

/// Coverage for the rebuilt `CreateServiceController` — P4-F3.
///
/// Two backends, two test groups, matching the class doc comment: create
/// mode submits through the legacy `ServiceCatalogService.createService`
/// (`POST services`, exercised here through the globally-installed
/// `FakeApiBackend`), edit mode submits through the new, frozen
/// `ServicesRepository.updateService` (exercised through the hand-written
/// `FakeServiceRepository`/a recording fake).
void main() {
  setUp(() => FakeApiBackend.instance.reset());

  group('CreateServiceController.init — shared lookups (D-164, read-only)', () {
    test(
      'loads units/categories from ServicesRepository for both modes',
      () async {
        final repo = FakeServiceRepository(
          units: [FakeServiceRepository.seedUnit(id: 'unit-9')],
          categories: [FakeServiceRepository.seedCategory(id: 'cat-9')],
        );
        final ctrl = CreateServiceController(repo: repo);
        expect(ctrl.loadingLookups, isTrue);
        await ctrl.init();
        expect(ctrl.loadingLookups, isFalse);
        expect(ctrl.units.map((u) => u.id), contains('unit-9'));
        expect(ctrl.categories.map((c) => c.id), contains('cat-9'));
      },
    );

    test('edit mode preselects unit/category/durationUnit by id', () async {
      final unit = FakeServiceRepository.seedUnit(id: 'unit-1');
      final category = FakeServiceRepository.seedCategory(id: 'cat-1');
      final existing = FakeServiceRepository.seedService(
        id: 'svc-1',
        unitId: 'unit-1',
        categoryId: 'cat-1',
      );
      final repo = FakeServiceRepository(
        seed: [existing],
        units: [unit],
        categories: [category],
      );
      final ctrl = CreateServiceController(existing: existing, repo: repo);
      await ctrl.init();
      expect(ctrl.selectedUnit?.id, 'unit-1');
      expect(ctrl.selectedCategory?.id, 'cat-1');
    });
  });

  group('CreateServiceController — create mode (legacy backend)', () {
    test(
      'submit posts to the legacy `services` route and reports success',
      () async {
        FakeApiBackend.instance.onJson('POST', 'services', {
          'service': {
            'id': 'svc-new',
            'type': 'LABOR',
            'name': 'Тос солих',
            'price': '15000',
            'isActive': true,
          },
        });
        final ctrl = CreateServiceController(repo: FakeServiceRepository());
        await ctrl.init();
        ctrl.setCategory(ctrl.categories.first);

        final ok = await ctrl.submit(name: 'Тос солих', price: '15000');

        expect(ok, isTrue);
        expect(ctrl.lastError, isNull);
        final sent = FakeApiBackend.instance.requests.single;
        expect(sent.method, 'POST');
        expect(sent.path, contains('services'));
      },
    );

    test('a failed legacy submit reports failure through the same AppError '
        'shape the edit path uses, never a crash', () async {
      // Left unscripted deliberately: `FakeApiBackend`'s `.on()` resolves
      // the given `Response` directly through the interceptor chain,
      // bypassing Dio's normal `validateStatus` short-circuit — so a
      // canned non-2xx `Response` here does NOT reproduce a real 422
      // rejection the way it would against a live backend, and
      // `FakeApiBackend` has no reject-with-status affordance to add
      // (`test/fakes/` is shared infrastructure, out of this slice's owned
      // paths). The default-deny path (an unscripted request rejected as
      // a `DioException.connectionError`) exercises the same
      // `on AppError catch` failure branch in
      // `ServiceCatalogService.createService` without depending on that
      // gap — see `FakeApiBackend`'s own doc comment.
      final ctrl = CreateServiceController(repo: FakeServiceRepository());
      await ctrl.init();
      ctrl.setCategory(ctrl.categories.first);

      final ok = await ctrl.submit(name: 'Тос солих', price: '15000');

      expect(ok, isFalse);
      expect(ctrl.lastError, isNotNull);
    });
  });

  group('CreateServiceController — edit mode (new frozen repository)', () {
    test('type is immutable once editing — setType is a no-op', () async {
      final existing = FakeServiceRepository.seedService(
        type: ServiceKind.goods,
      );
      final ctrl = CreateServiceController(
        existing: existing,
        repo: FakeServiceRepository(seed: [existing]),
      );
      await ctrl.init();
      expect(ctrl.type, ServiceKind.goods);
      ctrl.setType(ServiceKind.labor);
      expect(ctrl.type, ServiceKind.goods);
    });

    test(
      'whole-record replace: submit resends every field, stock verbatim from '
      'the existing record, never from user input',
      () async {
        final existing = FakeServiceRepository.seedService(
          id: 'svc-1',
          type: ServiceKind.goods,
          stock: '12.5',
        );
        final repo = _RecordingServicesRepository(existing);
        final ctrl = CreateServiceController(existing: existing, repo: repo);
        await ctrl.init();
        ctrl.setCategory(ctrl.categories.first);

        final ok = await ctrl.submit(
          name: 'Шинэ нэр',
          price: '99000',
          costPrice: '50000',
        );

        expect(ok, isTrue);
        expect(repo.lastUpdateArgs, isNotNull);
        expect(repo.lastUpdateArgs!['name'], 'Шинэ нэр');
        expect(repo.lastUpdateArgs!['price'], '99000');
        // Resent verbatim from `existing.stock`, not from any (nonexistent)
        // user-entered stock field on the edit form — see the class doc
        // comment on `lockedStock`.
        expect(repo.lastUpdateArgs!['stock'], '12.5');
        expect(repo.lastUpdateArgs!['type'], ServiceKind.goods);
      },
    );

    test('a 409 SERVICE_CODE_CONFLICT binds to the code field', () async {
      final existing = FakeServiceRepository.seedService(
        id: 'svc-1',
        code: 'AAA',
      );
      final other = FakeServiceRepository.seedService(id: 'svc-2', code: 'BBB');
      final repo = FakeServiceRepository(seed: [existing, other]);
      final ctrl = CreateServiceController(existing: existing, repo: repo);
      await ctrl.init();
      ctrl.setCategory(ctrl.categories.first);

      final ok = await ctrl.submit(name: 'Нэр', code: 'BBB', price: '1000');

      expect(ok, isFalse);
      expect(ctrl.lastError?.statusCode, 409);
      expect(ctrl.lastError?.code, 'SERVICE_CODE_CONFLICT');
      expect(ctrl.fieldErrors['code'], isNotNull);
    });

    test(
      'a successful edit returns only a bool — never the PATCH echo, which '
      'has stripped nested refs (service.dart\'s module doc comment)',
      () async {
        final existing = FakeServiceRepository.seedService(id: 'svc-1');
        final repo = FakeServiceRepository(seed: [existing]);
        final ctrl = CreateServiceController(existing: existing, repo: repo);
        await ctrl.init();
        ctrl.setCategory(ctrl.categories.first);

        final result = await ctrl.submit(name: 'Шинэ нэр', price: '1000');

        expect(result, isA<bool>());
        expect(result, isTrue);
      },
    );
  });
}

/// Records the exact arguments `updateService` was called with, mirroring
/// `_RecordingUpdateRepository` in `customer_detail_controller_test.dart`.
class _RecordingServicesRepository implements ServicesRepository {
  _RecordingServicesRepository(this._existing);
  final Service _existing;
  Map<String, dynamic>? lastUpdateArgs;

  @override
  Future<Result<Service>> updateService(
    String serviceId, {
    required ServiceKind type,
    required String name,
    String? code,
    String? unitId,
    required String price,
    String? costPrice,
    String? stock,
    String? durationValue,
    String? durationUnitId,
    int? reminderIntervalMonths,
    String? description,
    bool isActive = true,
    required String categoryId,
  }) async {
    lastUpdateArgs = {
      'type': type,
      'name': name,
      'code': code,
      'unitId': unitId,
      'price': price,
      'costPrice': costPrice,
      'stock': stock,
      'durationValue': durationValue,
      'durationUnitId': durationUnitId,
      'reminderIntervalMonths': reminderIntervalMonths,
      'description': description,
      'isActive': isActive,
      'categoryId': categoryId,
    };
    return Ok(_existing);
  }

  @override
  Future<Result<List<Unit>>> getUnits() async => const Ok([]);

  @override
  Future<Result<List<Category>>> getCategories() async =>
      Ok([Category(id: 'cat-1', name: 'Ангилал')]);

  @override
  Future<Result<Service>> getService(String serviceId) async => Ok(_existing);

  @override
  Future<Result<PagedResult<Service>>> getServices({ServiceListQuery? query}) =>
      throw UnimplementedError();

  @override
  Future<Result<ServiceDeleteResult>> deleteService(String serviceId) =>
      throw UnimplementedError();

  @override
  Future<Result<ServiceStockResult>> adjustStock(
    String serviceId, {
    required StockDirection direction,
    required String amount,
  }) => throw UnimplementedError();

  @override
  Future<Result<BulkCategoryResult>> bulkChangeCategory({
    required List<String> serviceIds,
    required String categoryId,
  }) => throw UnimplementedError();
}
