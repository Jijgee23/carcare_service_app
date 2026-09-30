import 'package:flutter/material.dart';

import 'package:carservice_business/app/theme/app_theme.dart';
import 'package:carservice_business/core/domain/user.dart';
import 'package:carservice_business/core/utils/async_value.dart';
import 'package:carservice_business/core/widgets/app_dropdown.dart';
import 'package:carservice_business/features/orders/domain/order.dart';
import 'package:carservice_business/features/orders/presentation/feature_theme.dart';
import 'package:carservice_business/features/orders/presentation/widgets/assignee_avatar.dart';
import 'package:carservice_business/features/orders/presentation/widgets/list/order_list_widgets.dart';

class OrderDetailSummaryCard extends StatelessWidget {
  const OrderDetailSummaryCard({
    super.key,
    required this.order,
    this.showNumber = true,
  });

  final ServiceOrderDetail order;

  /// Whether to render the "#number" heading. In embedded (side-pane) mode
  /// the number is already shown in the pane header, so the caller passes
  /// `false` here to avoid showing it twice.
  final bool showNumber;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showNumber) ...[
              Text(
                '#${order.number}',
                key: const ValueKey('order_detail_number'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
            ],
            _SummaryLine(
              icon: Icons.directions_car_outlined,
              text: '${order.vehicle.plate} — ${order.vehicle.displayName}',
            ),
            _SummaryLine(
              icon: Icons.person_outline,
              text: '${order.customer.displayName} · ${order.customer.phone}',
            ),
            _SummaryLine(
              icon: Icons.storefront_outlined,
              text: order.branch.name,
            ),
            if (order.notes?.trim().isNotEmpty == true)
              _SummaryLine(icon: Icons.notes_outlined, text: order.notes!),
          ],
        ),
      ),
    );
  }
}

/// "Төлөв" row: the order's current status, and — when the user may change
/// it — a tap opens a dropdown of the statuses it can move to next. The
/// current status heads the list, checked, for context.
class OrderStatusField extends StatelessWidget {
  const OrderStatusField({
    super.key,
    required this.current,
    required this.enabled,
    required this.onSelect,
  });

  final OrderStatus current;

  /// False without edit permission: the row still shows the status.
  final bool enabled;
  final ValueChanged<OrderStatus> onSelect;

