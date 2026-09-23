import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:carcare_service/app/theme/app_theme.dart';

final _hm = DateFormat('HH:mm');

/// One empty lane/hour cell. Touch-native slot selection: a past cell (or
/// one outside the branch's configured slot capacity) renders as an inert
/// placeholder with no tap target and no "add" affordance at all; a future,
/// in-capacity cell is a real button a caller can wire to appointment
/// registration ([onTap]). The distinction is entirely visual/interactive
/// here — [CalendarEmptyCell.tappable] itself is already decided by
/// `calendar_grid_layout.dart` from the model's own range/capacity fields.
class CalendarSlotCell extends StatelessWidget {
  const CalendarSlotCell({
    super.key,
    required this.hourStart,
    required this.tappable,
    this.onTap,
  });

  final DateTime hourStart;
  final bool tappable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarCareTheme.of(context);
    if (!tappable) {
      return const SizedBox.expand();
    }
    final label = 'Захиалга авах: ${_hm.format(hourStart)}';
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.borderSubtle,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: onTap == null
                ? const SizedBox.expand()
                : Center(
                    child: Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: theme.mutedText3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
