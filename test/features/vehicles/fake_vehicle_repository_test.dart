import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/vehicles/domain/vehicle.dart';
import 'package:carcare_service/features/vehicles/domain/vehicles_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_vehicle_repository.dart';

/// P3-F1 — contract tests for [FakeVehicleRepository].
///
/// The fake is a test double that later slices' controller tests build on, so
/// the rules it claims to mirror are asserted here. If one of these fails,
/// the fake is lying about the server and every test standing on it is
/// unsound.
void main() {
  test('implements the repository interface', () {
    expect(FakeVehicleRepository(), isA<VehiclesRepository>());
  });

  group('list', () {
    FakeVehicleRepository build() => FakeVehicleRepository(
      seed: [
        FakeVehicleRepository.seedVehicle(),
        const Vehicle(
          id: 'veh-2',
          plate: '5678 УБА',
          make: 'Nissan',
          model: 'Note',
          customerId: 'cust-2',
          customer: VehicleCustomerRef(
            id: 'cust-2',
            fullName: 'Дорж',
            phone: '88112233',
          ),
          isPostpaid: true,
        ),
        const Vehicle(id: 'veh-3', plate: '9999 УБА', make: 'Lexus'),
      ],
    );

    Future<List<String>> ids(
      FakeVehicleRepository repo, [
      VehicleListQuery? q,
    ]) async {
      final result = await repo.getVehicles(query: q);
      return (result as Ok<PagedResult<Vehicle>>).value.items
          .map((v) => v.id)
          .toList();
    }

    test('q matches plate, make, model and vin case-insensitively', () async {
      expect(await ids(build(), const VehicleListQuery(q: 'nissan')), [
        'veh-2',
      ]);
      expect(await ids(build(), const VehicleListQuery(q: 'prius')), ['veh-1']);
      expect(await ids(build(), const VehicleListQuery(q: '9999')), ['veh-3']);
      expect(
        await ids(build(), const VehicleListQuery(q: 'jtdkb20u793000000')),
        ['veh-1'],
      );
    });

    test('q also matches the owner name case-insensitively (P3-B6)', () async {
      expect(await ids(build(), const VehicleListQuery(q: 'дорж')), ['veh-2']);
    });

    test('the owner phone clause is case-sensitive and matches', () async {
      expect(await ids(build(), const VehicleListQuery(q: '8811')), ['veh-2']);
    });

    test('assigned splits owned from unowned links', () async {
      expect(await ids(build(), const VehicleListQuery(assigned: true)), [
        'veh-1',
        'veh-2',
      ]);
      expect(await ids(build(), const VehicleListQuery(assigned: false)), [
        'veh-3',
      ]);
    });

    test('postpaid filters on the link flag', () async {
      expect(await ids(build(), const VehicleListQuery(postpaid: true)), [
        'veh-2',
      ]);
    });

    test('customerId wins over assigned when both are supplied', () async {
      expect(
        await ids(
          build(),
          const VehicleListQuery(customerId: 'cust-2', assigned: false),
        ),
        ['veh-2'],
      );
    });

    test('pagination reports clamped meta like buildMeta', () async {
      final result = await build().getVehicles(
        query: const VehicleListQuery(page: 2, pageSize: 2),
      );
      final page = (result as Ok).value;
      expect(page.items.map((v) => v.id), ['veh-3']);
      expect(page.pagination.total, 3);
      expect(page.pagination.totalPages, 2);
      expect(page.pagination.hasPrev, isTrue);
      expect(page.pagination.hasNext, isFalse);
    });

    test('an empty result still reports one page, never zero', () async {
      final result = await build().getVehicles(
        query: const VehicleListQuery(q: 'no-such-thing'),
      );
      final page = (result as Ok).value;
      expect(page.items, isEmpty);
      expect(page.pagination.totalPages, 1);
    });
  });

  group('create', () {
    test('rejects blank required fields with 422 field errors', () async {
      final result = await FakeVehicleRepository().createVehicle(
        plate: '  ',
        make: '',
        model: 'Prius',
      );
      final error = (result as Err).error;
      expect(error.statusCode, 422);
      expect(error.code, 'VALIDATION_FAILED');
      expect(error.fieldErrors, containsPair('plate', isNotEmpty));
      expect(error.fieldErrors, containsPair('make', isNotEmpty));
      expect(error.fieldErrors!.containsKey('model'), isFalse);
    });

    test('rejects a year below 1900 but allows one above 2100', () async {
      final repo = FakeVehicleRepository();
      final low = await repo.createVehicle(
        plate: 'X',
        make: 'Y',
        model: 'Z',
        year: 1899,
      );
      expect((low as Err).error.fieldErrors, contains('year'));

      // The API route deliberately does not enforce the upper bound
      // (Divergence 3) — only the dashboard's own create action does.
      final high = await repo.createVehicle(
        plate: 'X',
        make: 'Y',
        model: 'Z',
        year: 2200,
      );
      expect(high, isA<Ok>());
    });

    test('enforces MAX_VEHICLES on every create (D-154)', () async {
      final repo = FakeVehicleRepository(maxVehicles: 1);
      final result = await repo.createVehicle(
        plate: '7777 УБА',
        make: 'Toyota',
        model: 'Alphard',
      );
      final error = (result as Err).error;
      expect(error.statusCode, 422);
      expect(error.code, 'PLAN_LIMIT_REACHED');
    });

    test('reports the link owner, not the requested owner', () async {
      final repo = FakeVehicleRepository();
      repo.preOwnedPlates['7777 УБА'] = 'cust-ORIGINAL';

      final result = await repo.createVehicle(
        plate: '7777 УБА',
        make: 'Toyota',
        model: 'Alphard',
        customerId: 'cust-REQUESTED',
      );
      expect((result as Ok).value.customerId, 'cust-ORIGINAL');
    });

    test(
      'a duplicate plate creates a second row — plates are not unique',
      () async {
        final repo = FakeVehicleRepository();
        final result = await repo.createVehicle(
          plate: '1234 УБА',
          make: 'Toyota',
          model: 'Prius 30',
          customerId: 'cust-2',
        );
        expect(result, isA<Ok>());

        final listed = await repo.getVehicles(
          query: const VehicleListQuery(q: '1234'),
        );
        expect((listed as Ok).value.items, hasLength(2));
      },
    );
  });

  group('update', () {
    test('never changes the plate', () async {
      final repo = FakeVehicleRepository();
      final result = await repo.updateVehicle(
        'veh-1',
        plate: 'A NEW PLATE',
        make: 'Toyota',
        model: 'Prius 30',
        customerId: 'cust-1',
      );
      expect((result as Ok).value.plate, '1234 УБА');
    });

    test('blocks an owner change on a vehicle with history', () async {
      final repo = FakeVehicleRepository(
        history: {
          'veh-1': const VehicleHistory(
            orders: [VehicleHistoryOrder(id: 'ord-1')],
            ownerLocked: true,
          ),
        },
      );
      final result = await repo.updateVehicle(
        'veh-1',
        plate: '1234 УБА',
        make: 'Toyota',
        model: 'Prius 30',
        customerId: 'cust-OTHER',
      );
      final error = (result as Err).error;
      expect(error.statusCode, 422);
      expect(error.code, 'VEHICLE_OWNER_CHANGE_BLOCKED');
      expect(error.fieldErrors, contains('customerId'));
    });

    test('allows a non-owner edit on a vehicle with history', () async {
      final repo = FakeVehicleRepository(
        history: {
          'veh-1': const VehicleHistory(
            orders: [VehicleHistoryOrder(id: 'ord-1')],
          ),
        },
      );
      final result = await repo.updateVehicle(
        'veh-1',
        plate: '1234 УБА',
        make: 'Toyota',
        model: 'Prius 40',
        customerId: 'cust-1',
      );
      expect((result as Ok).value.model, 'Prius 40');
    });

    test('404s for an unknown id', () async {
      final result = await FakeVehicleRepository().updateVehicle(
        'nope',
        plate: 'X',
        make: 'Y',
        model: 'Z',
      );
      final error = (result as Err).error;
      expect(error.kind, ErrorKind.notFound);
      expect(error.statusCode, 404);
    });
  });

  group('delete', () {
    test('unlinks and returns the removed identity', () async {
      final repo = FakeVehicleRepository();
      final result = await repo.deleteVehicle('veh-1');
      expect((result as Ok).value.plate, '1234 УБА');

      final after = await repo.getVehicle('veh-1');
      expect((after as Err).error.statusCode, 404);
    });

    test('409 VEHICLE_IN_USE when the vehicle has history', () async {
      final repo = FakeVehicleRepository(
        history: {'veh-1': const VehicleHistory(diagnosticReportCount: 1)},
      );
      final result = await repo.deleteVehicle('veh-1');
      final error = (result as Err).error;
      expect(error.statusCode, 409);
      expect(error.code, 'VEHICLE_IN_USE');
    });
  });

  group('history and HUR refresh', () {
    test(
      'a vehicle with no history returns an empty, unlocked history',
      () async {
        final result = await FakeVehicleRepository().getHistory('veh-1');
        final history = (result as Ok).value;
        expect(history.orders, isEmpty);
        expect(history.ownerLocked, isFalse);
      },
    );

    test('a refresh merges without discarding untouched fields', () async {
      final repo = FakeVehicleRepository();
      final result = await repo.refreshFromHur('veh-1');
      expect(result, isA<Ok>());
      expect(repo.refreshCalls, 1);

      final stored = ((await repo.getVehicle('veh-1')) as Ok).value;
      expect(stored.colorName, 'Мөнгөлөг');
      expect(stored.year, 2013);
      // Not part of the refresh payload — must survive.
      expect(stored.mileage, 180000);
      expect(stored.customerId, 'cust-1');
      expect(stored.plate, '1234 УБА');
    });

    test('an upstream failure is a 502 and writes nothing', () async {
      final repo = FakeVehicleRepository()..hurUpstreamFails = true;
      final before = ((await repo.getVehicle('veh-1')) as Ok).value;

      final result = await repo.refreshFromHur('veh-1');
      expect((result as Err).error.statusCode, 502);

      final after = ((await repo.getVehicle('veh-1')) as Ok).value;
      expect(after.colorName, before.colorName);
      expect(after.year, before.year);
    });
  });
}
