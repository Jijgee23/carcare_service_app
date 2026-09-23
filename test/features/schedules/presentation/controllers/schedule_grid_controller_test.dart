import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/schedules/domain/schedule.dart';
import 'package:carcare_service/features/schedules/domain/schedules_repository.dart';
import 'package:carcare_service/features/schedules/presentation/controllers/schedule_grid_controller.dart';

import '../../data/fake_schedule_repository.dart';

/// Records every [getGrid] query issued through it, delegating to a
/// [FakeScheduleRepository] for the actual response — lets these tests
/// assert on navigation/filter wiring without re-testing the fake itself.
class _RecordingRepository implements SchedulesRepository {
  _RecordingRepository(this._inner);
  final FakeScheduleRepository _inner;
  final List<ScheduleGridQuery> queries = [];

  @override
  Future<Result<ScheduleGrid>> getGrid({ScheduleGridQuery? query}) {
    queries.add(query ?? const ScheduleGridQuery());
    return _inner.getGrid(query: query);
  }

  @override
  Future<Result<MySchedule>> getMySchedule({String? month}) =>
      _inner.getMySchedule(month: month);

  @override
  Future<Result<ScheduleUpsertResult>> upsert(
    String userId, {
    required ScheduleScope scope,
    String? date,
    Weekday? weekday,
    required bool isWorking,
    List<ScheduleSegmentInput> segments = const [],
  }) => _inner.upsert(
    userId,
    scope: scope,
    date: date,
    weekday: weekday,
    isWorking: isWorking,
    segments: segments,
  );

  @override
  Future<Result<ScheduleResetResult>> reset(
    String userId, {
    required ScheduleScope scope,
    String? date,
    Weekday? weekday,
  }) => _inner.reset(userId, scope: scope, date: date, weekday: weekday);

  @override
  Future<Result<ScheduleBulkResult>> bulkUpsert({
    required ScheduleScope scope,
    required bool isWorking,
    List<ScheduleSegmentInput> segments = const [],
    required List<ScheduleBulkTarget> targets,
  }) => _inner.bulkUpsert(
    scope: scope,
    isWorking: isWorking,
    segments: segments,
    targets: targets,
  );
}

