import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/features/schedules/domain/schedule.dart';
import 'package:carcare_service/features/schedules/presentation/controllers/my_schedule_controller.dart';

import '../../data/fake_schedule_repository.dart';

void main() {
  group('MyScheduleController', () {
    late FakeScheduleRepository repo;
    late MyScheduleController controller;

    setUp(() {
      repo = FakeScheduleRepository(
        seed: [FakeScheduleRepository.seedRow(id: 'u-self', name: 'Би')],
        currentUserId: 'u-self',
      );
      controller = MyScheduleController(repo: repo);
    });

    tearDown(() => controller.dispose());

    test('load populates the caller-own resolved month', () async {
      expect(controller.state, isA<AsyncLoading>());
      await controller.load();
      expect(controller.state, isA<AsyncData<MySchedule>>());
      expect(controller.state.valueOrNull!.row?.id, 'u-self');
    });

    test('nextMonth/prevMonth advance the anchor month', () async {
      controller.month = DateTime(2026, 9, 1);
      await controller.load();
      controller.nextMonth();
      await Future.delayed(Duration.zero);
      expect(controller.month, DateTime(2026, 10, 1));
      controller.prevMonth();
      await Future.delayed(Duration.zero);
      expect(controller.month, DateTime(2026, 9, 1));
    });

    test('nextMonth rolls over the year boundary', () async {
      controller.month = DateTime(2026, 12, 1);
      controller.nextMonth();
      await Future.delayed(Duration.zero);
      expect(controller.month, DateTime(2027, 1, 1));
    });
  });
}
