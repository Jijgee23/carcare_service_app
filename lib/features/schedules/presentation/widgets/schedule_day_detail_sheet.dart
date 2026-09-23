import 'package:flutter/material.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/features/schedules/domain/schedule.dart';
import 'package:carcare_service/features/schedules/presentation/widgets/schedule_legend.dart';

/// Read-only day-detail bottom sheet for My Schedule — tap a calendar day to
/// see its segments and branch names. No edit affordance here at all: My
/// Schedule has no permission-gated write path in this slice.
class ScheduleDayDetailSheet extends StatelessWidget {
  const ScheduleDayDetailSheet({
    super.key,
    required this.date,
    required this.cell,
  });

  final DateTime date;
  final ScheduleCell? cell;

  static Future<void> show(
    BuildContext context, {
    required DateTime date,
    required ScheduleCell? cell,
  }) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => ScheduleDayDetailSheet(date: date, cell: cell),
  );

  @override
  Widget build(BuildContext context) {
    final c = cell;
    final working = c?.working ?? false;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${date.year}/${date.month.toString().padLeft(2, '0')}/'
            '${date.day.toString().padLeft(2, '0')}',
            style: context.textStyles.h3,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                working ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: working ? context.colors.good : context.colors.textHint,
              ),
              const SizedBox(width: 6),
              Text(
                working ? 'Ажиллана' : 'Амарна',
                style: context.textStyles.bodyMedium,
              ),
              if (c != null) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheduleSourceColor(context, c.source),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          if (working && c != null && c.segments.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final s in c.segments)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: context.colors.textHint,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${s.startTime ?? '--:--'}–${s.endTime ?? '--:--'}',
                      style: context.textStyles.bodyMedium,
                    ),
                    const SizedBox(width: 8),
                    if (s.branchName != null)
                      Expanded(
                        child: Text(
                          s.branchName!,
                          style: context.textStyles.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
          const ScheduleLegend(),
        ],
      ),
    );
  }
}
