import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/services/domain/service.dart';
import 'package:carcare_service/features/services/domain/services_repository.dart';
import 'package:carcare_service/features/services/presentation/controllers/service_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/completer_queue.dart';
import '../data/fake_service_repository.dart';

/// A repository whose `getServices` never resolves on its own — the test
/// controls exactly when and in what order each call completes, via
/// [CompleterQueue]. Every other method throws: this controller never calls
/// them, and a call reaching one is a bug in the test, not something to
/// paper over. Mirrors `vehicle_list_controller_test.dart`'s
/// `_QueuedVehiclesRepository` exactly.
class _QueuedServicesRepository implements ServicesRepository {
  final queue = CompleterQueue<Result<PagedResult<Service>>>();
  final requests = <ServiceListQuery?>[];

  @override
  Future<Result<PagedResult<Service>>> getServices({ServiceListQuery? query}) {
    requests.add(query);
    return queue.next();
  }

  @override
  Future<Result<Service>> getService(String serviceId) =>
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

Service _service(
  String id, {
  ServiceKind type = ServiceKind.labor,
  String name = 'Service',
}) => Service(id: id, type: type, name: name);

PagedResult<Service> _page(
  List<Service> items, {
  int page = 1,
  bool hasNext = false,
  int total = 0,
}) => PagedResult(
  items: items,
  pagination: PaginationMeta(
    page: page,
    pageSize: ServiceListController.defaultPageSize,
    total: total == 0 ? items.length : total,
    totalPages: hasNext ? page + 1 : page,
    hasPrev: page > 1,
    hasNext: hasNext,
  ),
);

void main() {
  group('race safety', () {
    test('a stale in-flight response cannot overwrite a newer one '
        '(loadServices vs loadServices)', () async {
      final repo = _QueuedServicesRepository();
      final controller = ServiceListController(
        repo: repo,
        searchDebounce: Duration.zero,
      );

      final oldLoad = controller.loadServices(); // call #0 — slow
      final newLoad = controller.loadServices(); // call #1 — fast
      expect(repo.queue.callCount, 2);

      // Resolve out of order: the newer request finishes first.
      repo.queue.resolve(1, Ok(_page([_service('new')])));
      await newLoad;
      repo.queue.resolve(0, Ok(_page([_service('old')])));
      await oldLoad;
      await Future<void>.delayed(Duration.zero);

      expect(controller.listState.valueOrNull!.single.id, 'new');
      controller.dispose();
    });

    test(
      'loadMore ignores a stale in-flight page after a fresh reload starts',
      () async {
        final repo = _QueuedServicesRepository();
        final controller = ServiceListController(
          repo: repo,
          searchDebounce: Duration.zero,
        );

        final firstLoad = controller.loadServices();
        repo.queue.resolve(
          0,
          Ok(_page([_service('first')], hasNext: true, total: 2)),
        );
        await firstLoad;

        final staleLoadMore = controller.loadMore(); // call #1
        final reload = controller.loadServices(); // call #2 — bumps generation
        repo.queue.resolve(2, Ok(_page([_service('reloaded')])));
        await reload;
        repo.queue.resolve(1, Ok(_page([_service('stale-page-2')])));
        await staleLoadMore;

        expect(controller.listState.valueOrNull!.single.id, 'reloaded');
        controller.dispose();
      },
    );
  });

  group('debounce', () {
    test('setQuery collapses rapid keystrokes into a single request', () async {
      final repo = _QueuedServicesRepository();
      final controller = ServiceListController(
        repo: repo,
        searchDebounce: const Duration(milliseconds: 20),
      );

      controller.setQuery('a');
      controller.setQuery('ab');
      controller.setQuery('abc');
      expect(repo.queue.callCount, 0, reason: 'debounced, nothing sent yet');

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(repo.queue.callCount, 1);
      expect(repo.requests.single?.q, 'abc');

      repo.queue.resolve(0, Ok(_page([])));
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
    });

    test('a fresh debounce cancels a still-pending earlier timer', () async {
      final repo = _QueuedServicesRepository();
      final controller = ServiceListController(
        repo: repo,
        searchDebounce: const Duration(milliseconds: 20),
      );

      controller.setQuery('first');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(repo.queue.callCount, 1);
      repo.queue.resolve(0, Ok(_page([])));
      await Future<void>.delayed(Duration.zero);

      controller.setQuery('second');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(repo.queue.callCount, 2);
      expect(repo.requests.last?.q, 'second');
      repo.queue.resolve(1, Ok(_page([])));
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
    });
  });

  group('kind filter tabs', () {
    test('the controller opens on the labor tab by default', () {
      final controller = ServiceListController(
        repo: _QueuedServicesRepository(),
        searchDebounce: Duration.zero,
      );
      expect(controller.type, ServiceKind.labor);
      controller.dispose();
    });

    test('setType sends the new kind to the repository and reloads', () async {
      final repo = _QueuedServicesRepository();
      final controller = ServiceListController(
        repo: repo,
        searchDebounce: Duration.zero,
      );

      final load = controller.setType(ServiceKind.goods);
      expect(controller.type, ServiceKind.goods);
      repo.queue.resolve(0, Ok(_page([])));
      await load;

      expect(repo.requests.single?.type, ServiceKind.goods);
      controller.dispose();
    });

    test('switching to the already-active tab does not re-fetch', () async {
      final repo = _QueuedServicesRepository();
      final controller = ServiceListController(
        repo: repo,
        searchDebounce: Duration.zero,
      );

      // Default is already ServiceKind.labor.
      await controller.setType(ServiceKind.labor);
      expect(repo.queue.callCount, 0);
      controller.dispose();
    });

    test('every kind tab is sent through to the repository', () async {
      final repo = _QueuedServicesRepository();
      final controller = ServiceListController(
        repo: repo,
        searchDebounce: Duration.zero,
      );

      for (final kind in [
        ServiceKind.goods,
        ServiceKind.diagnostic,
        ServiceKind.labor,
      ]) {
        final load = controller.setType(kind);
        repo.queue.resolve(repo.queue.callCount - 1, Ok(_page([])));
        await load;
        expect(repo.requests.last?.type, kind);
      }
      controller.dispose();
    });
  });

  group('pagination', () {
    test('loadMore appends to the already-loaded page', () async {
      final many = FakeServiceRepository(
        seed: [
          for (var i = 0; i < ServiceListController.defaultPageSize + 5; i++)
            _service('svc-$i'),
        ],
      );
      final paged = ServiceListController(
        repo: many,
        searchDebounce: Duration.zero,
      );
      await paged.loadServices();
      expect(
        paged.listState.valueOrNull!.length,
        ServiceListController.defaultPageSize,
      );
      expect(paged.hasNext, isTrue);

      await paged.loadMore();
      expect(
        paged.listState.valueOrNull!.length,
        ServiceListController.defaultPageSize + 5,
      );
      expect(paged.hasNext, isFalse);
      paged.dispose();
    });

    test(
      'a load-more error preserves the already-loaded data and is retryable',
      () async {
        final repo = _QueuedServicesRepository();
        final controller = ServiceListController(
          repo: repo,
          searchDebounce: Duration.zero,
        );

        final firstLoad = controller.loadServices();
        repo.queue.resolve(
          0,
          Ok(_page([_service('a'), _service('b')], hasNext: true, total: 4)),
        );
        await firstLoad;

        final loadMore = controller.loadMore();
        repo.queue.resolve(
          1,
          Err(const AppError(ErrorKind.network, 'сүлжээний алдаа')),
        );
        await loadMore;

        expect(controller.listState.valueOrNull!.length, 2);
        expect(controller.loadMoreError, isNotNull);
        expect(controller.loadingMore, isFalse);

        final retry = controller.loadMore();
        repo.queue.resolve(2, Ok(_page([_service('c')], page: 2)));
        await retry;

        expect(controller.listState.valueOrNull!.length, 3);
        expect(controller.loadMoreError, isNull);
        controller.dispose();
      },
    );
  });

  group('empty vs error states', () {
    test(
      'an empty page is AsyncData with an empty list, not AsyncError',
      () async {
        final fake = FakeServiceRepository(seed: const []);
        final controller = ServiceListController(
          repo: fake,
          searchDebounce: Duration.zero,
        );
        await controller.loadServices();

        expect(controller.listState, isA<AsyncData<List<Service>>>());
        expect(controller.listState.valueOrNull, isEmpty);
        controller.dispose();
      },
    );

    test('a request-level failure is AsyncError, not an empty list', () async {
      final repo = _QueuedServicesRepository();
      final controller = ServiceListController(
        repo: repo,
        searchDebounce: Duration.zero,
      );
      final load = controller.loadServices();
      repo.queue.resolve(
        0,
        Err(
          const AppError(ErrorKind.forbidden, 'Хандах эрхгүй', statusCode: 403),
        ),
      );
      await load;

      expect(controller.listState, isA<AsyncError<List<Service>>>());
      controller.dispose();
    });
  });

  group('server-side filters', () {
    test('q is trimmed and omitted entirely when empty', () async {
      final repo = _QueuedServicesRepository();
      final controller = ServiceListController(
        repo: repo,
        searchDebounce: Duration.zero,
      );

      final load = controller.loadServices();
      repo.queue.resolve(0, Ok(_page([])));
      await load;
      expect(repo.requests.single?.q, isNull);

      controller.setQuery('  brakes  ');
      await Future<void>.delayed(ServiceListController.defaultSearchDebounce);
      repo.queue.resolve(1, Ok(_page([])));
      await Future<void>.delayed(Duration.zero);
      expect(repo.requests.last?.q, 'brakes');

      controller.dispose();
    });

    test('includeInactive always sends false — no archived toggle in this '
        'slice', () async {
      final repo = _QueuedServicesRepository();
      final controller = ServiceListController(
        repo: repo,
        searchDebounce: Duration.zero,
      );
      final load = controller.loadServices();
      repo.queue.resolve(0, Ok(_page([])));
      await load;
      expect(repo.requests.single?.includeInactive, isFalse);
      controller.dispose();
    });
  });
}
