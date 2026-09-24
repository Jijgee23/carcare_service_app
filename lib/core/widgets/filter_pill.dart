import 'package:flutter/material.dart';

import 'package:carcare_service/app/theme/app_theme.dart';

/// The one filter-chip style for list screens (quick filters, branch filter,
/// status filter): outlined, tinted with [color] when selected. [color]
/// defaults to the accent; status filters pass their status colour so the
/// colour still carries meaning.
///
/// The pill is drawn compact but its tap area is at least 40dp tall.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.accent;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? c.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                border: Border.all(
                  color: selected ? c : context.colors.divider,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? c : context.colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
