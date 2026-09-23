import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/orders/presentation/screens/new_vehicle_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fakes/fake_api_backend.dart';
import '../../../../fakes/fake_customer_repository.dart';
import '../../../../fakes/fake_vehicle_repository.dart';

/// `P3-F6` — the Orders fast-path vehicle screen promoted onto
/// `VehiclesRepository`/`CustomersRepository`. The HUR plate lookup is a
/// documented, deliberate exception: it stays on `DiagnosticService`
/// (`GET /hur/vehicle`), which is outside the `P3-F1` contract — see the
/// module doc on `new_vehicle_screen.dart`.
///
/// Fields have no explicit `Key`s in the source, so this file locates them
/// by index (plate=0, make=1, model=2, year=3, mileage=4) — stable because
/// the form's field order is fixed — or, for the customer search box, by its
/// distinctive hint text.
void main() {
  setUp(FakeApiBackend.instance.reset);

  Finder plateField() => find.byType(TextFormField).at(0);
  Finder makeField() => find.byType(TextFormField).at(1);
  Finder modelField() => find.byType(TextFormField).at(2);
  Finder yearField() => find.byType(TextFormField).at(3);

  Future<void> fillRequired(WidgetTester tester) async {
    await tester.enterText(plateField(), '1234ABC');
    await tester.enterText(makeField(), 'Toyota');
    await tester.enterText(modelField(), 'Prius');
  }

  testWidgets('creates inline and pops with a result carrying the real owner', (
    tester,
  ) async {
    final vehicles = FakeVehicleRepository(seed: []);
    // `ensureTenantVehicle` never overwrites an existing owner — the fake
    // reproduces that by keying a pre-owned plate to a different customer
    // than the one this form will request.
    vehicles.preOwnedPlates['1234ABC'] = 'cust-real-owner';
    final customers = FakeCustomerRepository(seed: []);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => NewVehicleScreen(
            vehiclesRepository: vehicles,
            customersRepository: customers,
          ),
        ),
      ),
    );

    await fillRequired(tester);
    await tester.tap(find.text('Машин бүртгэх'));
    await tester.pumpAndSettle();

    final saved = (await vehicles.getVehicles()).valueOrNull!.items;
    expect(saved, hasLength(1));
    expect(saved.single.customerId, 'cust-real-owner');
  });

  testWidgets(
    'a repository 422 with fieldErrors binds to the field, not a snackbar',
    (tester) async {
      final vehicles = FakeVehicleRepository(seed: []);
      final customers = FakeCustomerRepository(seed: []);

      await tester.pumpWidget(
        MaterialApp(
          home: NewVehicleScreen(
            vehiclesRepository: vehicles,
            customersRepository: customers,
          ),
        ),
      );

      await fillRequired(tester);
      // The fake's `createVehicle` rejects `year < 1900` server-side — the
      // client form applies no year validator at all, so this can only reach
      // the screen through the repository's typed 422.
      await tester.enterText(yearField(), '1800');
      await tester.tap(find.text('Машин бүртгэх'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Жил буруу.'), findsOneWidget);
      final saved = (await vehicles.getVehicles()).valueOrNull!.items;
      expect(saved, isEmpty);
    },
  );

  testWidgets('plan limit (422 without fieldErrors) shows a general message', (
    tester,
  ) async {
    final vehicles = FakeVehicleRepository(seed: [], maxVehicles: 0);
    final customers = FakeCustomerRepository(seed: []);

    await tester.pumpWidget(
      MaterialApp(
        home: NewVehicleScreen(
          vehiclesRepository: vehicles,
          customersRepository: customers,
        ),
      ),
    );

    await fillRequired(tester);
    await tester.tap(find.text('Машин бүртгэх'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Машины хязгаарт хүрсэн байна.'), findsOneWidget);
  });

  testWidgets(
    'HUR lookup still goes through DiagnosticService (documented P3-X1 gap)',
    (tester) async {
      FakeApiBackend.instance.onJson('GET', 'hur/vehicle', {
        'vehicle': {'mark': 'Toyota', 'model': 'Prius', 'year': 2020},
      });
      final vehicles = FakeVehicleRepository(seed: []);
      final customers = FakeCustomerRepository(seed: []);

      await tester.pumpWidget(
        MaterialApp(
          home: NewVehicleScreen(
            vehiclesRepository: vehicles,
            customersRepository: customers,
          ),
        ),
      );

      await tester.enterText(plateField(), '1234ABC');
      await tester.tap(find.byTooltip('ХУР-аас хайх'));
      await tester.pumpAndSettle();

      final makeWidget = tester.widget<TextFormField>(makeField());
      expect(makeWidget.controller?.text, 'Toyota');
      expect(
        FakeApiBackend.instance.requests.any(
          (r) => r.path.contains('hur/vehicle'),
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'inline customer search uses CustomersRepository, never DiagnosticService',
    (tester) async {
      final vehicles = FakeVehicleRepository(seed: []);
      final customers = FakeCustomerRepository(seed: []);
      await customers.createCustomer(fullName: 'Бат', phone: '99001122');

      await tester.pumpWidget(
        MaterialApp(
          home: NewVehicleScreen(
            vehiclesRepository: vehicles,
            customersRepository: customers,
          ),
        ),
      );

      final searchField = find.ancestor(
        of: find.text('Нэр, утсаар хайх...'),
        matching: find.byType(TextFormField),
      );
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Бат');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('99001122'), findsOneWidget);
      // The only network traffic this screen may still generate is the HUR
      // lookup — customer search must never touch the fake API backend.
      expect(FakeApiBackend.instance.requests, isEmpty);
    },
  );
}
