import 'package:carcare_service/core/widgets/filter_pill.dart';
import 'package:carcare_service/core/widgets/adaptive/tight_height_fallback.dart';
import 'dart:async';

import 'package:carcare_service/features/orders/presentation/widgets/order_status_prompt.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:intl/intl.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/widgets/adaptive/breakpoints.dart';
import 'package:carcare_service/core/widgets/adaptive/record_views.dart';
import 'package:carcare_service/core/widgets/branch_filter_bar.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/domain/orders_repository.dart';
import 'package:carcare_service/features/orders/presentation/controllers/order_controller.dart';
import 'package:carcare_service/features/orders/presentation/feature_theme.dart';
import 'package:carcare_service/features/orders/presentation/screens/create_order_screen.dart';
import 'package:carcare_service/features/orders/presentation/screens/order_filter_sheet.dart';
import 'package:carcare_service/features/orders/presentation/widgets/list/order_list_widgets.dart';
import 'package:carcare_service/features/shell/presentation/controllers/working_branch_controller.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key, this.user});

  final User? user;

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  WorkingBranchController? _workingBranchController;
  bool _didLoad = false;

  /// Client-side sort over the loaded page only (`TENANT_UI_UX_PLAN.md`
  /// Phase 5's all-orders table). The orders API has no ordering parameter
  /// — see `OrderFilter.sortBy` — so this never claims to sort beyond what
  /// is already on screen; paging in more rows resets it to arrival order.
  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WorkingBranchController? nextWorkingBranchController;
    try {
      nextWorkingBranchController = context.read<WorkingBranchController>();
    } on ProviderNotFoundException {
      // Standalone list tests and embeds do not provide a working-branch
      // controller; the legacy branch filter remains available there.
    }
    if (nextWorkingBranchController != _workingBranchController) {
      _workingBranchController?.removeListener(_onWorkingBranchChanged);
      _workingBranchController = nextWorkingBranchController;
      _workingBranchController?.addListener(_onWorkingBranchChanged);
    }
    _onWorkingBranchChanged();
    if (!_didLoad) {
      _didLoad = true;
      final controller = context.read<OrderController>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.loadOrders();
      });
      _scrollController.addListener(() {
        if (_scrollController.position.extentAfter < 500 && mounted) {
          context.read<OrderController>().loadMore();
        }
      });
    }
  }

  @override
  void dispose() {
    _workingBranchController?.removeListener(_onWorkingBranchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onWorkingBranchChanged() {
    final workingBranchController = _workingBranchController;
    if (!mounted ||
        workingBranchController == null ||
        workingBranchController.isAllBranches) {
      return;
    }
    unawaited(context.read<OrderController>().clearLegacyBranchCriteria());
  }

  bool _canView(User? user) =>
      user?.isOwner == true ||
      user?.role?.permissions.contains('orders.view') == true ||
      user?.role?.permissions.contains('orders.viewOwn') == true;

  bool _canEdit(User? user) =>
      user?.isOwner == true ||
      user?.role?.permissions.contains('orders.edit') == true ||
      user?.role?.permissions.contains('orders.editOwn') == true;

  bool _canCreate(User? user) =>
      user?.isOwner == true ||
      user?.role?.permissions.contains('orders.create') == true;

  bool _canAssign(User? user) =>
      user?.isOwner == true ||
      user?.role?.permissions.contains('orders.assign') == true;

  Future<void> _toggleSelection(
    OrderController controller,
    String orderId,
    User? user,
  ) async {
    controller.toggleSelection(orderId);
    if (_canAssign(user) && controller.selectedCount > 0) {
      await controller.loadAssignableUsers();
    }
  }

  Future<void> _changeBulkStatus(
    OrderController controller,
    OrderStatus status,
  ) async {
    int? durationMinutes;
    if (status == OrderStatus.IN_PROGRESS) {
      final decision = await promptOrderStatusChange(context, status);
      if (!mounted || decision == null) return;
      durationMinutes = decision.durationMinutes;
    }
    await controller.bulkChangeStatus(status, durationMinutes: durationMinutes);
  }

  Future<void> _openFilters(OrderController controller) async {
    await controller.loadAssignableUsers();
    if (!mounted) return;
    final users =
        controller.assignableUsersState.valueOrNull ?? const <AssignableUser>[];
    final filter = await showOrderFilterSheet(
      context,
      controller.filter,
      assignableUsers: users,
    );
    if (filter != null && mounted) controller.setFilter(filter);
  }

  Future<void> _openOrder(
    OrderController controller,
    ServiceOrderSummary order,
  ) async {
    await context.push('/orders/${Uri.encodeComponent(order.id)}');
    if (mounted) await controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OrderController>();
    final user = widget.user ?? Authenticator.user;
    if (!_canView(user)) {
      return const Scaffold(body: Center(child: Text('Захиалга харах эрхгүй')));
    }

    final state = controller.listState;
    return Scaffold(
      backgroundColor: context.opsBackground,
      appBar: AppBar(
        title: const Text('Захиалгууд'),
        actions: [
          IconButton(
            key: const ValueKey('orders_in_progress_nav'),
            tooltip: 'Хийгдэж буй ажил',
            onPressed: () => context.push('/orders/in-progress'),
            icon: const Icon(Icons.build_circle_outlined),
          ),
          IconButton(
            key: const ValueKey('orders_postpaid_nav'),
            tooltip: 'Дараа төлөх захиалга',
            onPressed: () => context.push('/orders/postpaid'),
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
          IconButton(
            tooltip: 'Шинэчлэх',
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _canCreate(user)
          ? FloatingActionButton(
              key: const ValueKey('order_create_fab'),
              heroTag: 'order_list_fab',
              backgroundColor: context.opsAccent,
              onPressed: () async {
                final created = await Navigator.push<ServiceOrderSummary>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateOrderScreen(
                      repository: context.read<OrdersRepository>(),
                    ),
                  ),
                );
                if (created == null || !mounted) return;
                unawaited(controller.refresh());
                // Land on the new order with Today underneath, so back from
                // the detail returns to Today rather than this list.
                final router = GoRouter.of(context);
                router.go('/overview');
                await WidgetsBinding.instance.endOfFrame;
                unawaited(
                  router.push('/orders/${Uri.encodeComponent(created.id)}'),
                );
              },
              child: Icon(Icons.add, color: context.opsTextOnDark),
            )
          : null,
      bottomNavigationBar:
          controller.selectedCount == 0 ||
              (!_canEdit(user) && !_canAssign(user))
          ? null
          : BulkSelectionBar(
              count: controller.selectedCount,
              onClear: controller.clearVisibleSelection,
              canChangeStatus: _canEdit(user),
              canAssign: _canAssign(user),
              assignableUsers:
                  controller.assignableUsersState.valueOrNull ??
                  const <AssignableUser>[],
              loadingAssignableUsers: controller.loadingAssignableUsers,
              assignableUsersError: controller.assignableUsersError,
              onStatus: (status) => _changeBulkStatus(controller, status),
              onAssign: (id) => controller.bulkAssign(id),
            ),
      body: TightHeightFallback(
        controls: [
          _SearchBar(
            controller: _searchController,
            onChanged: controller.setQuery,
            onFilter: () => _openFilters(controller),
            onClear: () {
              _searchController.clear();
              controller.setQuery('');
            },
          ),
          if (_showLegacyBranchFilter(context))
            BranchFilterBar(
              selectedBranchId: controller.selectedBranchId,
              onChanged: controller.setBranch,
            ),
          if (MediaQuery.sizeOf(context).width >= AdaptiveBreakpoints.expanded)
            _QuickFilterChips(
              filter: controller.filter,
              myUserId: (widget.user ?? Authenticator.user)?.id,
              onChanged: controller.setFilter,
              // Tablet table only: sits inline at the end of the chip row.
              trailing: state is AsyncData<List<ServiceOrderSummary>> &&
                      state.value.isNotEmpty
                  ? TextButton.icon(
                      onPressed: () {
                        controller.selectVisiblePage();
                        if (_canAssign(widget.user ?? Authenticator.user)) {
                          controller.loadAssignableUsers();
                        }
                      },
                      icon: const Icon(Icons.select_all),
                      label: const Text('Энэ хуудсыг сонгох'),
                    )
                  : null,
            ),
          ActiveFilterBar(
            filter: controller.filter,
            onClear: controller.clearFilter,
          ),
          if (controller.bulkResult?.failed.isNotEmpty == true)
            _BulkFailureBanner(result: controller.bulkResult!),
        ],
        results: _buildResults(controller, state),
      ),
    );
  }

  bool _showLegacyBranchFilter(BuildContext context) {
    // The header's working-branch controller is the authoritative scope. The
    // legacy owner-only query filter is only meaningful while that scope is
    // explicitly ALL; showing it for a selected branch would label a
    // branch-scoped list as if it could widen its server scope.
    try {
      return context.watch<WorkingBranchController>().isAllBranches;
    } on ProviderNotFoundException {
      // Standalone tests and legacy embeddings have no working-branch
      // provider. Preserve their existing owner-only filter in that case.
      return true;
    }
  }

  Widget _buildResults(
    OrderController controller,
    AsyncValue<List<ServiceOrderSummary>> state,
  ) {
    return switch (state) {
      AsyncLoading() => const Center(child: CircularProgressIndicator()),
      AsyncError(:final error) => _ErrorView(
        message: error.display,
        retry: controller.refresh,
      ),
      AsyncData(:final value) when value.isEmpty => Center(
        child: Text(
          controller.query.isNotEmpty || controller.filter.activeCount > 0
              ? 'Шүүлтэд тохирох захиалга байхгүй'
              : 'Захиалга байхгүй байна',
        ),
      ),
      AsyncData(:final value) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= AdaptiveBreakpoints.expanded;
          if (!wide) {
            return _PhoneOrders(
              controller: controller,
              orders: value,
              open: _openOrder,
              scroll: _scrollController,
              select: (id) => _toggleSelection(
                controller,
                id,
                widget.user ?? Authenticator.user,
              ),
            );
          }
          final table = _TabletOrderList(
            controller: controller,
            orders: _sortedOrders(value),
            open: _openOrder,
            select: (id) => _toggleSelection(
              controller,
              id,
              widget.user ?? Authenticator.user,
            ),
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            onSort: _onSort,
          );
          if (constraints.maxWidth < AdaptiveBreakpoints.extendedRail) {
            return table;
          }
          // ≥1200dp: a persistent filter panel replaces the filter sheet
          // (`TENANT_UI_UX_PLAN.md` Phase 5). It applies every edit
          // immediately since it is always visible, unlike the sheet.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OrderFilterPanel(
                filter: controller.filter,
                onChanged: controller.setFilter,
                onClear: controller.clearFilter,
                assignableUsers:
                    controller.assignableUsersState.valueOrNull ??
                    const <AssignableUser>[],
              ),
              Expanded(child: table),
            ],
          );
        },
      ),
    };
  }

  /// Column indexes here must stay in the same order as `_TabletOrderList`'s
  /// [RecordColumn]s (index 0 is the selection checkbox and is never
  /// sortable).
  List<ServiceOrderSummary> _sortedOrders(List<ServiceOrderSummary> orders) {
    final column = _sortColumnIndex;
    if (column == null) return orders;
    int Function(ServiceOrderSummary, ServiceOrderSummary) cmp = switch (column) {
      1 => (a, b) => a.vehicle.plate.compareTo(b.vehicle.plate),
      2 => (a, b) => a.customer.displayName.compareTo(b.customer.displayName),
      3 => (a, b) => a.status.index.compareTo(b.status.index),
      4 => (a, b) => a.paymentStatus.index.compareTo(b.paymentStatus.index),
      5 => (a, b) => (a.assignedTo?.fullName ?? '').compareTo(
        b.assignedTo?.fullName ?? '',
      ),
      6 => (a, b) => (a.scheduledAt ?? a.createdAt).compareTo(
        b.scheduledAt ?? b.createdAt,
      ),
      7 => (a, b) => (a.totalAmount ?? -1).compareTo(b.totalAmount ?? -1),
      _ => (a, b) => 0,
    };
    final sorted = [...orders]..sort(cmp);
    if (!_sortAscending) return sorted.reversed.toList(growable: false);
    return sorted;
  }

  void _onSort(int columnIndex) {
    if (columnIndex == 0) return; // the checkbox column is not sortable.
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onFilter,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
    color: context.opsPrimary,
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: TextStyle(color: context.opsTextOnDark),
            decoration: InputDecoration(
              hintText: 'Дугаар, машин, үйлчлүүлэгч...',
              prefixIcon: Icon(
                Icons.search,
                color: context.opsTextOnDark.withOpacity(.6),
              ),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Цэвэрлэх',
                      onPressed: onClear,
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: context.opsTextOnDark.withOpacity(.12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Шүүлтүүр',
          onPressed: onFilter,
          icon: const Icon(Icons.tune),
          color: context.opsTextOnDark,
        ),
      ],
    ),
  );
}

