import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:carservice_business/core/domain/working_branch_scope.dart';
import 'package:carservice_business/core/network/working_branch_interceptor.dart';
import 'package:carservice_business/core/widgets/app_dropdown.dart';
import 'package:carservice_business/features/shell/presentation/controllers/working_branch_controller.dart';

/// Reusable compact working-branch selector (Бусад → profile card).
class WorkingBranchSwitcher extends StatelessWidget {
  final WorkingBranchController? controller;

  /// Fill the available width, the picked name right-aligned and
  /// ellipsized — for a row where a long branch name must not overflow.
  final bool expanded;

  const WorkingBranchSwitcher({
    super.key,
    this.controller,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = controller ?? context.watch<WorkingBranchController>();
    if (value.state == WorkingBranchLoadState.initial || value.isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (value.hasError || value.options.branches.isEmpty) {
      return const SizedBox.shrink();
    }

    final choices = <AppDropdownItem<String>>[];
    if (value.options.allowAll && !value.isLocked) {
      choices.add(
        const AppDropdownItem(value: allWorkingBranches, label: 'Бүх салбар'),
      );
    }
    choices.addAll(
      value.options.branches.map(
        (branch) => AppDropdownItem(value: branch.id, label: branch.name),
      ),
    );
    if (value.isLocked &&
        value.options.lockedBranchId != null &&
        !choices.any(
          (choice) => choice.value == value.options.lockedBranchId,
        )) {
      choices.add(
        AppDropdownItem(
          value: value.options.lockedBranchId!,
          label: 'Түгжигдсэн салбар',
        ),
      );
    }
    final selected =
        value.selection != null &&
            choices.any((choice) => choice.value == value.selection)
        ? value.selection
        : (value.isLocked ? value.options.lockedBranchId : null);

    return AppDropdown<String>(
      value: selected,
      hint: 'Салбар',
      variant: AppDropdownVariant.inline,
      expand: expanded,
      onChanged: value.isLocked ? null : value.select,
      items: choices,
    );
  }
}
