import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/appointments/domain/appointment.dart';
import 'package:carcare_service/features/appointments/presentation/controllers/calendar_controller.dart';

import '../../../fakes/fake_appointment_repository.dart';
import 'calendar_test_fixtures.dart';

/// Queues a `Completer` per `getMonthCounts` call so a test can resolve
/// overlapping month-count fetches out of order — modelled exactly on
/// `_QueuedAppointmentsRepository` in `appointment_controller_race_test.dart`.
/// `getCalendarDay` is left to the real [FakeAppointmentRepository]
/// implementation (fast, synchronous-ish) since these tests race the
/// month-counts fetch specifically, not the day-model load.
class _QueuedMonthCountsRepository extends FakeAppointmentRepository {
  final monthRequests = <DateTime>[];
  final pendingCounts = <Completer<Result<Map<DateTime, int>>>>[];

  @override
  Future<Result<Map<DateTime, int>>> getMonthCounts({
    String? branchId,
    required DateTime month,
  }) {
    monthRequests.add(month);
    final completer = Completer<Result<Map<DateTime, int>>>();
    pendingCounts.add(completer);
    return completer.future;
  }
}

void main() {
  group('CalendarController month-counts', () {
    test(
      'a stale in-flight month fetch never overwrites a newer month\'s counts',
      () async {
        final repo = _QueuedMonthCountsRepository();
        final controller = CalendarController(
          repo: repo,
          branchId: 'branch-1',
          date: DateTime(2026, 9, 22),
        );

        // First load fires the September fetch (request 0).
        await controller.load();
        expect(repo.monthRequests, [DateTime(2026, 9)]);

        // Paging to October fires a second, newer fetch (request 1) before
        // the September one has resolved.
        final octoberLoad = controller.setDate(DateTime(2026, 10, 5));
        await octoberLoad;
        expect(repo.monthRequests, [DateTime(2026, 9), DateTime(2026, 10)]);

        // Resolve the NEWER (October) request first, then let the stale
        // September one resolve after — it must not win.
        repo.pendingCounts[1].complete(Ok({DateTime(2026, 10, 5): 7}));
        repo.pendingCounts[0].complete(Ok({DateTime(2026, 9, 22): 3}));
        // Let both responses' continuations run.
        await Future<void>.delayed(Duration.zero);

        expect(controller.countFor(DateTime(2026, 10, 5)), 7);
        expect(controller.countFor(DateTime(2026, 9, 22)), 0);
        controller.dispose();
      },
    );

    test('a day absent from the counts map renders no dot (countFor is 0, not present-as-zero)', () async {
      final repo = FakeAppointmentRepository(
        seed: [
          AppointmentSummary(
            id: 'appt-has-count',
            status: AppointmentStatus.PENDING,
            requestedAt: DateTime(2026, 9, 22, 10),
            branch: const AppointmentBranchRef(
              id: 'branch-1',
              name: 'Толгойт салбар',
            ),
          ),
        ],
      );
      final controller = CalendarController(
        repo: repo,
        branchId: 'branch-1',
        date: DateTime(2026, 9, 22),
      );
      await controller.load();
      // The real fake resolves getMonthCounts asynchronously (not via a
      // manually-completed Completer); flush the microtask queue so its
      // continuation has run before asserting on the counts it produced.
      await Future<void>.delayed(Duration.zero);

      expect(controller.countFor(DateTime(2026, 9, 22)), 1);
      // A day with zero appointments is absent from the map entirely —
      // countFor must fall back to 0, not throw or read a stored zero.
      expect(controller.countFor(DateTime(2026, 9, 23)), 0);
      expect(
        controller.monthCounts.containsKey(DateTime(2026, 9, 23)),
        isFalse,
      );
      controller.dispose();
    });

    test(
      'a failed month-counts fetch leaves the calendar day model rendered',
      () async {
        final repo = _QueuedMonthCountsRepository();
        final controller = CalendarController(
          repo: repo,
          branchId: 'branch-1',
          date: DateTime(2026, 9, 22),
        );

        final load = controller.load();
        repo.pendingCounts[0].complete(
          const Err(
            AppError(ErrorKind.server, 'Сервер алдаа гарлаа', statusCode: 500),
          ),
        );
        await load;

        // The day model (the authoritative render) must still be there —
        // a month-counts failure must never surface as an error state over
        // the whole calendar.
        expect(controller.state, isA<AsyncData<CalendarDayModel>>());
        expect(controller.countFor(DateTime(2026, 9, 22)), 0);
        controller.dispose();
      },
    );
  });
}