/// Saved quick filters (`TENANT_UI_UX_PLAN.md` Phase 5), shown as a
/// persistent tablet chip row. Each chip toggles one field of [OrderFilter];
/// toggling one on preserves whatever else is already active (they combine),
/// toggling it off clears only that field. Only filters the server query can
/// already express are offered here — "Миний" needs a signed-in user id.
enum _QuickFilter { today, open, unpaid, mine }

class _QuickFilterChips extends StatelessWidget {
  const _QuickFilterChips({
    required this.filter,
    required this.myUserId,
    required this.onChanged,
    this.trailing,
  });

  final OrderFilter filter;
  final String? myUserId;
  final ValueChanged<OrderFilter> onChanged;
  final Widget? trailing;

  static const _openStatuses = {OrderStatus.SCHEDULED, OrderStatus.IN_PROGRESS};

  bool _active(_QuickFilter qf) => switch (qf) {
    _QuickFilter.today => filter.datePreset == DatePreset.today,
    _QuickFilter.open =>
      filter.statuses.isNotEmpty && filter.statuses.containsAll(_openStatuses) &&
          filter.statuses.length == _openStatuses.length,
    _QuickFilter.unpaid =>
      filter.paymentStatuses.length == 1 &&
          filter.paymentStatuses.contains(PaymentStatus.UNPAID),
    _QuickFilter.mine => myUserId != null && filter.assignedToId == myUserId,
  };

