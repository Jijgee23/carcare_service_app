import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/services/domain/service.dart';
import 'package:carcare_service/features/services/domain/services_repository.dart';
import 'package:carcare_service/features/services/presentation/screens/service_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_service_repository.dart';

/// Widget coverage for `ServiceListScreen` — P4-F2.
///
/// Mirrors `vehicle_list_screen_widget_test.dart`'s shape: pump against the
/// fake repository, no network. `ServiceListScreen` additionally takes an
/// injectable `user` (unlike `VehicleListScreen`) because this rebuild's own
/// requirement, beyond `P3-F3`'s, is gating the whole surface (D-163) — the
/// gate otherwise falls back to `Authenticator.user`, which needs a live Hive
/// box no widget test opens (D-160's trap), so every test here injects one.
void main() {
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

  Future<void> pumpAt(WidgetTester tester, Size size, Widget screen) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  group('permission gate (D-163)', () {
    testWidgets('the whole surface is gated on services.view', (tester) async {
      await pumpAt(
        tester,
        const Size(375, 812),
        ServiceListScreen(
          repository: FakeServiceRepository(),
          user: user(const []),
        ),
      );

      expect(find.text('Тормозны наклад'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(
        find.text('Танд үйлчилгээний каталог харах эрх байхгүй байна.'),
        findsOneWidget,
      );
    });

    testWidgets('a user with services.view sees the list', (tester) async {
      await pumpAt(
        tester,
        const Size(375, 812),
        ServiceListScreen(
          repository: FakeServiceRepository(
            seed: [
              FakeServiceRepository.seedService(
                id: 'labor-1',
                type: ServiceKind.labor,
                name: 'Тос солих',
                code: null,
              ),
            ],
          ),
          user: user(const ['services.view']),
        ),
      );

      expect(find.text('Тос солих'), findsOneWidget);
    });

    testWidgets('an owner sees the list without the explicit permission '
        'code', (tester) async {
      await pumpAt(
        tester,
        const Size(375, 812),
        ServiceListScreen(
          repository: FakeServiceRepository(
            seed: [
              FakeServiceRepository.seedService(
                id: 'labor-1',
                type: ServiceKind.labor,
                name: 'Тос солих',
                code: null,
              ),
            ],
          ),
          user: User(
            accessToken: 't',
            refreshToken: 'r',
            id: 'owner',
            email: 'owner@example.test',
            firstName: 'Owner',
            lastName: 'User',
            phone: '99000000',
            isOwner: true,
            tenant: UserTenant('tenant', 'Tenant'),
          ),
        ),
      );

      expect(find.text('Тос солих'), findsOneWidget);
    });
  });

  group('list rendering', () {
    testWidgets('renders the labor tab by default and hides other kinds', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(375, 812),
        ServiceListScreen(
          repository: FakeServiceRepository(
            seed: [
              FakeServiceRepository.seedService(
                id: 'labor-1',
                type: ServiceKind.labor,
                name: 'Тос солих',
                code: null,
              ),
              FakeServiceRepository.seedService(
                id: 'goods-1',
                type: ServiceKind.goods,
                name: 'Наклад',
                code: null,
              ),
            ],
          ),
          user: user(const ['services.view']),
        ),
      );

      expect(find.text('Тос солих'), findsOneWidget);
      expect(find.text('Наклад'), findsNothing);
    });

    testWidgets('empty state is distinct from the error state', (tester) async {
      await pumpAt(
        tester,
        const Size(375, 812),
        ServiceListScreen(
          repository: FakeServiceRepository(seed: const []),
          user: user(const ['services.view']),
        ),
      );

      expect(find.text('Үйлчилгээ байхгүй байна'), findsOneWidget);
      expect(find.text('Дахин оролдох'), findsNothing);
    });

    testWidgets('an error state offers retry and is not mistaken for empty', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(375, 812),
        ServiceListScreen(
          repository: _FailingServiceRepository(),
          user: user(const ['services.view']),
        ),
      );

      expect(find.text('Дахин оролдох'), findsOneWidget);
      expect(find.text('Үйлчилгээ байхгүй байна'), findsNothing);
    });

    testWidgets('search field narrows the list via the fake repository', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(375, 812),
        ServiceListScreen(
          repository: FakeServiceRepository(
            seed: [
              FakeServiceRepository.seedService(
                id: 's1',
                type: ServiceKind.labor,
                name: 'Тос солих',
                code: null,
              ),
              FakeServiceRepository.seedService(
                id: 's2',
                type: ServiceKind.labor,
                name: 'Тормоз шалгах',
                code: null,
              ),
            ],
          ),
          user: user(const ['services.view']),
        ),
      );

      expect(find.text('Тос солих'), findsOneWidget);
      expect(find.text('Тормоз шалгах'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Тос');
      // The controller debounces 350ms by default; settle past it.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Тос солих'), findsOneWidget);
      expect(find.text('Тормоз шалгах'), findsNothing);
    });
  });

  group('kind filter tabs', () {
    testWidgets('switching tabs reloads the list scoped to that kind', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(375, 812),
        ServiceListScreen(
          repository: FakeServiceRepository(
            seed: [
              FakeServiceRepository.seedService(
                id: 'labor-1',
                type: ServiceKind.labor,
                name: 'Тос солих',
                code: null,
              ),
              FakeServiceRepository.seedService(
                id: 'goods-1',
                type: ServiceKind.goods,
                name: 'Наклад',
                code: null,
              ),
              FakeServiceRepository.seedService(
                id: 'diag-1',
                type: ServiceKind.diagnostic,
                name: 'Оношилгоо-1',
                code: null,
              ),
            ],
          ),
          user: user(const ['services.view']),
        ),
      );

      expect(find.text('Тос солих'), findsOneWidget);
      expect(find.text('Наклад'), findsNothing);

      await tester.tap(find.text('Сэлбэг/Бараа'));
      await tester.pumpAndSettle();

      expect(find.text('Наклад'), findsOneWidget);
      expect(find.text('Тос солих'), findsNothing);

      await tester.tap(find.text('Оношилгоо'));
      await tester.pumpAndSettle();

      expect(find.text('Оношилгоо-1'), findsOneWidget);
      expect(find.text('Наклад'), findsNothing);

      await tester.tap(find.text('Ажил'));
      await tester.pumpAndSettle();

      expect(find.text('Тос солих'), findsOneWidget);
      expect(find.text('Оношилгоо-1'), findsNothing);
    });
  });

  group('create FAB hook — deferred to route wiring (P4-F4)', () {
    testWidgets('does not render when onCreateService is not supplied', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(375, 812),
        ServiceListScreen(
          repository: FakeServiceRepository(),
          user: user(const ['services.view', 'services.create']),
        ),
      );

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('renders and invokes the hook with the active tab kind', (
      tester,
    ) async {
      ServiceKind? tapped;
      await pumpAt(
        tester,
        const Size(375, 812),
        ServiceListScreen(
          repository: FakeServiceRepository(),
          user: user(const ['services.view', 'services.create']),
          onCreateService: (kind) => tapped = kind,
        ),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(tapped, ServiceKind.labor);
    });

    testWidgets('is gated on services.create even when the hook is supplied '
        '(D-163: gate the surface AND its actions)', (tester) async {
      await pumpAt(
        tester,
        const Size(375, 812),
        ServiceListScreen(
          repository: FakeServiceRepository(),
          user: user(const ['services.view']), // no services.create
          onCreateService: (_) {},
        ),
      );

      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('row tap hook', () {
    testWidgets('invokes onSelectService with the tapped service', (
      tester,
    ) async {
      Service? tapped;
      await pumpAt(
        tester,
        const Size(375, 812),
        ServiceListScreen(
          repository: FakeServiceRepository(
            seed: [
              FakeServiceRepository.seedService(
                id: 'labor-1',
                type: ServiceKind.labor,
                name: 'Тос солих',
                code: null,
              ),
            ],
          ),
          user: user(const ['services.view']),
          onSelectService: (service) => tapped = service,
        ),
      );

      await tester.tap(find.text('Тос солих'));
      await tester.pumpAndSettle();

      expect(tapped?.id, 'labor-1');
    });

    testWidgets('rows are inert (no chevron, no crash) when the hook is not '
        'supplied — same as the pre-wiring default', (tester) async {
      await pumpAt(
        tester,
        const Size(375, 812),
        ServiceListScreen(
          repository: FakeServiceRepository(
            seed: [
              FakeServiceRepository.seedService(
                id: 'labor-1',
                type: ServiceKind.labor,
                name: 'Тос солих',
                code: null,
              ),
            ],
          ),
          user: user(const ['services.view']),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsNothing);
      await tester.tap(find.text('Тос солих'));
      await tester.pumpAndSettle();
      // No exception is the assertion — nothing else observable changes.
    });
  });
}

class _FailingServiceRepository extends FakeServiceRepository {
  _FailingServiceRepository() : super(seed: const []);

  @override
  Future<Result<PagedResult<Service>>> getServices({
    ServiceListQuery? query,
  }) async =>
      Err(const AppError(ErrorKind.network, 'Сервертэй холбогдож чадсангүй'));
}
