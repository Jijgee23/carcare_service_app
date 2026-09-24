import 'package:flutter/material.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/presentation/feature_theme.dart';

class OrderDetailSummaryCard extends StatelessWidget {
  const OrderDetailSummaryCard({
    super.key,
    required this.order,
    this.onDelete,
    this.showNumber = true,
  });

  final ServiceOrderDetail order;
  final VoidCallback? onDelete;

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
            if (showNumber || onDelete != null)
              Row(
                children: [
                  if (showNumber)
                    Expanded(
                      child: Text(
                        '#${order.number}',
                        key: const ValueKey('order_detail_number'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    )
                  else
                    const Spacer(),
                  if (onDelete != null)
                    IconButton(
                      key: const ValueKey('order_detail_delete'),
                      tooltip: 'Устгах',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
            if (showNumber || onDelete != null) const SizedBox(height: 8),
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

class OrderStatusActions extends StatelessWidget {
  const OrderStatusActions({
    super.key,
    required this.current,
    required this.enabled,
    required this.onSelect,
  });

  final OrderStatus current;
  final bool enabled;
  final ValueChanged<OrderStatus> onSelect;

  @override
  Widget build(BuildContext context) {
    final next = current.nextStatuses;
    if (!enabled || next.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Статус өөрчлөх',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in next)
                  // Tinted with the same per-status palette as the badges
                  // (feature_theme.dart orderStatusColor).
                  OutlinedButton(
                    key: ValueKey('order_status_${status.name}'),
                    onPressed: () => onSelect(status),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.orderStatusColor(status),
                      backgroundColor: context.orderStatusBackground(status),
                      side: BorderSide(
                        color: context
                            .orderStatusColor(status)
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(status.label),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
  final bool enabled;
  final AsyncValue<List<AssignableUser>> state;
  final bool loading;
  final String? error;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return _AssignmentSummary(order: order);
    }
    final users = state.valueOrNull ?? const <AssignableUser>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Хариуцагч', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (loading) const LinearProgressIndicator(minHeight: 2),
            if (error != null)
              Text(error!, key: const ValueKey('order_assignment_error')),
            if (!loading && users.isEmpty && error == null)
              const Text('Сонгох ажилтан олдсонгүй'),
            if (users.isNotEmpty)
              DropdownButtonFormField<String>(
                key: const ValueKey('order_assignment_picker'),
                value: users.any((user) => user.id == order.assignedTo?.id)
                    ? order.assignedTo?.id
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Ажилтан',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Хариуцагчгүй'),
                  ),
                  for (final user in users)
                    DropdownMenuItem<String>(
                      value: user.id,
                      child: Text(user.fullName),
                    ),
                ],
                onChanged: onChanged,
              ),
          ],
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

class _AssignmentSummary extends StatelessWidget {
  const _AssignmentSummary({required this.order});
  final ServiceOrderDetail order;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.engineering_outlined),
      title: const Text('Хариуцагч'),
      subtitle: Text(order.assignedTo?.fullName ?? 'Хариуцагчгүй'),
    ),
  );
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