  void _toggle(_QuickFilter qf) {
    final active = _active(qf);
    final next = switch (qf) {
      _QuickFilter.today => OrderFilter(
        statuses: filter.statuses,
        paymentStatuses: filter.paymentStatuses,
        datePreset: active ? DatePreset.all : DatePreset.today,
        assignedToId: filter.assignedToId,
        plate: filter.plate,
        postpaid: filter.postpaid,
      ),
      _QuickFilter.open => OrderFilter(
        statuses: active ? const {} : _openStatuses,
        paymentStatuses: filter.paymentStatuses,
        datePreset: filter.datePreset,
        assignedToId: filter.assignedToId,
        dateFrom: filter.dateFrom,
        dateTo: filter.dateTo,
        plate: filter.plate,
        postpaid: filter.postpaid,
      ),
      _QuickFilter.unpaid => OrderFilter(
        statuses: filter.statuses,
        paymentStatuses: active ? const {} : const {PaymentStatus.UNPAID},
        datePreset: filter.datePreset,
        assignedToId: filter.assignedToId,
        dateFrom: filter.dateFrom,
        dateTo: filter.dateTo,
        plate: filter.plate,
        postpaid: filter.postpaid,
      ),
      _QuickFilter.mine => OrderFilter(
        statuses: filter.statuses,
        paymentStatuses: filter.paymentStatuses,
        datePreset: filter.datePreset,
        assignedToId: active ? null : myUserId,
        dateFrom: filter.dateFrom,
        dateTo: filter.dateTo,
        plate: filter.plate,
        postpaid: filter.postpaid,
      ),
    };
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    // This row spans the same width as the results area, so it mirrors the
    // results' own table-vs-cards breakpoint: the select-page action only
    // shows while the tablet table (with its checkboxes) is what's rendered.
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: Row(
          children: [
            Expanded(child: _chips(context)),
            if (constraints.maxWidth >= AdaptiveBreakpoints.expanded) ?trailing,
          ],
        ),
      ),
    );
  }

  Widget _chips(BuildContext context) {
    return Wrap(
        spacing: 8,
        runSpacing: 0,
        children: [
          _chip(context, 'Өнөөдөр', _QuickFilter.today, key: 'orders_quick_filter_today'),
          _chip(context, 'Нээлттэй', _QuickFilter.open, key: 'orders_quick_filter_open'),
          _chip(
            context,
            'Төлбөр дутуу',
            _QuickFilter.unpaid,
            key: 'orders_quick_filter_unpaid',
          ),
          if (myUserId != null)
            _chip(context, 'Миний', _QuickFilter.mine, key: 'orders_quick_filter_mine'),
        ],
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    _QuickFilter qf, {
    required String key,
  }) {
    return FilterPill(
      key: ValueKey(key),
      label: label,
      selected: _active(qf),
      onTap: () => _toggle(qf),
    );
  }
}

