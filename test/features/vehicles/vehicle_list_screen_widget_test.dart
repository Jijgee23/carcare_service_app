import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/vehicles/domain/vehicle.dart';
import 'package:carcare_service/features/vehicles/domain/vehicles_repository.dart';
import 'package:carcare_service/features/vehicles/presentation/screens/vehicle_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_vehicle_repository.dart';

/// Widget coverage for `VehicleListScreen`/`VehicleListView` — P3-F3.
///
/// Mirrors `test/features/notifications/notification_screen_test.dart`'s
/// shape: pump against the fake repository, no network. Sizes cover the
/// three tiers this slice's verification list asks for: 375dp (phone),
/// 700dp (compact tablet — still a table per `AdaptiveBreakpoints`, whose
/// `expanded` cutoff is 840), and 1024dp (tablet).
void main() {
  Future<void> pumpAt(WidgetTester tester, Size size, Widget screen) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  group('375dp (phone)', () {
    testWidgets('renders seeded vehicles as cards', (tester) async {
      await pumpAt(
        tester,
        const Size(375, 812),
        VehicleListScreen(repository: FakeVehicleRepository()),
      );

      expect(find.text('Машинууд'), findsOneWidget);
      expect(find.text('1234 УБА'), findsOneWidget);
      expect(find.text('Toyota Prius 30'), findsOneWidget);
      expect(find.text('Бат'), findsOneWidget);
    });

    testWidgets('empty state is distinct from the error state', (tester) async {
      await pumpAt(
        tester,
        const Size(375, 812),
        VehicleListScreen(repository: FakeVehicleRepository(seed: const [])),
      );

      expect(find.text('Машин бүртгэгдээгүй байна'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsWidgets); // app bar action only
      expect(find.text('Дахин оролдох'), findsNothing);
    });

    testWidgets('an error state offers retry and is not mistaken for empty', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(375, 812),
        VehicleListScreen(repository: _FailingVehicleRepository()),
      );

      expect(find.text('Дахин оролдох'), findsOneWidget);
      expect(find.text('Машин бүртгэгдээгүй байна'), findsNothing);
    });

    testWidgets('search field narrows the list via the fake repository', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(375, 812),
        VehicleListScreen(
          repository: FakeVehicleRepository(
            seed: [
              FakeVehicleRepository.seedVehicle(id: 'v1', plate: '1111 АБВ'),
              FakeVehicleRepository.seedVehicle(id: 'v2', plate: '2222 ГДЕ'),
            ],
          ),
        ),
      );

      expect(find.text('1111 АБВ'), findsOneWidget);
      expect(find.text('2222 ГДЕ'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1111');
      // The controller debounces 350ms by default; settle past it.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('1111 АБВ'), findsOneWidget);
      expect(find.text('2222 ГДЕ'), findsNothing);
    });
  });

  group('700dp (compact tablet)', () {
    testWidgets('renders the table header and the postpaid chip', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(700, 900),
        VehicleListScreen(
          repository: FakeVehicleRepository(
            seed: [
              Vehicle(
                id: 'v1',
                plate: '1234 УБА',
                make: 'Toyota',
                model: 'Prius',
                isPostpaid: true,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Улсын дугаар'), findsOneWidget);
      expect(find.text('Дараа төлбөр'), findsWidgets);
    });
  });

  group('1024dp (tablet)', () {
    testWidgets('renders the table layout with owner column', (tester) async {
      await pumpAt(
        tester,
        const Size(1024, 900),
        VehicleListScreen(repository: FakeVehicleRepository()),
      );

      expect(find.text('Эзэмшигч'), findsOneWidget);
      expect(find.text('Бат'), findsOneWidget);
    });

    testWidgets('the assigned/postpaid filter chips are reachable', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(1024, 900),
        VehicleListScreen(repository: FakeVehicleRepository()),
      );

      expect(find.text('Эзэнтэй'), findsOneWidget);
      expect(find.text('Дараа төлдөг'), findsOneWidget);

      await tester.tap(find.text('Эзэнтэй'));
      await tester.pumpAndSettle();

      expect(find.text('Шүүлтүүр арилгах'), findsOneWidget);
    });
  });
}

class _FailingVehicleRepository extends FakeVehicleRepository {
  _FailingVehicleRepository() : super(seed: const []);

  @override
  Future<Result<PagedResult<Vehicle>>> getVehicles({
    VehicleListQuery? query,
  }) async =>
      Err(const AppError(ErrorKind.network, 'Сервертэй холбогдож чадсангүй'));
}
