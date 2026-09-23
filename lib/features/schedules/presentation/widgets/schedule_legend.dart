import 'package:flutter/material.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/features/schedules/domain/schedule.dart';

/// Colour/label for a [ScheduleSource] badge — shared by the grid cell and
/// its legend so the two can never drift apart.
Color scheduleSourceColor(BuildContext context, ScheduleSource source) =>
    switch (source) {
      ScheduleSource.exception => context.colors.accent,
      ScheduleSource.weekly => context.colors.good,
      ScheduleSource.scheduleDefault => context.colors.textHint,
      ScheduleSource.unknown => context.colors.divider,
    };

String scheduleSourceLabel(ScheduleSource source) => switch (source) {
  ScheduleSource.exception => 'Онцгой өдөр',
  ScheduleSource.weekly => 'Долоо хоногийн дүрэм',
  ScheduleSource.scheduleDefault => 'Үндсэн цаг',
  ScheduleSource.unknown => 'Тодорхойгүй',
};

/// Legend row explaining the exception/weekly/default source markers — one
/// visual key shared by every grid render.
class ScheduleLegend extends StatelessWidget {
  const ScheduleLegend({super.key});

  static const _sources = [
    ScheduleSource.exception,
    ScheduleSource.weekly,
    ScheduleSource.scheduleDefault,
  ];

  @override
  Widget build(BuildContext context) => Wrap(
    key: const ValueKey('schedule_legend'),
    spacing: 12,
    runSpacing: 4,
    children: [
      for (final source in _sources)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: scheduleSourceColor(context, source),
                shape: BoxShape.circle,
              ),
            ),
            Text(
              scheduleSourceLabel(source),
              style: context.textStyles.caption,
            ),
          ],
        ),
    ],
  );
}
