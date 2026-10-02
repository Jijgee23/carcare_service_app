import 'package:carservice_business/core/domain/user.dart';
import 'package:carservice_business/features/vehicles/presentation/screens/vehicle_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../fakes/fake_vehicle_repository.dart';

User _user(List<String> permissions) => User(
  accessToken: 't',
  refreshToken: 'r',
  id: 'u',
  email: 'u@example.test',
  firstName: 'A',
  lastName: 'B',
  phone: '99001122',
  isOwner: false,
  role: UserRole('role', 'Role', permissions),
  tenant: UserTenant('tenant', 'Tenant'),
);

void main() {
  Future<FakeVehicleRepository> pump(
    WidgetTester tester, {
    required List<String> permissions,
    Future<bool> Function()? onCreate,
  }) async {
    final repo = FakeVehicleRepository();
    await tester.pumpWidget(
      GetMaterialApp(
        home: VehicleListScreen(
          repository: repo,
          user: _user(permissions),
          onCreateVehicle: onCreate,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('"+" is gated on vehicles.create', (tester) async {
    await pump(
      tester,
      permissions: const ['vehicles.view'],
      onCreate: () async => false,
    );
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('"+" refreshes the list after a vehicle was created', (
    tester,
  ) async {
    final repo = await pump(
      tester,
      permissions: const ['vehicles.view', 'vehicles.create'],
      onCreate: () async => true,
    );
    final before = repo.listCalls;
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(repo.listCalls, greaterThan(before));
  });

  testWidgets('"+" does not refresh when creation was cancelled', (
    tester,
  ) async {
    final repo = await pump(
      tester,
      permissions: const ['vehicles.create'],
      onCreate: () async => false,
    );
    final before = repo.listCalls;
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(repo.listCalls, before);
  });
}
