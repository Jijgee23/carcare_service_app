import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/presentation/feature_theme.dart';

List<ServiceItem> progressItems(Iterable<ServiceItem> items) => items
    .where(
      (item) =>
          item.kind != ItemKind.PART &&
          item.status != ServiceItemStatus.CANCELLED,
    )
    .toList(growable: false);

double progressFraction(Iterable<ServiceItem> items) {
  final active = progressItems(items);
  if (active.isEmpty) return 0;
  final completed = active
      .where((item) => item.status == ServiceItemStatus.COMPLETED)
      .length;
  return completed / active.length;
}

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: context.orderStatusBackground(status),
      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
      border: Border.all(
        color: context.orderStatusColor(status).withOpacity(.35),
      ),
    ),
    child: Text(
      status.label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: context.orderStatusColor(status),
      ),
    ),
  );
}

class OrderPaymentChip extends StatelessWidget {
  const OrderPaymentChip({super.key, required this.status});
  final PaymentStatus status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: context.paymentStatusBackground(status),
      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
      border: Border.all(
        color: context.paymentStatusColor(status).withOpacity(.35),
      ),
    ),
    child: Text(
      status.label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: context.paymentStatusColor(status),
      ),
    ),
  );
}

/// Renders the server-authoritative summary. It deliberately does not inspect
/// items or recalculate counts on the client.
class OrderProgressView extends StatelessWidget {
  const OrderProgressView({super.key, required this.progress});

  final OrderProgressSummary? progress;

  @override
  Widget build(BuildContext context) {
    if (progress == null) {
      return Text('Прогресс тодорхойгүй', style: context.textStyles.caption);
    }
    final total = progress!.total;
    final completed = progress!.completed;
    final fraction = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          total == 0 ? '0/0 · ажил бүртгэгдээгүй' : '$completed/$total дууссан',
          style: context.textStyles.caption,
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: fraction),
      ],
    );
  }
}

class OrderPhoneCard extends StatelessWidget {
  const OrderPhoneCard({
    super.key,
    required this.order,
    required this.selected,
    required this.onTap,
    required this.onSelect,
  });
  final ServiceOrderSummary order;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MM/dd HH:mm');
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.paddingMD),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                onChanged: (value) => onSelect(value ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '#${order.number}',
                            style: context.textStyles.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: OrderStatusChip(status: order.status),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: OrderPaymentChip(status: order.paymentStatus),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${order.vehicle.plate} · ${order.vehicle.displayName}',
                      style: context.textStyles.captionMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      order.customer.displayName,
                      style: context.textStyles.caption,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 13,
                          color: context.opsTextHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order.scheduledAt == null
                              ? '—'
                              : fmt.format(order.scheduledAt!),
                          style: context.textStyles.caption.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const Spacer(),
                        if (order.totalAmount != null)
                          Text(
                            '${NumberFormat('#,###').format(order.totalAmount!.toInt())}₮',
                            style: context.textStyles.captionMedium.copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BulkSelectionBar extends StatelessWidget {
  const BulkSelectionBar({
    super.key,
    required this.count,
    required this.onClear,
    required this.onStatus,
    required this.onAssign,
    required this.canChangeStatus,
    required this.canAssign,
    this.assignableUsers = const [],
    this.loadingAssignableUsers = false,
    this.assignableUsersError,
  });
  final int count;
  final VoidCallback onClear;
  final ValueChanged<OrderStatus> onStatus;
  final ValueChanged<String?> onAssign;
  final bool canChangeStatus;
  final bool canAssign;
  final List<AssignableUser> assignableUsers;
  final bool loadingAssignableUsers;
  final String? assignableUsersError;

  @override
  Widget build(BuildContext context) => Material(
    color: context.opsSurface,
    elevation: 4,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Text('$count сонгосон', style: context.textStyles.bodyMedium),
            const Spacer(),
            if (canChangeStatus)
              PopupMenuButton<OrderStatus>(
                key: const ValueKey('bulk_status_button'),
                tooltip: 'Төлөв өөрчлөх',
                icon: const Icon(Icons.sync_alt),
                onSelected: onStatus,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: OrderStatus.SCHEDULED,
                    child: Text('Товлосон'),
                  ),
                  PopupMenuItem(
                    value: OrderStatus.IN_PROGRESS,
                    child: Text('Хийгдэж байна'),
                  ),
                  PopupMenuItem(
                    value: OrderStatus.COMPLETED,
                    child: Text('Дууссан'),
                  ),
                  PopupMenuItem(
                    value: OrderStatus.CANCELLED,
                    child: Text('Цуцлагдсан'),
                  ),
                ],
              ),
            if (canAssign)
              if (loadingAssignableUsers)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (assignableUsersError != null)
                Tooltip(
                  message: assignableUsersError!,
                  child: const Icon(
                    Icons.error_outline,
                    key: ValueKey('bulk_assign_error'),
                  ),
                )
              else
                PopupMenuButton<String>(
                  key: const ValueKey('bulk_assign_button'),
                  tooltip: 'Хариуцагч сонгох',
                  icon: const Icon(Icons.person_outline),
                  onSelected: (value) => onAssign(value.isEmpty ? null : value),
                  itemBuilder: (_) => [
                    const PopupMenuItem<String>(
                      value: '',
                      child: Text('Хариуцагчгүй болгох'),
                    ),
                    ...assignableUsers.map(
                      (user) => PopupMenuItem<String>(
                        value: user.id,
                        child: Text(user.fullName),
                      ),
                    ),
                  ],
                ),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close),
              tooltip: 'Сонголт цэвэрлэх',
            ),
          ],
        ),
      ),
    ),
  );
}