class _PhoneOrders extends StatelessWidget {
  const _PhoneOrders({
    required this.controller,
    required this.orders,
    required this.open,
    required this.scroll,
    required this.select,
  });
  final OrderController controller;
  final List<ServiceOrderSummary> orders;
  final Future<void> Function(OrderController, ServiceOrderSummary) open;
  final ScrollController scroll;
  final ValueChanged<String> select;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: controller.refresh,
    child: ListView.separated(
      controller: scroll,
      padding: const EdgeInsets.all(AppDimens.paddingMD),
      itemCount: orders.length + 1,
      separatorBuilder: (_, index) =>
          SizedBox(height: index == orders.length - 1 ? 4 : 10),
      itemBuilder: (_, index) {
        if (index == orders.length) return _ListFooter(controller: controller);
        final order = orders[index];
        return OrderPhoneCard(
          order: order,
          selected: controller.isSelected(order.id),
          onTap: () => open(controller, order),
          onSelect: (_) => select(order.id),
        );
      },
    ),
  );
}

/// The tablet/pane list column, now a real sortable table
/// (`TENANT_UI_UX_PLAN.md` Phase 5) backed by [DataTableView]. Used both
/// stand-alone (list only) and at [AdaptiveBreakpoints.expanded] and wider —
/// [DataTableView.forceTable] is set because this slot can render inside a
/// column narrower than the phone/tablet threshold even though the screen
/// overall is tablet width.
class _TabletOrderList extends StatelessWidget {
  const _TabletOrderList({
    required this.controller,
    required this.orders,
    required this.open,
    required this.select,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
  });
  final OrderController controller;
  final List<ServiceOrderSummary> orders;
  final Future<void> Function(OrderController, ServiceOrderSummary) open;
  final ValueChanged<String> select;
  final int? sortColumnIndex;
  final bool sortAscending;
  final ValueChanged<int> onSort;

