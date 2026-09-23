import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/core/domain/working_branch_scope.dart';
import 'package:carcare_service/core/network/working_branch_interceptor.dart';
import 'package:carcare_service/features/shell/presentation/controllers/working_branch_controller.dart';

/// Reusable compact working-branch selector for the adaptive app header.
class WorkingBranchSwitcher extends StatelessWidget {
  final WorkingBranchController? controller;

  const WorkingBranchSwitcher({super.key, this.controller});

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

    final choices = <DropdownMenuItem<String>>[];
    if (value.options.allowAll && !value.isLocked) {
      choices.add(
        const DropdownMenuItem(
          value: allWorkingBranches,
          child: Text('Бүх салбар'),
        ),
      );
    }
    choices.addAll(
      value.options.branches.map(
        (branch) => DropdownMenuItem(
          value: branch.id,
          child: Text(branch.name, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
    if (value.isLocked &&
        value.options.lockedBranchId != null &&
        !choices.any(
          (choice) => choice.value == value.options.lockedBranchId,
        )) {
      choices.add(
        DropdownMenuItem(
          value: value.options.lockedBranchId,
          child: const Text('Түгжигдсэн салбар'),
        ),
      );
    }
    final selected =
        value.selection != null &&
            choices.any((choice) => choice.value == value.selection)
        ? value.selection
        : (value.isLocked ? value.options.lockedBranchId : null);

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selected,
        hint: const Text('Салбар'),
        isDense: true,
        isExpanded: false,
        icon: const Icon(Icons.unfold_more, size: 18),
        onChanged: value.isLocked
            ? null
            : (next) {
                if (next != null) value.select(next);
              },
        items: choices,
      ),
    );
  }
}
