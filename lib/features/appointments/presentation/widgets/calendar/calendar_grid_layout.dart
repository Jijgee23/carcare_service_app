/// Pure, testable layout geometry for the tablet day grid — P2-F3.
///
/// This module computes ONLY where to draw things: which hour row a block
/// starts on, how many rows it spans, and which lane/hour cells are empty
/// and (for empty future capacity within [CalendarDayModel.slotCapacity])
/// tappable to start a booking. It never recomputes status, issues,
/// open-ended/day-boundary handling or capacity overflow — those are read
/// verbatim off [CalendarBlock] / [CalendarDayModel], which already carry
/// them from the server's `calendar-day-model.ts`. Deriving any of that
/// here would be exactly the truth-duplication this slice exists to avoid.
library;

import 'package:carcare_service/features/appointments/domain/appointment.dart';

/// One hour-row boundary of the rendered grid, business-local.
class CalendarHourRow {
  final DateTime start;
  const CalendarHourRow(this.start);
}

/// A block, anchored to the hour row it starts on and spanning [spanRows]
/// rows. [spanRows] is a pure display quantity (how tall to draw the
/// block) — it is derived from the already-resolved [block.startAt]/
/// [block.endAt], never from any status/issue field.
class CalendarLaneBlock {
  final int rowIndex;
  final int spanRows;
  final CalendarBlock block;
  const CalendarLaneBlock({
    required this.rowIndex,
    required this.spanRows,
    required this.block,
  });
}

/// One empty (no block) lane/hour cell. [tappable] is true only when the
/// cell is future (its hour has not fully elapsed) AND its lane is within
/// the branch's configured [CalendarDayModel.slotCapacity] — an overflow
/// lane never offers a booking affordance, since it is not real bookable
/// capacity.
class CalendarEmptyCell {
  final int rowIndex;
  final DateTime hourStart;
  final bool tappable;
  const CalendarEmptyCell({
    required this.rowIndex,
    required this.hourStart,
    required this.tappable,
  });
}

class CalendarLaneLayout {
  final int laneIndex;
  final List<CalendarLaneBlock> blocks;
  final List<CalendarEmptyCell> emptyCells;
  const CalendarLaneLayout({
    required this.laneIndex,
    required this.blocks,
    required this.emptyCells,
  });
}

class CalendarGridLayout {
  final List<CalendarHourRow> hours;
  final List<CalendarLaneLayout> lanes;
  const CalendarGridLayout({required this.hours, required this.lanes});
}

DateTime _hourFloor(DateTime value) =>
    DateTime(value.year, value.month, value.day, value.hour);

/// Builds the full grid layout for [model]. [now] is injectable for tests;
/// defaults to the wall clock.
CalendarGridLayout buildCalendarGridLayout(
  CalendarDayModel model, {
  DateTime? now,
}) {
  final nowLocal = now ?? DateTime.now();
  final rangeStart = model.rangeStart?.toLocal();
  final rangeEnd = model.rangeEnd?.toLocal();

  final hours = <CalendarHourRow>[];
  if (rangeStart != null && rangeEnd != null && rangeEnd.isAfter(rangeStart)) {
    var cursor = _hourFloor(rangeStart);
    while (cursor.isBefore(rangeEnd)) {
      hours.add(CalendarHourRow(cursor));
      cursor = cursor.add(const Duration(hours: 1));
    }
  }
  if (hours.isEmpty) {
    // Malformed/missing range — still render a usable single-row grid
    // rather than an empty widget the caller cannot distinguish from
    // "no appointments".
    hours.add(CalendarHourRow(_hourFloor(nowLocal)));
  }

  final laneCount = model.laneCount < 1 ? 1 : model.laneCount;
  final lanes = <CalendarLaneLayout>[];
  for (var lane = 0; lane < laneCount; lane++) {
    final laneBlocks = <CalendarLaneBlock>[];
    final occupiedRows = <int>{};
    for (final block in model.blocks) {
      if (block.laneIndex != lane) continue;
      final start = block.startAt?.toLocal();
      if (start == null) continue;
      final startHour = _hourFloor(start);
      var rowIndex = hours.indexWhere((h) => h.start == startHour);
      if (rowIndex < 0) {
        // Block starts before/after the rendered range (clock skew,
        // malformed range) — clamp to the nearest edge rather than
        // dropping it silently.
        rowIndex = startHour.isBefore(hours.first.start) ? 0 : hours.length - 1;
      }
      final end = block.endAt?.toLocal();
      final minutes = end != null ? end.difference(start).inMinutes : 60;
      final spanRows = (minutes / 60).ceil().clamp(1, hours.length - rowIndex);
      laneBlocks.add(
        CalendarLaneBlock(rowIndex: rowIndex, spanRows: spanRows, block: block),
      );
      for (var r = rowIndex; r < rowIndex + spanRows; r++) {
        occupiedRows.add(r);
      }
    }
    final emptyCells = <CalendarEmptyCell>[];
    for (var row = 0; row < hours.length; row++) {
      if (occupiedRows.contains(row)) continue;
      final hourStart = hours[row].start;
      final isFuture = hourStart
          .add(const Duration(hours: 1))
          .isAfter(nowLocal);
      final withinCapacity = lane < model.slotCapacity;
      emptyCells.add(
        CalendarEmptyCell(
          rowIndex: row,
          hourStart: hourStart,
          tappable: isFuture && withinCapacity,
        ),
      );
    }
    lanes.add(
      CalendarLaneLayout(
        laneIndex: lane,
        blocks: laneBlocks,
        emptyCells: emptyCells,
      ),
    );
  }

  return CalendarGridLayout(hours: hours, lanes: lanes);
}
