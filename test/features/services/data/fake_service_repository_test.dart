import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/services/domain/service.dart';
import 'package:carcare_service/features/services/domain/services_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_service_repository.dart';

/// P4-F1 — contract tests for [FakeServiceRepository].
///
/// The fake is a test double later slices' controller tests will build on,
/// so the rules it claims to mirror are asserted here. If one of these
/// fails, the fake is lying about the server and every test standing on it
/// is unsound.
void main() {
  test('implements the repository interface', () {
    expect(FakeServiceRepository(), isA<ServicesRepository>());
  });

  group('getServices', () {
    FakeServiceRepository build() => FakeServiceRepository(
      seed: [
        FakeServiceRepository.seedService(),
        FakeServiceRepository.seedService(
          id: 'svc-2',
          type: ServiceKind.labor,
          name: 'Тос солих',
          code: 'LAB-001',
          stock: null,
        ),
        FakeServiceRepository.seedService(
          id: 'svc-3',
          name: 'Хуучин бараа',
          isActive: false,
        ),
      ],
    );

    Future<List<String>> ids(
      FakeServiceRepository repo, [
      ServiceListQuery? q,
    ]) async {
      final result = await repo.getServices(query: q);
      return (result as Ok<PagedResult<Service>>).value.items
          .map((s) => s.id)
          .toList();
    }

    test('defaults to active-only — the archived row is hidden', () async {
      expect(await ids(build()), ['svc-1', 'svc-2']);
    });

    test('includeInactive shows both, never inactive-only', () async {
      expect(
        await ids(build(), const ServiceListQuery(includeInactive: true)),
        ['svc-1', 'svc-2', 'svc-3'],
      );
    });

    test('type filters to exactly that kind', () async {
      expect(
        await ids(build(), const ServiceListQuery(type: ServiceKind.labor)),
        ['svc-2'],
      );
    });

    test('q matches name, code and description case-insensitively', () async {
      expect(await ids(build(), const ServiceListQuery(q: 'наклад')), [
        'svc-1',
      ]);
      expect(await ids(build(), const ServiceListQuery(q: 'lab-001')), [
        'svc-2',
      ]);
    });

    test('pagination clamps and reports correctly', () async {
      final repo = build();
      final result = await repo.getServices(
        query: const ServiceListQuery(pageSize: 1, page: 2),
      );
      final page = (result as Ok<PagedResult<Service>>).value;
      expect(page.items.single.id, 'svc-2');
      expect(page.pagination.hasNext, isFalse);
      expect(page.pagination.hasPrev, isTrue);
    });
  });

  group('getService', () {
    test('404s for an unknown id', () async {
      final result = await FakeServiceRepository().getService('nope');
      final error = (result as Err).error;
      expect(error.code, 'SERVICE_NOT_FOUND');
      expect(error.statusCode, 404);
    });
  });

  group('updateService', () {
    test(
      'type is immutable — the caller-supplied value is discarded',
      () async {
        final repo = FakeServiceRepository();
        final result = await repo.updateService(
          'svc-1',
          type: ServiceKind.diagnostic,
          name: 'Наклад',
          price: '45000',
          categoryId: 'cat-1',
        );
        expect((result as Ok<Service>).value.type, ServiceKind.goods);
      },
    );

    test('stock is validated on a GOODS row but never persisted', () async {
      final repo = FakeServiceRepository();

      final bad = await repo.updateService(
        'svc-1',
        type: ServiceKind.goods,
        name: 'Наклад',
        price: '45000',
        stock: 'not-a-number',
        categoryId: 'cat-1',
      );
      expect((bad as Err).error.fieldErrors!['stock'], isNotNull);

      final ok = await repo.updateService(
        'svc-1',
        type: ServiceKind.goods,
        name: 'Наклад',
        price: '45000',
        stock: '999',
        categoryId: 'cat-1',
      );
      // The response never echoes stock at all — matches the measured
      // PATCH shape.
      expect((ok as Ok<Service>).value.stock, isNull);
      // And the stored row's real stock is untouched by the bogus 999.
      final refetched = (await repo.getService('svc-1') as Ok<Service>).value;
      expect(refetched.stock, '12.5');
    });

    test('a duplicate code is a 409 SERVICE_CODE_CONFLICT', () async {
      final repo = FakeServiceRepository(
        seed: [
          FakeServiceRepository.seedService(),
          FakeServiceRepository.seedService(id: 'svc-2', code: 'OTHER'),
        ],
      );
      final result = await repo.updateService(
        'svc-2',
        type: ServiceKind.goods,
        name: 'X',
        code: 'BRK-001',
        price: '1',
        categoryId: 'cat-1',
      );
      final error = (result as Err).error;
      expect(error.statusCode, 409);
      expect(error.code, 'SERVICE_CODE_CONFLICT');
    });

    test('a missing name/price/categoryId is 422 VALIDATION_FAILED', () async {
      final repo = FakeServiceRepository();
      final result = await repo.updateService(
        'svc-1',
        type: ServiceKind.goods,
        name: '',
        price: 'nope',
        categoryId: '',
      );
      final error = (result as Err).error;
      expect(error.statusCode, 422);
      expect(
        error.fieldErrors!.keys,
        containsAll(['name', 'price', 'categoryId']),
      );
    });

    test('the returned Service mirrors the measured PATCH shape — no nested '
        'refs, flat ids, reminderIntervalMonths present', () async {
      final repo = FakeServiceRepository();
      final result = await repo.updateService(
        'svc-1',
        type: ServiceKind.goods,
        name: 'Наклад 2',
        unitId: 'unit-1',
        price: '50000',
        reminderIntervalMonths: 6,
        categoryId: 'cat-1',
      );
      final updated = (result as Ok<Service>).value;
      expect(updated.unit, isNull);
      expect(updated.category, isNull);
      expect(updated.unitId, 'unit-1');
      expect(updated.categoryId, 'cat-1');
      expect(updated.reminderIntervalMonths, 6);
      expect(updated.createdAt, isNull);
    });

    test('404s for an unknown id', () async {
      final result = await FakeServiceRepository().updateService(
        'nope',
        type: ServiceKind.goods,
        name: 'X',
        price: '1',
        categoryId: 'cat-1',
      );
      expect((result as Err).error.code, 'SERVICE_NOT_FOUND');
    });
  });

  group('deleteService', () {
    test('archives when the service has order-item history', () async {
      final repo = FakeServiceRepository(
        seed: [FakeServiceRepository.seedService(orderItemCount: 3)],
      );
      final result = await repo.deleteService('svc-1');
      expect((result as Ok).value.outcome, ServiceDeleteOutcome.archived);
      // The row still exists, just inactive.
      final refetched = (await repo.getService('svc-1')) as Ok<Service>;
      expect(refetched.value.isActive, isFalse);
    });

    test('hard-deletes when there is no order-item history', () async {
      final repo = FakeServiceRepository();
      final result = await repo.deleteService('svc-1');
      expect((result as Ok).value.outcome, ServiceDeleteOutcome.deleted);
      expect((await repo.getService('svc-1')), isA<Err>());
    });

    test('404s for an unknown id', () async {
      final result = await FakeServiceRepository().deleteService('nope');
      expect((result as Err).error.code, 'SERVICE_NOT_FOUND');
    });
  });

  group('adjustStock', () {
    test('in adds, out subtracts', () async {
      final repo = FakeServiceRepository();
      final inResult = await repo.adjustStock(
        'svc-1',
        direction: StockDirection.incoming,
        amount: '5',
      );
      expect((inResult as Ok<ServiceStockResult>).value.stock, '17.5');

      final outResult = await repo.adjustStock(
        'svc-1',
        direction: StockDirection.outgoing,
        amount: '2.5',
      );
      expect((outResult as Ok<ServiceStockResult>).value.stock, '15.0');
    });

    test('rejects a resulting negative balance rather than clamping', () async {
      final repo = FakeServiceRepository();
      final result = await repo.adjustStock(
        'svc-1',
        direction: StockDirection.outgoing,
        amount: '999',
      );
      final error = (result as Err).error;
      expect(error.statusCode, 422);
      expect(error.fieldErrors!['amount'], isNotNull);
      // Nothing was written.
      final refetched = (await repo.getService('svc-1') as Ok<Service>).value;
      expect(refetched.stock, '12.5');
    });

    test('is GOODS-only — a LABOR row 404s, not a validation error', () async {
      final repo = FakeServiceRepository(
        seed: [
          FakeServiceRepository.seedService(
            id: 'svc-2',
            type: ServiceKind.labor,
            stock: null,
          ),
        ],
      );
      final result = await repo.adjustStock(
        'svc-2',
        direction: StockDirection.incoming,
        amount: '1',
      );
      expect((result as Err).error.code, 'SERVICE_NOT_FOUND');
    });
  });

  group('bulkChangeCategory', () {
    test('per-item: a missing id fails, the rest still succeed', () async {
      final repo = FakeServiceRepository(
        seed: [
          FakeServiceRepository.seedService(),
          FakeServiceRepository.seedService(id: 'svc-2', categoryId: 'cat-2'),
        ],
        categories: [
          FakeServiceRepository.seedCategory(),
          FakeServiceRepository.seedCategory(id: 'cat-2'),
        ],
      );
      final result = await repo.bulkChangeCategory(
        serviceIds: const ['svc-1', 'svc-2', 'svc-missing'],
        categoryId: 'cat-2',
      );
      final value = (result as Ok<BulkCategoryResult>).value;
      expect(value.succeeded, 2);
      expect(value.failed, 1);
      expect(value.errors.single, contains('svc-missing'));
    });

    test(
      'a missing categoryId is a whole-request rejection, not per-item',
      () async {
        final repo = FakeServiceRepository();
        final result = await repo.bulkChangeCategory(
          serviceIds: const ['svc-1'],
          categoryId: '',
        );
        expect((result as Err).error.code, 'CATEGORY_REQUIRED');
      },
    );

    test('an unknown categoryId 404s the whole request', () async {
      final repo = FakeServiceRepository();
      final result = await repo.bulkChangeCategory(
        serviceIds: const ['svc-1'],
        categoryId: 'cat-nope',
      );
      expect((result as Err).error.code, 'CATEGORY_NOT_FOUND');
    });

    test('an empty selection is a whole-request rejection', () async {
      final repo = FakeServiceRepository();
      final result = await repo.bulkChangeCategory(
        serviceIds: const [],
        categoryId: 'cat-1',
      );
      expect((result as Err).error.code, 'EMPTY_SELECTION');
    });
  });

  group('lookups', () {
    test('getUnits and getCategories are read-only seeds', () async {
      final repo = FakeServiceRepository();
      final units = (await repo.getUnits() as Ok<List<Unit>>).value;
      final categories =
          (await repo.getCategories() as Ok<List<Category>>).value;
      expect(units.single.id, 'unit-1');
      expect(categories.single.id, 'cat-1');
    });
  });
}
