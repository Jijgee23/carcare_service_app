import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/features/appointments/presentation/widgets/calendar/calendar_grid_layout.dart';

import 'calendar_test_fixtures.dart';

void main() {
  group('buildCalendarGridLayout', () {
    test('known-finish block spans its exact duration', () {
      final model = dayModel(blocks: [knownFinishBlock()]);
      final layout = buildCalendarGridLayout(model, now: day(8));
      final lane0 = layout.lanes.first;
      expect(lane0.blocks, hasLength(1));
      final block = lane0.blocks.single;
      // 09:00 is row 0 (range starts at 09:00); a 1h block spans 1 row.
      expect(block.rowIndex, 0);
      expect(block.spanRows, 1);
    });

    test('open-ended block spans the remaining rendered range, not zero', () {
      final block = openEndedBlock(startAt: day(11), endAt: day(21));
      final model = dayModel(
        blocks: [block],
        rangeStart: day(9),
        rangeEnd: day(21),
      );
      final layout = buildCalendarGridLayout(model, now: day(8));
      final laid = layout.lanes.first.blocks.single;
      expect(laid.spanRows, greaterThan(0));
      // Layout geometry must be driven by the server's own endAt/startAt,
      // never by inventing a duration for `finishKnown == false`.
      expect(laid.block.finishKnown, isFalse);
    });

    test('day-boundary block is not clipped to a bogus negative span', () {
      final model = dayModel(
        blocks: [dayBoundaryBlock()],
        rangeStart: day(9),
        rangeEnd: DateTime(2026, 9, 23),
      );
      final layout = buildCalendarGridLayout(model, now: day(8));
      final laid = layout.lanes.first.blocks.single;
      expect(laid.spanRows, greaterThanOrEqualTo(1));
      expect(laid.block.endsAtDayBoundary, isTrue);
    });

    test(
      'overflow lane (>= slotCapacity) never marks empty cells tappable',
      () {
        final overflowBlock = knownFinishBlock(laneIndex: 1);
        final model = dayModel(
          blocks: [overflowBlock],
          slotCapacity: 1,
          laneCount: 2,
          rangeStart: day(9),
          rangeEnd: day(12),
        );
        final layout = buildCalendarGridLayout(model, now: day(8));
        final overflowLane = layout.lanes.firstWhere((l) => l.laneIndex == 1);
        expect(overflowLane.emptyCells, isNotEmpty);
        expect(overflowLane.emptyCells.every((c) => !c.tappable), isTrue);
      },
    );

    test('in-capacity lane: past cells are not tappable, future cells are', () {
      final model = dayModel(
        rangeStart: day(9),
        rangeEnd: day(12),
        slotCapacity: 1,
      );
      // "Now" sits inside the range: 09:00-10:00 and 10:00-11:00 are past,
      // 11:00-12:00 is still future.
      final layout = buildCalendarGridLayout(model, now: day(10, 30));
      final lane0 = layout.lanes.single;
      final past = lane0.emptyCells.where(
        (c) => c.hourStart.isBefore(day(10, 30)),
      );
      final future = lane0.emptyCells.where(
        (c) => !c.hourStart.isBefore(day(10, 30)),
      );
      expect(past, isNotEmpty);
      expect(future, isNotEmpty);
      for (final cell in past) {
        // 09:00-10:00 has already fully elapsed by 10:30 → not tappable.
        if (cell.hourStart == day(9)) expect(cell.tappable, isFalse);
      }
      for (final cell in future) {
        expect(cell.tappable, isTrue);
      }
    });

    test('a block never produces an empty-cell affordance on its own rows', () {
      final model = dayModel(
        blocks: [knownFinishBlock(startAt: day(9), endAt: day(11))],
        rangeStart: day(9),
        rangeEnd: day(12),
      );
      final layout = buildCalendarGridLayout(model, now: day(8));
      final lane0 = layout.lanes.single;
      final emptyRows = lane0.emptyCells.map((c) => c.rowIndex).toSet();
      final blockRows = <int>{};
      for (final b in lane0.blocks) {
        for (var r = b.rowIndex; r < b.rowIndex + b.spanRows; r++) {
          blockRows.add(r);
        }
      }
      expect(emptyRows.intersection(blockRows), isEmpty);
    });
  });
}
