import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/widgets/branch_filter_bar.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/domain/orders_repository.dart';
import 'package:carcare_service/features/orders/presentation/controllers/order_controller.dart';
import 'package:carcare_service/features/orders/presentation/controllers/order_detail_controller.dart';
import 'package:carcare_service/features/orders/presentation/feature_theme.dart';
import 'package:carcare_service/features/orders/presentation/screens/create_order_screen.dart';
import 'package:carcare_service/features/orders/presentation/screens/order_detail_screen.dart';
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
  String? _selectedOrderId;

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
      var input = '60';
      final value = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ажлын үргэлжлэх хугацаа'),
          content: TextFormField(
            initialValue: input,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Минут'),
            onChanged: (value) => input = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Болих'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = int.tryParse(input.trim());
                if (parsed != null && parsed > 0) {
                  Navigator.pop(dialogContext, parsed);
                }
              },
              child: const Text('Үргэлжлүүлэх'),
            ),
          ],
        ),
      );
      if (!mounted || value == null) return;
      durationMinutes = value;
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
    if (MediaQuery.sizeOf(context).width >= 700) {
      setState(() => _selectedOrderId = order.id);
      return;
    }
    await _openPhoneOrder(controller, order);
  }

  Future<void> _openPhoneOrder(
    OrderController controller,
    ServiceOrderSummary order,
  ) async {
    await context.push('/orders/${Uri.encodeComponent(order.id)}');
    if (mounted) await controller.refresh();
  }

  Widget _buildEmbeddedDetail(OrderController listController) {
    final id = _selectedOrderId;
    if (id == null) return _SelectionPane(controller: listController);
    return ChangeNotifierProvider(
      key: ValueKey('order-detail-pane-$id'),
      create: (context) => OrderDetailController(
        repo: context.read<OrdersRepository>(),
        listController: listController,
        branchController: _workingBranchController,
      ),
      child: OrderDetailScreen(
        orderId: id,
        embedded: true,
        user: widget.user ?? Authenticator.user,
      ),
    );
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
                if (created != null && mounted) await controller.refresh();
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
      body: Column(
        children: [
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
          ActiveFilterBar(
            filter: controller.filter,
            onClear: controller.clearFilter,
          ),
          if (controller.bulkResult?.failed.isNotEmpty == true)
            _BulkFailureBanner(result: controller.bulkResult!),
          Expanded(child: _buildResults(controller, state)),
        ],
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
        builder: (context, constraints) => constraints.maxWidth >= 700
            ? _TabletOrders(
                controller: controller,
                orders: value,
                open: _openOrder,
                selectedOrderId: _selectedOrderId,
                detail: _buildEmbeddedDetail(controller),
                select: (id) => _toggleSelection(
                  controller,
                  id,
                  widget.user ?? Authenticator.user,
                ),
                selectAll: () {
                  controller.selectVisiblePage();
                  if (_canAssign(widget.user ?? Authenticator.user)) {
                    controller.loadAssignableUsers();
                  }
                },
              )
            : _PhoneOrders(
                controller: controller,
                orders: value,
                open: _openPhoneOrder,
                scroll: _scrollController,
                select: (id) => _toggleSelection(
                  controller,
                  id,
                  widget.user ?? Authenticator.user,
                ),
              ),
      ),
    };
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
          onPressed: onFilter,
          icon: const Icon(Icons.tune),
          color: context.opsTextOnDark,
        ),
      ],
    ),
  );
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

class _TabletOrders extends StatelessWidget {
  const _TabletOrders({
    required this.controller,
    required this.orders,
    required this.open,
    required this.selectedOrderId,
    required this.detail,
    required this.select,
    required this.selectAll,
  });
  final OrderController controller;
  final List<ServiceOrderSummary> orders;
  final Future<void> Function(OrderController, ServiceOrderSummary) open;
  final String? selectedOrderId;
  final Widget detail;
  final ValueChanged<String> select;
  final VoidCallback selectAll;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        flex: 3,
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(AppDimens.paddingMD),
            itemCount: orders.length + 2,
            itemBuilder: (_, index) {
              if (index == 0) {
                return Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: selectAll,
                    icon: const Icon(Icons.select_all),
                    label: const Text('Энэ хуудсыг сонгох'),
                  ),
                );
              }
              if (index == orders.length + 1) {
                return _ListFooter(controller: controller);
              }
              final order = orders[index - 1];
              return DecoratedBox(
                decoration: BoxDecoration(
                  border: order.id == selectedOrderId
                      ? Border.all(color: Theme.of(context).colorScheme.primary)
                      : null,
                ),
                child: OrderTableRow(
                  order: order,
                  selected: controller.isSelected(order.id),
                  onTap: () => open(controller, order),
                  onSelect: (_) => select(order.id),
                ),
              );
            },
          ),
        ),
      ),
      const VerticalDivider(width: 1),
      Expanded(flex: 2, child: detail),
    ],
  );
}

class _SelectionPane extends StatelessWidget {
  const _SelectionPane({required this.controller});
  final OrderController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Сонголт', style: context.textStyles.h3),
        const SizedBox(height: 12),
        Text(
          '${controller.selectedCount} захиалга сонгосон',
          style: context.textStyles.body,
        ),
        const SizedBox(height: 8),
        Text(
          'Зөвхөн одоо харагдаж буй мөрүүд bulk үйлдэлд орно.',
          style: context.textStyles.caption,
        ),
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
