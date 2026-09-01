import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/models/order.dart';
import 'package:carcare_service/features/presentation/controllers/controllers.dart';
import 'package:carcare_service/features/presentation/pages/orders/create_order_screen.dart';
import 'package:carcare_service/features/presentation/pages/orders/order_detail_screen.dart';
import 'package:carcare_service/features/presentation/pages/orders/order_filter_sheet.dart';
import 'package:carcare_service/shared/mixin/pagination_mixin.dart';
import 'package:carcare_service/shared/mixin/search_debounce_mixin.dart';
import 'package:carcare_service/shared/widgets/branch_filter_bar.dart';
import 'package:carcare_service/shared/widgets/common/common_widgets.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen>
    with PaginationMixin, SearchDebounceMixin {
  final _searchCtrl = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<OrderController>().loadOrders();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    initPagination(() => context.read<OrderController>().loadMore());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    onSearchChanged(v, (q) {
      if (mounted) context.read<OrderController>().setQuery(q.trim().toLowerCase());
    });
  }

  Future<void> _openFilter(OrderController provider) async {
    final result = await showOrderFilterSheet(context, provider.filter);
    if (result != null && mounted) provider.setFilter(result);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderController>();
    final filtered = provider.filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Захиалгууд'),
        // leading: IconButton(
        //   icon: const Icon(Icons.menu_rounded),
        //   onPressed: () => context.read<BottomNavController>().openMenu(),
        // ),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: provider.loadOrders)],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'order_list_fab',
        onPressed: () async {
          final created = await Navigator.push<ServiceOrderSummary>(
            context,
            MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
          );
          if (created != null && mounted) {
            provider.prependOrder(created);
          }
        },
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // ─── Search + filter row ──────────────────────────────────────
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearch,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Дугаар, машин, үйлчлүүлэгч...',
                        hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                        suffixIcon: provider.query.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  provider.setQuery('');
                                },
                                child: const Icon(Icons.close, color: Colors.white54, size: 18),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.12),
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                          borderSide: const BorderSide(color: Colors.white30),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _FilterButton(
                  count: provider.filter.activeCount,
                  onTap: () => _openFilter(provider),
                ),
              ],
            ),
          ),

          // ─── Branch filter (owner only) ───────────────────────────────
          BranchFilterBar(
            selectedBranchId: provider.selectedBranchId,
            onChanged: provider.setBranch,
          ),

          // ─── Active filter bar ────────────────────────────────────────
          ActiveFilterBar(filter: provider.filter, onClear: provider.clearFilter),

          // ─── Result count ─────────────────────────────────────────────
          if (provider.listState is AsyncData &&
              (provider.query.isNotEmpty || provider.filter.activeCount > 0))
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [Text('${filtered.length} захиалга', style: AppTextStyles.caption)],
              ),
            ),

          // ─── List ─────────────────────────────────────────────────────
          Expanded(
            child: switch (provider.listState) {
              AsyncLoading() => const Center(child: CircularProgressIndicator()),
              AsyncError(:final error) => _ListErrorView(
                message: error.display,
                onRetry: provider.loadOrders,
              ),
              AsyncData() =>
                filtered.isEmpty
                    ? EmptyState(
                        message: provider.query.isNotEmpty || provider.filter.activeCount > 0
                            ? 'Шүүлтэд тохирох захиалга байхгүй'
                            : 'Захиалга байхгүй байна',
                        icon: Icons.receipt_long_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: provider.loadOrders,
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(AppDimens.paddingMD),
                          itemCount: filtered.length + 1,
                          itemBuilder: (_, i) {
                            if (i == filtered.length) {
                              return _PaginationFooter(
                                loadingMore: provider.loadingMore,
                                hasNext: provider.hasNext,
                                total: provider.total,
                                label: 'захиалга',
                              );
                            }
                            final order = filtered[i];
                            return Padding(
                              key: ValueKey(order.id),
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _OrderCard(
                                order: order,
                                onTap: () async {
                                  final ctrl = context.read<OrderController>();
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChangeNotifierProvider.value(
                                        value: ctrl,
                                        child: OrderDetailScreen(orderId: order.id),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
            },
          ),
        ],
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ListErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ListErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(message, style: AppTextStyles.body, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Дахин оролдох'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter button with badge ─────────────────────────────────────────────────

class _FilterButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _FilterButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: count > 0 ? AppColors.accent : Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppDimens.radiusMD),
              border: count > 0 ? null : Border.all(color: Colors.white24),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 18,
              color: count > 0 ? Colors.white : Colors.white70,
            ),
          ),
          if (count > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Pagination footer ────────────────────────────────────────────────────────

class _PaginationFooter extends StatelessWidget {
  final bool loadingMore;
  final bool hasNext;
  final int total;
  final String label;
  const _PaginationFooter({
    required this.loadingMore,
    required this.hasNext,
    required this.total,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!hasNext && total > 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('Нийт $total $label ачааллагдлаа', style: AppTextStyles.caption)),
      );
    }
    return const SizedBox(height: 16);
  }
}

// ─── Order card ───────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final ServiceOrderSummary order;
  final VoidCallback onTap;
  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MM/dd HH:mm');
    final numFmt = NumberFormat('#,###');
    final locked = order.status.isLocked;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Locked top bar
          if (locked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: order.status == OrderStatus.COMPLETED
                    ? AppColors.goodBg
                    : AppColors.dangerBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimens.radiusMD)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 11,
                    color: order.status == OrderStatus.COMPLETED
                        ? AppColors.good
                        : AppColors.danger,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    order.status == OrderStatus.COMPLETED
                        ? 'Дууссан — засвар хийх боломжгүй'
                        : 'Цуцлагдсан — засвар хийх боломжгүй',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: order.status == OrderStatus.COMPLETED
                          ? AppColors.good
                          : AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),

          // Main content
          Opacity(
            opacity: locked ? 0.72 : 1.0,
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('#${order.number}', style: AppTextStyles.bodyMedium),
                      const SizedBox(width: 8),
                      _StatusChip(status: order.status),
                      const Spacer(),
                      _PaymentChip(status: order.paymentStatus),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.directions_car_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(order.vehicle.plate, style: AppTextStyles.captionMedium),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.vehicle.displayName,
                          style: AppTextStyles.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(order.customer.displayName, style: AppTextStyles.caption),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (order.totalAmount != null && order.totalAmount! > 0) ...[
                        const Icon(
                          Icons.monetization_on_outlined,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${numFmt.format(order.totalAmount!.toInt())}₮',
                          style: AppTextStyles.captionMedium.copyWith(color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 12),
                      ],
                      const Spacer(),
                      const Icon(Icons.access_time_outlined, size: 13, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        order.scheduledAt != null
                            ? fmt.format(order.scheduledAt!)
                            : fmt.format(order.createdAt),
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final OrderStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        border: Border.all(color: status.color.withOpacity(0.35)),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: status.color),
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final PaymentStatus status;
  const _PaymentChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        border: Border.all(color: status.color.withOpacity(0.35)),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: status.color),
      ),
    );
  }
}
