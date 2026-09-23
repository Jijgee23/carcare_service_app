import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/features/appointments/domain/appointment.dart';

import 'calendar_block_tile.dart';
import 'calendar_grid_layout.dart';
import 'calendar_slot_cell.dart';

final _hm = DateFormat('HH:mm');

/// Tablet rendering: a day grid, one column per lane, one row per hour of
/// the branch's business day. Positioning comes entirely from
/// [buildCalendarGridLayout] (pure display geometry over the server's
/// already-resolved [CalendarBlock] fields); this widget draws what that
/// layout says and nothing else.
class CalendarDayGrid extends StatelessWidget {
  const CalendarDayGrid({
    super.key,
    required this.model,
    this.onOpenBlock,
    this.onCreateAt,
    this.rowHeight = 56,
    this.laneColumnWidth = 168,
    this.now,
  });

  final CalendarDayModel model;
  final void Function(CalendarBlock block)? onOpenBlock;
  final void Function(DateTime slotStart)? onCreateAt;
  final double rowHeight;
  final double laneColumnWidth;

  /// Injectable for tests; defaults to the wall clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = CarCareTheme.of(context);
    final layout = buildCalendarGridLayout(model, now: now);
    final totalHeight = layout.hours.length * rowHeight;

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hour axis.
            SizedBox(
              width: 56,
              child: Column(
                children: [
                  for (final hour in layout.hours)
                    SizedBox(
                      height: rowHeight,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _hm.format(hour.start),
                            style: context.textStyles.caption.copyWith(
                              fontFamily: theme.monoFontFamily,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (final lane in layout.lanes)
              Container(
                width: laneColumnWidth,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: theme.border)),
                ),
                child: SizedBox(
                  height: totalHeight,
                  child: Stack(
                    children: [
                      // Hour gridlines, purely decorative.
                      for (var row = 0; row < layout.hours.length; row++)
                        Positioned(
                          top: row * rowHeight,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 1,
                            color: theme.borderSubtle,
                          ),
                        ),
                      for (final empty in lane.emptyCells)
                        Positioned(
                          top: empty.rowIndex * rowHeight,
                          left: 2,
                          right: 2,
                          height: rowHeight - 2,
                          child: CalendarSlotCell(
                            hourStart: empty.hourStart,
                            tappable: empty.tappable,
                            onTap: empty.tappable && onCreateAt != null
                                ? () => onCreateAt!(empty.hourStart)
                                : null,
                          ),
                        ),
                      for (final laneBlock in lane.blocks)
                        Positioned(
                          top: laneBlock.rowIndex * rowHeight + 1,
                          left: 2,
                          right: 2,
                          height: laneBlock.spanRows * rowHeight - 2,
                          child: CalendarBlockTile(
                            block: laneBlock.block,
                            dense: laneBlock.spanRows <= 1,
                            onTap: onOpenBlock == null
                                ? null
                                : () => onOpenBlock!(laneBlock.block),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
