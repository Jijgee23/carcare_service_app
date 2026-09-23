import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/services/domain/service.dart';
import 'package:carcare_service/features/services/domain/services_repository.dart';
import 'package:carcare_service/features/services/presentation/controllers/service_detail_controller.dart';

import '../data/fake_service_repository.dart';

/// Coverage for the new `ServiceDetailController` — P4-F3.
///
/// Mirrors `customer_detail_controller_test.dart`'s conventions: fetch-by-id
/// cold start, a stale-response generation guard, and the delete/adjustStock
/// outcomes the detail screen renders distinctly.
class _QueuedDetailRepository implements ServicesRepository {
  final requested = <String>[];
  final pending = <Completer<Result<Service>>>[];

  @override
  Future<Result<Service>> getService(String serviceId) {
    requested.add(serviceId);
    final completer = Completer<Result<Service>>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<Result<PagedResult<Service>>> getServices({ServiceListQuery? query}) =>
      throw UnimplementedError();

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
  }) => throw UnimplementedError();

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

  @override
  Future<Result<List<Unit>>> getUnits() => throw UnimplementedError();

  @override
  Future<Result<List<Category>>> getCategories() => throw UnimplementedError();
}

void main() {
  group('ServiceDetailController.load', () {
    test('cold start fetches by id — no preloaded summary required', () async {
      final repo = FakeServiceRepository(
        seed: [FakeServiceRepository.seedService(id: 'svc-1')],
      );
      final ctrl = ServiceDetailController(serviceId: 'svc-1', repo: repo);
      expect(ctrl.state, isA<AsyncLoading<Service>>());
      await ctrl.load();
      expect(ctrl.state, isA<AsyncData<Service>>());
      expect(ctrl.service?.id, 'svc-1');
    });

    test('surfaces a 404 as AsyncError rather than crashing', () async {
      final repo = FakeServiceRepository(
        seed: [FakeServiceRepository.seedService(id: 'svc-1')],
      );
      final ctrl = ServiceDetailController(serviceId: 'missing', repo: repo);
      await ctrl.load();
      expect(ctrl.state, isA<AsyncError<Service>>());
    });

    test(
      'a stale in-flight getService response never overwrites a newer one',
      () async {
        final repo = _QueuedDetailRepository();
        final ctrl = ServiceDetailController(serviceId: 'svc-1', repo: repo);

        final first = ctrl.load();
        final second = ctrl.load();
        expect(repo.pending.length, 2);

        repo.pending[1].complete(
          Ok(FakeServiceRepository.seedService(id: 'svc-1', name: 'Шинэ')),
        );
        repo.pending[0].complete(
          Ok(FakeServiceRepository.seedService(id: 'svc-1', name: 'Хуучин')),
        );
        await Future.wait([first, second]);

        expect(ctrl.service?.name, 'Шинэ');
      },
    );
  });

  group('ServiceDetailController.delete', () {
    test('archives when the service has order-item history', () async {
      final repo = FakeServiceRepository(
        seed: [
          FakeServiceRepository.seedService(id: 'svc-1', orderItemCount: 3),
        ],
      );
      final ctrl = ServiceDetailController(serviceId: 'svc-1', repo: repo);
      await ctrl.load();
      final result = await ctrl.delete();
      expect(result, isA<Ok<ServiceDeleteResult>>());
      expect(
        (result as Ok<ServiceDeleteResult>).value.outcome,
        ServiceDeleteOutcome.archived,
      );
    });

    test('hard-deletes when unreferenced', () async {
      final repo = FakeServiceRepository(
        seed: [
          FakeServiceRepository.seedService(id: 'svc-1', orderItemCount: 0),
        ],
      );
      final ctrl = ServiceDetailController(serviceId: 'svc-1', repo: repo);
      await ctrl.load();
      final result = await ctrl.delete();
      expect(result, isA<Ok<ServiceDeleteResult>>());
      expect(
        (result as Ok<ServiceDeleteResult>).value.outcome,
        ServiceDeleteOutcome.deleted,
      );
    });
  });

  group('ServiceDetailController.adjustStock', () {
    test(
      'a successful adjustment reloads the detail with the new balance',
      () async {
        final repo = FakeServiceRepository(
          seed: [
            FakeServiceRepository.seedService(
              id: 'svc-1',
              type: ServiceKind.goods,
              stock: '10',
            ),
          ],
        );
        final ctrl = ServiceDetailController(serviceId: 'svc-1', repo: repo);
        await ctrl.load();

        final result = await ctrl.adjustStock(
          direction: StockDirection.incoming,
          amount: '5',
        );

        expect(result, isA<Ok<ServiceStockResult>>());
        expect(ctrl.service?.stock, '15.0');
      },
    );

    test(
      'a resulting negative balance surfaces as a field error on amount, not '
      'a generic failure',
      () async {
        final repo = FakeServiceRepository(
          seed: [
            FakeServiceRepository.seedService(
              id: 'svc-1',
              type: ServiceKind.goods,
              stock: '3',
            ),
          ],
        );
        final ctrl = ServiceDetailController(serviceId: 'svc-1', repo: repo);
        await ctrl.load();

        final result = await ctrl.adjustStock(
          direction: StockDirection.outgoing,
          amount: '10',
        );

        expect(result, isA<Err<ServiceStockResult>>());
        final error = (result as Err<ServiceStockResult>).error;
        expect(error.statusCode, 422);
        expect(error.fieldErrors?['amount'], isNotNull);
        // The stock reading must be untouched by the rejected adjustment.
        expect(ctrl.service?.stock, '3');
      },
    );
  });
}
