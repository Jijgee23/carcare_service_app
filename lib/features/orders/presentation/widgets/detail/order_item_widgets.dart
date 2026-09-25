import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/presentation/controllers/order_item_controller.dart';
import 'package:carcare_service/features/orders/presentation/feature_theme.dart';

class OrderItemCard extends StatelessWidget {
  const OrderItemCard({
    super.key,
    required this.item,
    required this.locked,
    required this.canEdit,
    required this.canPrice,
    required this.canStatus,
    required this.diagnosticEditable,
    this.onEdit,
    this.onCancel,
    this.onStatus,
    this.onDiagnosticCreate,
    this.onDiagnosticFill,
    this.onDiagnosticView,
  });

  final ServiceItem item;
  final bool locked;
  final bool canEdit;
  final bool canPrice;
  final bool canStatus;
  final bool diagnosticEditable;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final ValueChanged<ServiceItemStatus>? onStatus;
  final VoidCallback? onDiagnosticCreate;
  final VoidCallback? onDiagnosticFill;
  final VoidCallback? onDiagnosticView;

  String _money(Money? value, double fallback) =>
      '${value?.raw ?? fallback.toString()}₮';

  @override
  Widget build(BuildContext context) {
    final accent = context.itemKindColor(item.kind);
    final qty = item.quantityMoney?.raw ?? item.quantity.toString();
    final price = _money(item.unitPriceMoney, item.unitPrice);
    final total = _money(item.totalMoney, item.total);
    final actions = <Widget>[];
    if (!locked && (canEdit || canPrice)) {
      actions.add(
        IconButton(
          tooltip: 'Засах',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    if (!locked && canStatus && item.status != ServiceItemStatus.CANCELLED) {
      actions.add(
        PopupMenuButton<ServiceItemStatus>(
          tooltip: 'Төлөв',
          icon: const Icon(Icons.swap_vert_rounded, size: 19),
          onSelected: onStatus,
          itemBuilder: (_) => _nextStatuses(item).map((status) {
            return PopupMenuItem(
              value: status,
              child: Text(_statusLabel(status)),
            );
          }).toList(),
        ),
      );
    }
    if (!locked && canEdit && item.status != ServiceItemStatus.CANCELLED) {
      actions.add(
        IconButton(
          tooltip: 'Цуцлах',
          onPressed: onCancel,
          icon: const Icon(Icons.cancel_outlined, size: 18),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withOpacity(.12),
              borderRadius: BorderRadius.circular(AppDimens.radiusSM),
            ),
            child: Text(
              item.kind.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      item.description,
                      style: context.textStyles.captionMedium,
                    ),
                    _StatusBadge(status: item.status),
                  ],
                ),
                const SizedBox(height: 3),
                Text('$qty × $price', style: context.textStyles.caption),
                if (item.kind == ItemKind.DIAGNOSTIC) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (item.diagnosticReportId != null)
                        TextButton.icon(
                          onPressed: onDiagnosticView,
                          icon: const Icon(Icons.visibility_outlined, size: 15),
                          label: const Text('Тайлан үзэх'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                          ),
                        )
                      else if (diagnosticEditable &&
                          item.diagnosticTemplateId != null)
                        TextButton.icon(
                          onPressed: onDiagnosticFill,
                          icon: const Icon(Icons.playlist_add_check, size: 15),
                          label: const Text('Бөглөх'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                          ),
                        )
                      else if (diagnosticEditable)
                        TextButton.icon(
                          onPressed: onDiagnosticCreate,
                          icon: const Icon(Icons.add_task, size: 15),
                          label: const Text('Оношилгоо үүсгэх'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(total, style: context.textStyles.captionMedium),
              if (actions.isNotEmpty) Wrap(spacing: 0, children: actions),
            ],
          ),
        ],
      ),
    );
  }

  static List<ServiceItemStatus> _nextStatuses(ServiceItem item) {
    return switch (item.status) {
      ServiceItemStatus.PENDING => const [ServiceItemStatus.IN_PROGRESS],
      ServiceItemStatus.IN_PROGRESS => const [ServiceItemStatus.COMPLETED],
      // A finished line can be reopened; the API accepts any non-cancelled
      // target while the order is IN_PROGRESS and resets the timing fields.
      ServiceItemStatus.COMPLETED => const [
        ServiceItemStatus.IN_PROGRESS,
        ServiceItemStatus.PENDING,
      ],
      ServiceItemStatus.CANCELLED => const [],
    };
  }

  static String _statusLabel(ServiceItemStatus status) => switch (status) {
    ServiceItemStatus.PENDING => 'Хүлээгдэж буй',
    ServiceItemStatus.IN_PROGRESS => 'Хийгдэж байна',
    ServiceItemStatus.COMPLETED => 'Дууссан',
    ServiceItemStatus.CANCELLED => 'Цуцлагдсан',
  };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final ServiceItemStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ServiceItemStatus.COMPLETED => context.opsGood,
      ServiceItemStatus.CANCELLED => context.opsDanger,
      ServiceItemStatus.IN_PROGRESS => context.opsAccent,
      ServiceItemStatus.PENDING => context.opsTextSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
      ),
      child: Text(
        OrderItemCard._statusLabel(status),
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class OrderItemHistorySheet extends StatefulWidget {
  const OrderItemHistorySheet({super.key, required this.controller});
  final OrderItemController controller;

  @override
  State<OrderItemHistorySheet> createState() => _OrderItemHistorySheetState();
}

class _OrderItemHistorySheetState extends State<OrderItemHistorySheet> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<OrderItemController>().historyState;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: switch (state) {
          AsyncLoading() => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          ),
          AsyncError(:final error) => SizedBox(
            height: 180,
            child: Center(child: Text(error.display)),
          ),
          AsyncData(:final value) => _buildRows(context, value.items),
        },
      ),
    );
  }

  Widget _buildRows(BuildContext context, List<ServiceItem> items) {
    final controller = context.read<OrderItemController>();
    final date = DateFormat('yyyy-MM-dd HH:mm');
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.historyNextError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.historyNextError!,
                      style: TextStyle(color: context.opsDanger),
                    ),
                  ),
                  TextButton(
                    onPressed:
                        controller.isLoadingHistory ||
                            controller.isLoadingNextHistory
                        ? null
                        : () {
                            controller.loadNextHistory();
                          },
                    child: const Text('Дахин оролдох'),
                  ),
                ],
              ),
            ),
          if (items.isEmpty)
            const SizedBox(
              height: 140,
              child: Center(child: Text('Цуцлагдсан мөр байхгүй.')),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final item = items[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.description),
                    subtitle: Text(
                      '${item.kind.label} · ${item.cancelledAt == null ? '—' : date.format(item.cancelledAt!)}'
                      '${item.cancelledBy == null ? (item.cancelledById == null ? '' : ' · ${item.cancelledById}') : ' · ${item.cancelledBy!.fullName}'}\n'
                      'Тоо: ${item.quantityMoney?.raw ?? item.quantity} · '
                      'Нэгж: ${item.unitPriceMoney?.raw ?? item.unitPrice}₮ · '
                      'Нийт: ${item.totalMoney?.raw ?? item.total}₮',
                    ),
                    isThreeLine: true,
                    trailing:
                        controller.historyHasNext && index == items.length - 1
                        ? TextButton(
                            onPressed:
                                controller.isLoadingHistory ||
                                    controller.isLoadingNextHistory
                                ? null
                                : () {
                                    controller.loadNextHistory();
                                  },
                            child: const Text('Дараах'),
                          )
                        : null,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
