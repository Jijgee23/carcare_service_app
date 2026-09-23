import 'package:carcare_service/features/vehicles/presentation/controllers/vehicle_list_controller.dart';
import 'package:carcare_service/features/vehicles/presentation/screens/vehicle_search_tab.dart';
import 'package:carcare_service/features/vehicles/presentation/widgets/vehicle_list_widgets.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_vehicle_repository.dart';

/// Widget coverage for `VehicleSearchTab` — the `P3-F3` follow-up that moved
/// the vehicle tab of `search_screen.dart` off its hand-rolled `Timer` and
/// its direct `DiagnosticService.searchVehicles` call.
///
/// The list body itself is covered by `vehicle_list_screen_widget_test.dart`;
/// what is asserted here is the tab's own contract — that it loads without
/// being told to, that it suppresses the standalone screen's filter chrome,
/// and that searching still narrows the list.
void main() {
  /// The tab gates its whole surface on `vehicles.view` (P3-X1), and the gate
  /// otherwise falls back to `Authenticator.user`, which needs a live Hive box
  /// no widget test opens. Tests therefore inject a user.
  User user(List<String> permissions) => User(
    accessToken: 'token',
    refreshToken: 'refresh',
    id: 'user',
    email: 'user@example.test',
    firstName: 'Test',
    lastName: 'User',
    phone: '99001122',
    isOwner: false,
    role: UserRole('role', 'Role', permissions),
    tenant: UserTenant('tenant', 'Tenant'),
  );

  Future<VehicleListController> pumpTab(
    WidgetTester tester,
    Size size, {
    FakeVehicleRepository? repo,
    User? asUser,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = VehicleListController(
      repo: repo ?? FakeVehicleRepository(),
      searchDebounce: Duration.zero,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleSearchTab(
            controller: controller,
            user: asUser ?? user(const ['vehicles.view']),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('loads on first build without an explicit trigger', (
    tester,
  ) async {
    await pumpTab(tester, const Size(375, 812));

    expect(find.text('1234 УБА'), findsOneWidget);
  });

  testWidgets('suppresses the standalone screen filter chips', (tester) async {
    await pumpTab(tester, const Size(375, 812));

    // `showFilters: false` — the search tab deliberately keeps the plain
    // search-box affordance staff already know.
    expect(find.text('Эзэнтэй'), findsNothing);
    expect(find.text('Зээлээр'), findsNothing);
  });

  testWidgets('typing narrows the list through the controller', (tester) async {
    final controller = await pumpTab(tester, const Size(375, 812));

    await tester.enterText(find.byType(TextField).first, 'ZZZZ-no-match');
    await tester.pumpAndSettle();

    expect(controller.query, 'ZZZZ-no-match');
    expect(find.text('1234 УБА'), findsNothing);
  });

  testWidgets('renders at 700dp and 1024dp', (tester) async {
    await pumpTab(tester, const Size(700, 1024));
    expect(find.byType(VehicleListView), findsOneWidget);

    await pumpTab(tester, const Size(1024, 768));
    expect(find.byType(VehicleListView), findsOneWidget);
  });

  testWidgets('disposes an injected controller only via its owner', (
    tester,
  ) async {
    final controller = VehicleListController(
      repo: FakeVehicleRepository(),
      searchDebounce: Duration.zero,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleSearchTab(
            controller: controller,
            user: user(const ['vehicles.view']),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    // A disposed ChangeNotifier throws on addListener, so this is a real
    // disposal check — and it starts no debounce timer, unlike setQuery.
    void listener() {}
    expect(() => controller.addListener(listener), returnsNormally);
    controller.removeListener(listener);
  });
  testWidgets('the whole surface is gated on vehicles.view', (tester) async {
    await pumpTab(tester, const Size(375, 812), asUser: user(const []));

    expect(find.text('1234 УБА'), findsNothing);
    expect(
      find.text('Танд машины жагсаалт харах эрх байхгүй байна.'),
      findsOneWidget,
    );
  });
}