void main() {
  group('ScheduleGridController', () {
    late _RecordingRepository repo;
    late ScheduleGridController controller;

    setUp(() {
      repo = _RecordingRepository(
        FakeScheduleRepository(
          seed: [
            FakeScheduleRepository.seedRow(id: 'u-1', name: 'Бат'),
            FakeScheduleRepository.seedRow(id: 'u-2', name: 'Дорж'),
          ],
        ),
      );
      controller = ScheduleGridController(repo: repo);
    });

    tearDown(() => controller.dispose());

    test('load populates grid state and exposes canEdit', () async {
      expect(controller.gridState, isA<AsyncLoading>());
      await controller.load();
      expect(controller.gridState, isA<AsyncData<ScheduleGrid>>());
      expect(controller.grid!.rows, hasLength(2));
      expect(controller.canEdit, isTrue);
    });

    test('setView reloads with the new view param', () async {
      await controller.load();
      controller.setView('month');
      await Future.delayed(Duration.zero);
      expect(repo.queries.last.view, 'month');
    });

    test('nextPeriod/prevPeriod advance by 7 days in week view', () async {
      controller.anchorDate = DateTime(2026, 9, 21);
      await controller.load();
      controller.nextPeriod();
      await Future.delayed(Duration.zero);
      expect(controller.anchorDate, DateTime(2026, 9, 28));
      controller.prevPeriod();
      await Future.delayed(Duration.zero);
      expect(controller.anchorDate, DateTime(2026, 9, 21));
    });

    test('nextPeriod advances by a month in month view', () async {
      controller.anchorDate = DateTime(2026, 9, 21);
      controller.setView('month');
      await Future.delayed(Duration.zero);
      controller.nextPeriod();
      await Future.delayed(Duration.zero);
      expect(controller.anchorDate, DateTime(2026, 10, 1));
    });

    test('setBranch filters and is passed through to the query', () async {
      await controller.load();
      controller.setBranch('b-1');
      await Future.delayed(Duration.zero);
      expect(repo.queries.last.branchId, 'b-1');
    });

    test('setQuery debounces then reloads with q', () async {
      await controller.load();
      controller.setQuery('Бат');
      expect(repo.queries.last.q, isNot('Бат')); // not yet fired
      await Future.delayed(const Duration(milliseconds: 400));
      expect(repo.queries.last.q, 'Бат');
    });

    group('rectangular range selection', () {
      test('rectangleBetween computes the full inclusive rectangle', () async {
        await controller.load();
        final grid = controller.grid!;
        final dates =
            grid.dates; // single date in the fake, but exercised below
        expect(dates, isNotEmpty);
        final anchor = ScheduleGridController.cellKey('u-1', dates.first);
        final end = ScheduleGridController.cellKey('u-2', dates.first);
        final rect = controller.rectangleBetween(anchor, end);
        expect(rect, {
          ScheduleGridController.cellKey('u-1', dates.first),
          ScheduleGridController.cellKey('u-2', dates.first),
        });
      });

      test(
        'onRangeTap: first tap anchors, second commits the rectangle',
        () async {
          await controller.load();
          final date = controller.grid!.dates.first;
          controller.enterSelectionMode();
          controller.onRangeTap('u-1', date);
          expect(controller.selection.isRangeActive, isTrue);
          expect(controller.selection.isEmpty, isTrue);

          controller.onRangeTap('u-2', date);
          expect(controller.selection.isRangeActive, isFalse);
          expect(controller.selection.selected, {
            ScheduleGridController.cellKey('u-1', date),
            ScheduleGridController.cellKey('u-2', date),
          });
        },
      );

      test('tapping the anchor again cancels the pending range', () async {
        await controller.load();
        final date = controller.grid!.dates.first;
        controller.enterSelectionMode();
        controller.onRangeTap('u-1', date);
        controller.onRangeTap('u-1', date);
        expect(controller.selection.isRangeActive, isFalse);
        expect(controller.selection.isEmpty, isTrue);
      });

      test('toggleCell flips one cell without needing an anchor', () async {
        await controller.load();
        final date = controller.grid!.dates.first;
        controller.toggleCell('u-1', date);
        expect(
          controller.selection.isSelected(
            ScheduleGridController.cellKey('u-1', date),
          ),
          isTrue,
        );
        controller.toggleCell('u-1', date);
        expect(
          controller.selection.isSelected(
            ScheduleGridController.cellKey('u-1', date),
          ),
          isFalse,
        );
      });
    });

    group('bulk targets (date vs weekday scope)', () {
      test('date scope: one target per selected cell, unchanged', () {
        controller.toggleCell('u-1', '2026-09-21'); // Monday
        controller.toggleCell('u-1', '2026-09-28'); // Monday, next week
        controller.toggleCell('u-2', '2026-09-22'); // Tuesday

        final targets = controller.bulkTargets(ScheduleScope.date);
        expect(targets, hasLength(3));
        expect(targets.map((t) => (t.userId, t.date, t.weekday)).toSet(), {
          ('u-1', '2026-09-21', null),
          ('u-1', '2026-09-28', null),
          ('u-2', '2026-09-22', null),
        });
      });

      test('weekday scope: a rectangular selection spanning two weeks '
          'dedupes to one target per (user, weekday)', () {
        // Two Mondays and one Tuesday for u-1, one Monday for u-2 — as a
        // rectangular selection spanning 2026-09-21..2026-09-28 would
        // produce for any user working both Mondays.
        controller.toggleCell('u-1', '2026-09-21'); // Monday
        controller.toggleCell('u-1', '2026-09-28'); // Monday (2nd week)
        controller.toggleCell('u-1', '2026-09-22'); // Tuesday
        controller.toggleCell('u-2', '2026-09-21'); // Monday

        final targets = controller.bulkTargets(ScheduleScope.weekday);
        // u-1 Monday is deduped to a single target despite 2 selected dates.
        expect(targets, hasLength(3));
        expect(targets.map((t) => (t.userId, t.weekday)).toSet(), {
          ('u-1', Weekday.mon),
          ('u-1', Weekday.tue),
          ('u-2', Weekday.mon),
        });
        // No target carries a date under weekday scope.
        expect(targets.every((t) => t.date == null), isTrue);
      });

      test(
        'distinctWeekdaysForSelection / orderedDistinctWeekdaysForSelection',
        () {
          controller.toggleCell('u-1', '2026-09-23'); // Wednesday
          controller.toggleCell('u-1', '2026-09-21'); // Monday
          controller.toggleCell('u-2', '2026-09-21'); // Monday (dup weekday)

          expect(controller.distinctWeekdaysForSelection(), {
            Weekday.wed,
            Weekday.mon,
          });
          expect(controller.orderedDistinctWeekdaysForSelection(), [
            Weekday.mon,
            Weekday.wed,
          ]);
        },
      );
    });
  });
}
