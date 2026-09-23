import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/features/vehicles/domain/vehicle.dart';
import 'package:carcare_service/features/vehicles/presentation/screens/vehicle_detail_screen.dart';

import '../../fakes/fake_vehicle_repository.dart';

/// Widget coverage for the rebuilt `VehicleDetailScreen` — `P3-F5`.
///
/// Mirrors `customer_detail_screen_widget_test.dart` (`P3-F4`): fetch-by-id
/// including the deep-link cold start (the screen is given only
/// [VehicleDetailScreen.vehicleId]), permission gating both hiding (edit)
/// and disabling (delete), the delete-blocked-by-history conflict rendered
/// as a real explanation, HUR refresh in-flight/success/502 states, and
/// rendering at phone (375dp) and expanded (1024dp) widths.
User _user(List<String> permissions, {bool isOwner = false}) => User(
  accessToken: 'token',
  refreshToken: 'refresh',
  id: 'user',
  email: 'user@example.test',
  firstName: 'Test',
  lastName: 'User',
  phone: '99001122',
  isOwner: isOwner,
  role: UserRole('role', 'Role', permissions),
  tenant: UserTenant('tenant', 'Tenant'),
);

Future<void> _pump(
  WidgetTester tester,
  double width, {
  required FakeVehicleRepository repo,
  required User user,
  String vehicleId = 'veh-1',
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: VehicleDetailScreen(
        vehicleId: vehicleId,
        repository: repo,
        user: user,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  for (final width in [375.0, 1024.0]) {
    testWidgets('cold start at ${width}dp fetches by id and renders detail', (
      tester,
    ) async {
      final repo = FakeVehicleRepository(
        seed: [FakeVehicleRepository.seedVehicle(id: 'veh-1')],
      );
      await _pump(
        tester,
        width,
        repo: repo,
        user: _user(const ['vehicles.view']),
      );

      expect(find.text('1234 УБА'), findsWidgets);
      expect(find.text('Toyota Prius 30'), findsOneWidget);
      expect(find.text('Бат'), findsOneWidget);
      expect(find.text('Засварын түүх'), findsOneWidget);
    });
  }

  testWidgets('edit is hidden without vehicles.edit', (tester) async {
    final repo = FakeVehicleRepository(
      seed: [FakeVehicleRepository.seedVehicle(id: 'veh-1')],
    );
    await _pump(tester, 375, repo: repo, user: _user(const ['vehicles.view']));

    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('delete is shown but disabled without vehicles.delete', (
    tester,
  ) async {
    final repo = FakeVehicleRepository(
      seed: [FakeVehicleRepository.seedVehicle(id: 'veh-1')],
    );
    await _pump(
      tester,
      375,
      repo: repo,
      user: _user(const ['vehicles.view', 'vehicles.edit']),
    );

    final deleteIcon = find.byIcon(Icons.delete_outline_rounded);
    expect(deleteIcon, findsOneWidget);
    final deleteButton = tester.widget<IconButton>(
      find.ancestor(of: deleteIcon, matching: find.byType(IconButton)),
    );
    // `PermissionGate(disable: true)` — visible but its `onPressed` must be
    // rendered but inert to a tap; `AbsorbPointer`/`IgnorePointer` is what
    // actually blocks the tap, verified indirectly by tapping and seeing no
    // confirm sheet.
    expect(deleteButton.onPressed, isNotNull);
    await tester.tap(deleteIcon, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Машин устгах уу?'), findsNothing);
  });

  testWidgets('edit and delete show and are usable with permission', (
    tester,
  ) async {
    final repo = FakeVehicleRepository(
      seed: [FakeVehicleRepository.seedVehicle(id: 'veh-1')],
    );
    await _pump(
      tester,
      375,
      repo: repo,
      user: _user(const ['vehicles.view', 'vehicles.edit', 'vehicles.delete']),
    );

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    final editButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.edit_outlined),
        matching: find.byType(IconButton),
      ),
    );
    expect(editButton.onPressed, isNotNull);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Машин устгах уу?'), findsOneWidget);
  });

  testWidgets(
    'delete blocked by history shows a real explanation, not a generic error',
    (tester) async {
      final repo = FakeVehicleRepository(
        seed: [FakeVehicleRepository.seedVehicle(id: 'veh-1')],
        history: {
          'veh-1': const VehicleHistory(
            orders: [VehicleHistoryOrder(id: 'ord-1')],
          ),
        },
      );
      await _pump(
        tester,
        375,
        repo: repo,
        user: _user(const ['vehicles.view', 'vehicles.delete']),
      );

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Машин устгах уу?'), findsOneWidget);
      await tester.tap(find.text('Устгах').last);
      await tester.pumpAndSettle();

      expect(find.text('Устгах боломжгүй'), findsOneWidget);
      expect(find.textContaining('устгах боломжгүй'), findsWidgets);
    },
  );

  testWidgets('HUR refresh: in-flight, success and 502 upstream failure', (
    tester,
  ) async {
    final repo = FakeVehicleRepository(
      seed: [FakeVehicleRepository.seedVehicle(id: 'veh-1')],
    );
    await _pump(tester, 375, repo: repo, user: _user(const ['vehicles.view']));

    // Success path. (The in-flight spinner swap itself is covered at the
    // controller level with a Completer-based fake, where the request can
    // actually be held open; the fake repository here resolves within a
    // microtask, too fast to reliably observe mid-flight in a widget pump.)
    await tester.tap(find.byTooltip('ХУР-аас шинэчлэх'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
    // Flush the toast's own 3s auto-dismiss timer so it does not leak past
    // this test.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // 502 upstream failure — expected outcome, not a crash.
    repo.hurUpstreamFails = true;
    await tester.tap(find.byTooltip('ХУР-аас шинэчлэх'));
    await tester.pumpAndSettle();
    expect(find.byType(VehicleDetailScreen), findsOneWidget);
    // Vehicle data is still rendered — the screen did not crash or blank.
    expect(find.text('1234 УБА'), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'a HUR refresh never discards a field it did not touch (mileage/owner)',
    (tester) async {
      final repo = FakeVehicleRepository(
        seed: [
          FakeVehicleRepository.seedVehicle(id: 'veh-1', customerId: 'cust-1'),
        ],
      );
      await _pump(
        tester,
        375,
        repo: repo,
        user: _user(const ['vehicles.view']),
      );

      expect(
        find.text('Явсан км: 180000 км'),
        findsNothing,
      ); // sanity: no such literal
      expect(find.textContaining('180000'), findsOneWidget);
      expect(find.text('Бат'), findsOneWidget);

      await tester.tap(find.byTooltip('ХУР-аас шинэчлэх'));
      await tester.pumpAndSettle();

      // Mileage and owner are not part of the HUR payload — both must still
      // be shown after the refresh, not blanked.
      expect(find.textContaining('180000'), findsOneWidget);
      expect(find.text('Бат'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );
  testWidgets('keeps the legacy "Оношилгоо" inspection FAB (DM-01 parity)', (
    tester,
  ) async {
    // The P3-F5 rebuild dropped this FAB; the P3-X1 audit found it. Pinned
    // here for the same reason the customer screen's shortcut is pinned: a
    // rebuild may change anything except quietly losing an entry point staff
    // already had.
    await _pump(
      tester,
      375,
      repo: FakeVehicleRepository(),
      user: _user(const ['vehicles.view']),
    );

    expect(find.text('Оношилгоо'), findsOneWidget);
  });
}