  static final _dateFmt = DateFormat('MM/dd HH:mm');
  static final _moneyFmt = NumberFormat('#,###');

  List<RecordColumn<ServiceOrderSummary>> _columns(BuildContext context) => [
    RecordColumn<ServiceOrderSummary>(
      label: '',
      flex: 1,
      builder: (context, order) => Semantics(
        label: controller.isSelected(order.id) ? 'Сонгогдсон' : 'Сонгох',
        child: Checkbox(
          value: controller.isSelected(order.id),
          onChanged: (_) => select(order.id),
        ),
      ),
    ),
    RecordColumn<ServiceOrderSummary>(
      label: 'Дугаар',
      flex: 3,
      builder: (context, order) => Text(
        order.vehicle.plate,
        overflow: TextOverflow.ellipsis,
        style: context.textStyles.bodyMedium,
      ),
    ),
    RecordColumn<ServiceOrderSummary>(
      label: 'Үйлчлүүлэгч',
      flex: 4,
      builder: (context, order) => Text(
        order.customer.displayName,
        overflow: TextOverflow.ellipsis,
        style: context.textStyles.caption,
      ),
    ),
    RecordColumn<ServiceOrderSummary>(
      label: 'Статус',
      flex: 3,
      builder: (context, order) => OrderStatusChip(status: order.status),
    ),
    RecordColumn<ServiceOrderSummary>(
      label: 'Төлбөр',
      flex: 3,
      builder: (context, order) => OrderPaymentChip(status: order.paymentStatus),
    ),
    RecordColumn<ServiceOrderSummary>(
      label: 'Хариуцагч',
      flex: 3,
      builder: (context, order) => Text(
        order.assignedTo?.fullName ?? 'Хуваарилаагүй',
        overflow: TextOverflow.ellipsis,
        style: context.textStyles.caption.copyWith(
          color: order.assignedTo == null ? context.opsTextHint : null,
        ),
      ),
    ),
    RecordColumn<ServiceOrderSummary>(
      label: 'Огноо',
      flex: 3,
      builder: (context, order) => Text(
        _dateFmt.format((order.scheduledAt ?? order.createdAt).toLocal()),
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      ),
    ),
    RecordColumn<ServiceOrderSummary>(
      label: 'Дүн',
      flex: 2,
      numeric: true,
      builder: (context, order) => Text(
        order.totalAmount == null
            ? '—'
            : '${_moneyFmt.format(order.totalAmount!.toInt())}₮',
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: controller.refresh,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Expanded(
          child: DataTableView<ServiceOrderSummary>(
            forceTable: true,
            records: orders,
            columns: _columns(context),
            sortColumnIndex: sortColumnIndex,
            sortAscending: sortAscending,
            onSort: onSort,
            onTap: (order) => open(controller, order),
          ),
        ),
        _ListFooter(controller: controller),
      ],
    ),
  );
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});
  final OrderController controller;
  @override
  Widget build(BuildContext context) {
    if (controller.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (controller.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton.icon(
          onPressed: controller.loadMore,
          icon: const Icon(Icons.refresh),
          label: Text('Дахин оролдох: ${controller.loadMoreError!.display}'),
        ),
      );
    }
    if (controller.hasNext) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton.icon(
          onPressed: controller.loadMore,
          icon: const Icon(Icons.expand_more),
          label: const Text('Дараагийн хуудас'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          'Нийт ${controller.total} захиалга',
          style: context.textStyles.caption,
        ),
      ),
    );
  }
}

class _BulkFailureBanner extends StatelessWidget {
  const _BulkFailureBanner({required this.result});
  final BulkOrderResult result;
  @override
  Widget build(BuildContext context) => MaterialBanner(
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Зарим мөрийн үйлдэл амжилтгүй болсон'),
        for (final failure in result.failed)
          Text('${failure.orderId}: ${failure.code} — ${failure.message}'),
      ],
    ),
    leading: Icon(Icons.warning_amber_rounded, color: context.opsWarning),
    actions: const [SizedBox.shrink()],
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Дахин оролдох'),
        ),
      ],
    ),
  );
}
