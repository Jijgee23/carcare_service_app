import 'package:flutter/material.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';

/// One action offered by a [SelectionActionBar] — a label, an icon, and a
/// callback. `onPressed: null` renders it disabled (e.g. no target picked
/// yet), matching every other button in this app.
class SelectionAction {
  const SelectionAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
}

/// Generic bottom action bar for a `SelectionController`-driven surface:
/// shows the selected count, a clear ("x") button, and the caller's
/// [actions]. New, reusable widget under `lib/core/widgets/selection/` —
/// modelled on the affordance the orders/services bulk-selection bars
/// already use (count + clear + primary action row) but deliberately not a
/// copy of either file, both of which stay untouched.
class SelectionActionBar extends StatelessWidget {
  const SelectionActionBar({
    super.key,
    required this.count,
    required this.onClear,
    this.actions = const [],
    this.busy = false,
  });

  final int count;
  final VoidCallback onClear;
  final List<SelectionAction> actions;

  /// True while a bulk action is in flight — disables every action button
  /// and the clear button so a second tap cannot race the first.
  final bool busy;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Material(
        color: context.colors.surface,
        elevation: 4,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('selection_bar_clear'),
                icon: const Icon(Icons.close),
                tooltip: 'Цуцлах',
                onPressed: busy ? null : onClear,
              ),
              Flexible(
                child: Text(
                  '$count сонгосон',
                  style: context.textStyles.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              for (final action in actions) ...[
                const SizedBox(width: 6),
                _ActionButton(action: action, busy: busy),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.busy});
  final SelectionAction action;
  final bool busy;

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: busy ? null : action.onPressed,
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    icon: busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(action.icon, size: 16),
    label: Text(action.label, style: const TextStyle(fontSize: 13)),
  );
}

/// Banner listing per-row failures from a bulk operation that reports
/// partial success (never all-or-nothing) — the shape
/// `EmployeeBulkResult`/`BulkCategoryResult` both share. Generic over that
/// shape: the caller supplies [succeeded]/[failed]/[errors] directly rather
/// than this widget depending on any one feature's result type, so it stays
/// reusable from `lib/core/widgets/selection/`.
class SelectionResultBanner extends StatelessWidget {
  const SelectionResultBanner({
    super.key,
    required this.succeeded,
    required this.failed,
    this.errors = const [],
  });

  final int succeeded;
  final int failed;
  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    final hasFailures = failed > 0;
    return Container(
      key: const ValueKey('selection_result_banner'),
      margin: const EdgeInsets.fromLTRB(
        AppDimens.paddingMD,
        AppDimens.paddingMD,
        AppDimens.paddingMD,
        0,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasFailures ? context.colors.dangerBg : context.colors.goodBg,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$succeeded амжилттай, $failed амжилтгүй',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: hasFailures ? context.colors.danger : context.colors.good,
            ),
          ),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...errors.map(
              (e) => Text(
                '• $e',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A checkbox-leading list row that toggles on tap and enters selection
/// mode on long-press — the common convention this slice and any future
/// caller of [SelectionController] should share for a plain (non-grid) row.
class SelectableListTile extends StatelessWidget {
  const SelectableListTile({
    super.key,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.child,
  });

  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? context.colors.accent.withValues(alpha: 0.08)
        : context.colors.surface,
    borderRadius: BorderRadius.circular(AppDimens.radiusLG),
    child: InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppDimens.radiusLG),
      child: Row(
        children: [
          if (selectionMode)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Checkbox(value: selected, onChanged: (_) => onTap()),
            ),
          Expanded(child: child),
        ],
      ),
    ),
  );
}
