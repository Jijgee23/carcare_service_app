import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/features/schedules/domain/schedule.dart';
import 'package:carcare_service/features/schedules/presentation/controllers/schedule_edit_controller.dart';

/// Shared cell/bulk edit sheet body — P6-F4. Only the caller (cell sheet vs
/// bulk sheet) differs in how it wires [onSave]/[onReset]; the scope choice,
/// working toggle, segment list and error display are identical, which is
/// why [ScheduleEditController] backs both.
///
/// [weekdayLabel] is the human label for "every weekday" (e.g. "Даваа
/// гараг бүр"); `null` hides the weekday scope option entirely (the bulk
/// sheet, which only ever targets specific dates in this slice — see
/// `ScheduleGridController.rectangleBetween`'s doc comment).
class ScheduleEditSheetBody extends StatelessWidget {
  const ScheduleEditSheetBody({
    super.key,
    required this.branches,
    required this.onSave,
    this.onReset,
    this.weekdayLabel,
    this.dateScopeLabel = 'Зөвхөн энэ өдөр',
    this.title = 'Хуваарь засах',
  });

  final List<ScheduleBranch> branches;
  final Future<void> Function() onSave;
  final Future<void> Function()? onReset;
  final String? weekdayLabel;

  /// Label for the `date`-scope radio option — the cell sheet's default
  /// ("Зөвхөн энэ өдөр") reads correctly for a single cell; the bulk sheet
  /// passes "Зөвхөн сонгосон өдрүүдэд" (plural), parity with
  /// `schedule-grid.tsx`'s `BulkShiftEditor` scope radio copy.
  final String dateScopeLabel;
  final String title;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScheduleEditController>();
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.textStyles.h3),
            const SizedBox(height: 12),
            if (weekdayLabel != null) ...[
              Text('Хамрах хүрээ', style: context.textStyles.caption),
              const SizedBox(height: 6),
              _ScopeChoice(
                controller: controller,
                weekdayLabel: weekdayLabel!,
                dateScopeLabel: dateScopeLabel,
              ),
              const SizedBox(height: 12),
            ],
            SwitchListTile(
              key: const ValueKey('schedule_edit_working_switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Ажиллана'),
              value: controller.working,
              onChanged: controller.setWorking,
            ),
            if (controller.working) ...[
              const SizedBox(height: 4),
              for (var i = 0; i < controller.segments.length; i++)
                _SegmentRow(
                  key: ValueKey('schedule_edit_segment_$i'),
                  index: i,
                  segment: controller.segments[i],
                  branches: branches,
                  controller: controller,
                  removable: controller.segments.length > 1,
                ),
              TextButton.icon(
                key: const ValueKey('schedule_edit_add_segment'),
                onPressed: controller.addSegment,
                icon: const Icon(Icons.add),
                label: const Text('Цаг нэмэх'),
              ),
            ],
            if (controller.error != null) ...[
              const SizedBox(height: 8),
              Text(
                controller.error!.display,
                style: TextStyle(color: context.colors.danger),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 8,
              children: [
                if (onReset != null)
                  TextButton(
                    key: const ValueKey('schedule_edit_reset_button'),
                    onPressed: controller.submitting
                        ? null
                        : () => _confirmReset(context),
                    child: const Text('Үндсэн цаг'),
                  ),
                FilledButton(
                  key: const ValueKey('schedule_edit_save_button'),
                  onPressed: controller.submitting || !controller.segmentsValid
                      ? null
                      : () => onSave(),
                  child: controller.submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Хадгалах'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Үндсэн цагаар тохируулах уу?'),
        content: const Text(
          'Энэ өөрчлөлт (эсвэл тухайн гарагийн дүрэм) устаж, дараагийн '
          'дүрэм рүү буцна.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Цуцлах'),
          ),
          TextButton(
            key: const ValueKey('schedule_edit_reset_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Тийм'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onReset!();
  }
}

class _ScopeChoice extends StatelessWidget {
  const _ScopeChoice({
    required this.controller,
    required this.weekdayLabel,
    required this.dateScopeLabel,
  });
  final ScheduleEditController controller;
  final String weekdayLabel;
  final String dateScopeLabel;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      RadioListTile<ScheduleScope>(
        key: const ValueKey('schedule_edit_scope_date'),
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(dateScopeLabel),
        value: ScheduleScope.date,
        groupValue: controller.scope,
        onChanged: (v) => controller.setScope(v!),
      ),
      RadioListTile<ScheduleScope>(
        key: const ValueKey('schedule_edit_scope_weekday'),
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(weekdayLabel),
        value: ScheduleScope.weekday,
        groupValue: controller.scope,
        onChanged: (v) => controller.setScope(v!),
      ),
    ],
  );
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({
    super.key,
    required this.index,
    required this.segment,
    required this.branches,
    required this.controller,
    required this.removable,
  });

  final int index;
  final EditableSegment segment;
  final List<ScheduleBranch> branches;
  final ScheduleEditController controller;
  final bool removable;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('schedule_edit_branch_$index'),
                value: segment.branchId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Салбар'),
                items: [
                  for (final b in branches)
                    DropdownMenuItem(
                      value: b.id,
                      child: Text(
                        b.name ?? b.id,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) =>
                    controller.updateSegment(index, (s) => s..branchId = value),
              ),
            ),
            if (removable)
              IconButton(
                key: ValueKey('schedule_edit_remove_segment_$index'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => controller.removeSegment(index),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _TimeField(
                key: ValueKey('schedule_edit_start_$index'),
                label: 'Эхлэх',
                value: segment.startTime,
                onChanged: (value) => controller.updateSegment(
                  index,
                  (s) => s..startTime = value,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TimeField(
                key: ValueKey('schedule_edit_end_$index'),
                label: 'Дуусах',
                value: segment.endTime,
                onChanged: (value) =>
                    controller.updateSegment(index, (s) => s..endTime = value),
              ),
            ),
          ],
        ),
        if (!segment.isRangeValid)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Эхлэх цаг дуусах цагаас өмнө байх ёстой.',
              style: TextStyle(fontSize: 11, color: context.colors.danger),
            ),
          ),
      ],
    ),
  );
}

class _TimeField extends StatefulWidget {
  const _TimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<_TimeField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    decoration: InputDecoration(labelText: widget.label, hintText: 'HH:MM'),
    onChanged: widget.onChanged,
  );
}
