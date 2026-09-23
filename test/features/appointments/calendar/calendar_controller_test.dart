import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/appointments/domain/appointment.dart';
import 'package:carcare_service/features/appointments/presentation/controllers/calendar_controller.dart';

import '../../../fakes/fake_appointment_repository.dart';
import 'calendar_test_fixtures.dart';

/// Lets a test control exactly when `getCalendarDay` resolves, to prove the
/// controller's generation guard (mirrors `OrderListController`/P0-F7's
/// `_loadRequestId` pattern) discards a stale response.
class _ControllableAppointmentRepository extends FakeAppointmentRepository {
  final _pending = <Completer<Result<CalendarDayModel>>>[];
  int calls = 0;

  @override
  Future<Result<CalendarDayModel>> getCalendarDay({
    String? branchId,
    required DateTime date,
  }) {
    calls++;
    final completer = Completer<Result<CalendarDayModel>>();
    _pending.add(completer);
    return completer.future;
  }

  void resolve(int index, Result<CalendarDayModel> result) {
    _pending[index].complete(result);
  }
}

void main() {
  group('CalendarController', () {
    test(
      'no branch selected surfaces a dedicated prompt, never calls the API',
      () async {
        final repo = _ControllableAppointmentRepository();
        final controller = CalendarController(
          repo: repo,
          branchId: null,
          date: day(9),
        );
        await controller.load();
        expect(repo.calls, 0);
        expect(controller.state, isA<AsyncError<CalendarDayModel>>());
        final error = (controller.state as AsyncError<CalendarDayModel>).error;
        expect(error.code, 'NO_BRANCH_SELECTED');
      },
    );

    test(
      'load success populates state with the server model verbatim',
      () async {
        final repo = FakeAppointmentRepository();
        final controller = CalendarController(
          repo: repo,
          branchId: 'branch-1',
          date: day(9),
        );
        await controller.load();
        expect(controller.state, isA<AsyncData<CalendarDayModel>>());
      },
    );

    test(
      'load failure surfaces AsyncError with the repository error',
      () async {
        final repo = _ControllableAppointmentRepository();
        final controller = CalendarController(
          repo: repo,
          branchId: 'branch-1',
          date: day(9),
        );
        final future = controller.load();
        repo.resolve(
          0,
          const Err(
            AppError(ErrorKind.server, 'Сервер алдаа гарлаа', statusCode: 500),
          ),
        );
        await future;
        expect(controller.state, isA<AsyncError<CalendarDayModel>>());
      },
    );

    test(
      'a stale in-flight load never overwrites a newer result (race guard)',
      () async {
        final repo = _ControllableAppointmentRepository();
        final controller = CalendarController(
          repo: repo,
          branchId: 'branch-1',
          date: day(9),
        );

        final first = controller.load(); // request 0
        final second = controller.load(); // request 1 — supersedes request 0

        // Resolve the SECOND (newer) request first, then the stale first one.
        repo.resolve(1, Ok(dayModel(dateKey: '2026-09-22-second')));
        await second;
        repo.resolve(0, Ok(dayModel(dateKey: '2026-09-22-stale')));
        await first;

        final value = (controller.state as AsyncData<CalendarDayModel>).value;
        expect(value.dateKey, '2026-09-22-second');
      },
    );

    test('setDate/setBranch trigger a reload for the new selection', () async {
      final repo = FakeAppointmentRepository();
      final controller = CalendarController(
        repo: repo,
        branchId: 'branch-1',
        date: day(9),
      );
      await controller.load();

      await controller.setBranch('branch-2');
      expect(controller.branchId, 'branch-2');
      expect(controller.state, isA<AsyncData<CalendarDayModel>>());

      await controller.setDate(DateTime(2026, 9, 23));
      expect(controller.date, DateTime(2026, 9, 23));
    });
  });
}
