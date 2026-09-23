import 'package:flutter/material.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/features/appointments/domain/appointment.dart';

import 'calendar_status_style.dart';
import 'calendar_time_format.dart';

/// Renders one [CalendarBlock] — shared between the tablet day grid and the
/// phone agenda so both surfaces stay visually and semantically consistent.
///
/// [dense] controls how much visible content a narrow rendering keeps
/// (grid cells can be a few dozen pixels tall); the block's full meaning is
/// never lost even when [dense] drops most of the visible text, because the
/// whole tile is wrapped in a single [Semantics] node carrying the
/// server-built [CalendarBlock.accessibleLabel] verbatim — that string
/// already contains every fact the block conveys (time range, name,
/// status, payment, issue, overflow), see `calendar-day-model.ts`'s
/// `buildAccessibleLabel`. This widget must never rebuild that sentence
/// from parts; it only renders (a subset of) the same facts visually.
class CalendarBlockTile extends StatelessWidget {
  const CalendarBlockTile({
    super.key,
    required this.block,
    this.dense = false,
    this.onTap,
  });

  final CalendarBlock block;
  final bool dense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarCareTheme.of(context);
    final color = calendarStatusColor(context, block.status);
    final timeLabel = calendarBlockTimeLabel(block);

    return Semantics(
      label: block.accessibleLabel,
      button: onTap != null,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 6 : AppDimens.paddingSM,
              vertical: dense ? 2 : AppDimens.paddingXS,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(
                color: block.issue != null ? theme.danger : color,
                width: block.issue != null ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Open-ended/unknown-finish work is visually distinct
                    // from a known finish — a dedicated icon, not just the
                    // text, so it still reads at a glance in a dense cell.
                    if (!block.finishKnown)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.all_inclusive_rounded,
                          size: dense ? 12 : 14,
                          color: theme.mutedText,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        timeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (dense
                                    ? context.textStyles.caption
                                    : context.textStyles.captionMedium)
                                .copyWith(fontFamily: theme.monoFontFamily),
                      ),
                    ),
                    if (block.capacityOverflow)
                      Icon(
                        Icons.warning_amber_rounded,
                        size: dense ? 12 : 14,
                        color: theme.warn,
                      ),
                    if (block.issue != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(
                          Icons.error_outline_rounded,
                          size: dense ? 12 : 14,
                          color: theme.danger,
                        ),
                      ),
                  ],
                ),
                if (!dense) const SizedBox(height: 2),
                Text(
                  block.name,
                  maxLines: dense ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (dense
                              ? context.textStyles.caption
                              : context.textStyles.body)
                          .copyWith(fontWeight: FontWeight.w600),
                ),
                if (!dense) ...[
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      _Chip(label: block.statusLabel, color: color),
                      if (block.paymentStatusLabel != null)
                        _Chip(
                          label: block.paymentStatusLabel!,
                          color: theme.mutedText2,
                        ),
                      if (block.issue != null)
                        _Chip(label: block.issue!.label, color: theme.danger),
                      if (block.capacityOverflow)
                        _Chip(label: 'Багтаамжаас хэтэрсэн', color: theme.warn),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppRadii.control),
    ),
    child: Text(
      label,
      style: context.textStyles.caption.copyWith(color: color, fontSize: 10),
    ),
  );
}