  @override
  Widget build(BuildContext context) {
    final options = enabled ? current.nextStatuses : const <OrderStatus>[];
    return LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
        alignmentOffset: const Offset(0, 6),
        // Lets the min width below reach the panel; by default MenuAnchor
        // sizes the panel to its widest item.
        crossAxisUnconstrained: false,
        // As wide as the row, like a dropdown.
        style: AppDropdown.menuStyle(context, width: constraints.maxWidth),
        menuChildren: [
          _StatusMenuItem(status: current, selected: true),
          for (final status in options)
            _StatusMenuItem(
              key: ValueKey('order_status_${status.name}'),
              status: status,
              onPressed: () => onSelect(status),
            ),
        ],
        builder: (context, menu, _) => Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('order_status_menu'),
            onTap: options.isEmpty
                ? null
                : () => menu.isOpen ? menu.close() : menu.open(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Text('Төлөв', style: context.textStyles.h3),
                  const Spacer(),
                  OrderStatusChip(status: current),
                  if (options.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Icon(
                      menu.isOpen
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: context.opsTextSecondary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusMenuItem extends StatelessWidget {
  const _StatusMenuItem({
    super.key,
    required this.status,
    this.selected = false,
    this.onPressed,
  });

  final OrderStatus status;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = context.orderStatusColor(status);
    return MenuItemButton(
      onPressed: selected ? null : onPressed,
      style: MenuItemButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // The current status is informational, not greyed out.
        disabledForegroundColor: context.opsTextPrimary,
      ),
      leadingIcon: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      trailingIcon: selected
          ? Icon(Icons.check_rounded, size: 20, color: context.opsAccent)
          : null,
      child: Text(
        status.label,
        style: context.textStyles.bodyMedium.copyWith(
          fontWeight: selected ? FontWeight.w700 : null,
        ),
      ),
    );
  }
}

/// "Хариуцагч" row, styled like [OrderStatusField]: the order's assignee,
/// and — with `orders.assign` — a tap opens a menu of the branch's
/// assignable staff. The current assignee is checked.
class OrderAssignmentSection extends StatelessWidget {
  const OrderAssignmentSection({
    super.key,
    required this.order,
    required this.enabled,
    required this.state,
    required this.loading,
    required this.onChanged,
    this.error,
  });

  final ServiceOrderDetail order;

  /// False without assign permission: the row still shows the assignee.
  final bool enabled;
  final AsyncValue<List<AssignableUser>> state;
  final bool loading;
  final String? error;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final users = enabled
        ? state.valueOrNull ?? const <AssignableUser>[]
        : const <AssignableUser>[];
    final canOpen = users.isNotEmpty;
    final currentId = order.assignedTo?.id;
    final currentName = order.assignedTo?.fullName.trim();
    final hint = !enabled
        ? null
        : error ??
              (!loading && users.isEmpty ? 'Сонгох ажилтан олдсонгүй' : null);

    return LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
        alignmentOffset: const Offset(0, 6),
        // Lets the min width below reach the panel; by default MenuAnchor
        // sizes the panel to its widest item.
        crossAxisUnconstrained: false,
        // As wide as the row, like a dropdown; long rosters scroll.
        style: AppDropdown.menuStyle(
          context,
          width: constraints.maxWidth,
          maxHeight: 360,
        ),
        menuChildren: [
          _AssigneeMenuItem(
            key: const ValueKey('order_assignee_none'),
            name: null,
            selected: currentId == null,
            onPressed: () => onChanged(null),
          ),
          for (final user in users)
            _AssigneeMenuItem(
              key: ValueKey('order_assignee_${user.id}'),
              name: user.fullName,
              selected: user.id == currentId,
              onPressed: () => onChanged(user.id),
            ),
        ],
        builder: (context, menu, _) => Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: canOpen ? const ValueKey('order_assignment_picker') : null,
            onTap: canOpen
                ? () => menu.isOpen ? menu.close() : menu.open()
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('Хариуцагч', style: context.textStyles.h3),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _AssigneeChip(name: currentName),
                        ),
                      ),
                      if (enabled && loading) ...[
                        const SizedBox(width: 8),
                        SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.opsTextSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ] else if (canOpen) ...[
                        const SizedBox(width: 4),
                        Icon(
                          menu.isOpen
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: context.opsTextSecondary,
                        ),
                      ],
                    ],
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      hint,
                      key: error != null
                          ? const ValueKey('order_assignment_error')
                          : null,
                      textAlign: TextAlign.end,
                      style: context.textStyles.caption.copyWith(
                        color: error != null ? context.opsDanger : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar + name pill for the assignee row; `null` reads as unassigned.
class _AssigneeChip extends StatelessWidget {
  const _AssigneeChip({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final assigned = name?.isNotEmpty == true;
    final color = assigned ? context.opsAccent : context.opsTextSecondary;
    return Container(
      padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AssigneeAvatar(name: name, size: 22),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              assigned ? name! : 'Хариуцагчгүй',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.captionMedium.copyWith(
                color: assigned
                    ? context.opsTextPrimary
                    : context.opsTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssigneeMenuItem extends StatelessWidget {
  const _AssigneeMenuItem({
    super.key,
    required this.name,
    required this.selected,
    required this.onPressed,
  });

  /// `null` is the "no assignee" option.
  final String? name;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      onPressed: selected ? null : onPressed,
      style: MenuItemButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        // The current assignee is informational, not greyed out.
        disabledForegroundColor: context.opsTextPrimary,
        backgroundColor: selected ? context.opsAccent.withOpacity(.06) : null,
      ),
      leadingIcon: AssigneeAvatar(name: name, size: 32),
      trailingIcon: selected
          ? Icon(Icons.check_rounded, size: 20, color: context.opsAccent)
          : null,
      child: Text(
        name ?? 'Хариуцагчгүй',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textStyles.bodyMedium.copyWith(
          color: name == null ? context.opsTextSecondary : null,
          fontWeight: selected ? FontWeight.w700 : null,
        ),
      ),
    );
  }
}

class OrderScheduleSection extends StatelessWidget {
  const OrderScheduleSection({
    super.key,
    required this.order,
    required this.enabled,
    required this.onExpectedFinish,
    required this.onReschedule,
  });

  final ServiceOrderDetail order;
  final bool enabled;
  final VoidCallback onExpectedFinish;
  final VoidCallback onReschedule;

  @override
  Widget build(BuildContext context) {
    final format = MaterialLocalizations.of(context).formatMediumDate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Хуваарь', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (order.scheduledAt != null)
              Text('Товлосон: ${format(order.scheduledAt!)}'),
            if (order.expectedFinishAt != null)
              Text('Дуусах тооцоо: ${format(order.expectedFinishAt!)}'),
            if (enabled)
              Wrap(
                spacing: 8,
                children: [
                  if (order.status == OrderStatus.IN_PROGRESS)
                    TextButton.icon(
                      key: const ValueKey('order_expected_finish_button'),
                      onPressed: onExpectedFinish,
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Дуусах хугацаа'),
                    ),
                  if (order.status == OrderStatus.SCHEDULED)
                    TextButton.icon(
                      key: const ValueKey('order_reschedule_button'),
                      onPressed: onReschedule,
                      icon: const Icon(Icons.event_repeat_outlined),
                      label: const Text('Шилжүүлэх'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: context.opsTextSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
