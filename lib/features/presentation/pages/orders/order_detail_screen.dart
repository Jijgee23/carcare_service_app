import 'package:carcare_service/core/services/service_catalog_service.dart';
import 'package:carcare_service/features/presentation/pages/orders/order_payment_screen.dart';
import 'package:carcare_service/features/models/service_catalog.dart'
    hide DiagnosticTemplateSummary, DiagnosticType, StockLevel;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/models/diagnostic.dart';
import 'package:carcare_service/features/models/order.dart';
import 'package:carcare_service/features/presentation/controllers/controllers.dart';
import 'package:carcare_service/features/presentation/pages/inspection/new_inspection_screen.dart';
import 'package:carcare_service/features/presentation/pages/inspection/report_detail_screen.dart';
import 'package:carcare_service/features/presentation/data/repository/diagnostic_repository.dart';
import 'package:carcare_service/shared/widgets/common/common_widgets.dart';
import 'package:carcare_service/shared/widgets/dialogs/confirm_sheet.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OrderController>().loadDetail(widget.orderId);
    });
  }

  Future<void> _changeStatus(OrderStatus status) async {
    if (status == OrderStatus.COMPLETED) {
      final ok = await ConfirmSheet.show(
        context,
        title: 'Захиалга дуусгах уу?',
        message: 'Дуусгасны дараа захиалганд өөрчлөлт хийх боломжгүй болно.',
        confirmLabel: 'Дуусгах',
        icon: Icons.check_circle_outline_rounded,
        iconColor: AppColors.good,
      );
      if (!ok || !mounted) return;
    } else if (status == OrderStatus.CANCELLED) {
      final ok = await ConfirmSheet.steps(
        context,
        steps: const [
          ConfirmStep(
            title: 'Захиалга цуцлах уу?',
            message: 'Цуцалсны дараа захиалганд өөрчлөлт хийх боломжгүй болно.',
            confirmLabel: 'Үргэлжлүүлэх',
            icon: Icons.cancel_outlined,
            iconColor: AppColors.warning,
          ),
          ConfirmStep(
            title: 'Цуцлах уу?',
            message: 'Та итгэлтэй байна уу? Энэ үйлдлийг буцаах боломжгүй.',
            confirmLabel: 'Цуцлах',
            icon: Icons.do_not_disturb_on_outlined,
            isDangerous: true,
          ),
        ],
      );
      if (!ok || !mounted) return;
    }
    await context.read<OrderController>().updateStatus(widget.orderId, status);
  }

  Future<void> _addItem() async {
    final provider = context.read<OrderController>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemFormScreen(orderId: widget.orderId, provider: provider),
      ),
    );
  }

  Future<void> _editItem(ServiceItem item) async {
    final provider = context.read<OrderController>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemFormScreen(
          orderId: widget.orderId,
          provider: provider,
          editItem: item,
        ),
      ),
    );
  }

  Future<void> _openNewInspection() async {
    final order = context.read<OrderController>().detailState.valueOrNull;
    if (order == null) return;
    final templateId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplatePickerSheet(),
    );
    if (templateId == null || !mounted) return;
    await NewInspectionScreen.pushFromOrder(
      context,
      orderId: order.id,
      vehicle: order.vehicle,
      customer: order.customer,
      templateId: templateId,
    );
    if (mounted) context.read<OrderController>().refreshDetail();
  }

  Future<void> _removeItem(ServiceItem item) async {
    final ok = await ConfirmSheet.show(
      context,
      title: 'Мөр устгах уу?',
      message: '"${item.description}" мөрийг захиалгаас хасах уу?',
      confirmLabel: 'Устгах',
      icon: Icons.delete_outline_rounded,
      isDangerous: true,
    );
    if (!ok || !mounted) return;
    await context.read<OrderController>().removeItem(widget.orderId, item.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderController>();

    switch (provider.detailState) {
      case AsyncLoading():
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AsyncError(:final error):
        return Scaffold(
          appBar: AppBar(),
          body: EmptyState(message: error.display, icon: Icons.error_outline),
        );
      case AsyncData(:final value):
        return _buildDetail(context, value, provider);
    }
  }

  Widget _buildDetail(BuildContext context, ServiceOrderDetail o, OrderController provider) {
    final numFmt = NumberFormat('#,###');
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final locked = o.status.isLocked;

    return Scaffold(
      appBar: AppBar(
        title: Text('#${o.number}'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: provider.refreshDetail)],
      ),
      body: RefreshIndicator(
        onRefresh: provider.refreshDetail,
        child: ListView(
          padding: const EdgeInsets.all(AppDimens.paddingMD),
          children: [
            // ─── Locked banner ───────────────────────────────────────────
            if (locked) ...[_LockedBanner(status: o.status), const SizedBox(height: 14)],

            // ─── Status + Payment ────────────────────────────────────────
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatusChip(status: o.status),
                      const SizedBox(width: 8),
                      _PaymentChip(status: o.paymentStatus),
                      const Spacer(),
                      Text('#${o.number}', style: AppTextStyles.caption),
                    ],
                  ),
                  const Divider(height: 20),
                  _InfoRow(
                    icon: Icons.directions_car_outlined,
                    text: '${o.vehicle.plate} — ${o.vehicle.displayName}',
                  ),
                  _InfoRow(
                    icon: Icons.person_outline,
                    text: '${o.customer.fullName} · ${o.customer.phone}',
                  ),
                  _InfoRow(icon: Icons.storefront_outlined, text: o.branch.name),
                  if (o.assignedTo != null)
                    _InfoRow(icon: Icons.engineering_outlined, text: o.assignedTo!.fullName),
                  if (o.scheduledAt != null)
                    _InfoRow(
                      icon: Icons.event_outlined,
                      text: 'Товлосон: ${dateFmt.format(o.scheduledAt!)}',
                    ),
                  if (o.startedAt != null)
                    _InfoRow(
                      icon: Icons.play_circle_outline,
                      text: 'Эхэлсэн: ${dateFmt.format(o.startedAt!)}',
                    ),
                  if (o.completedAt != null)
                    _InfoRow(
                      icon: Icons.check_circle_outline,
                      text: 'Дууссан: ${dateFmt.format(o.completedAt!)}',
                    ),
                  if (o.notes != null && o.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _InfoRow(icon: Icons.notes_outlined, text: o.notes!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ─── Status transition ────────────────────────────────────────
            if (o.status.nextStatuses.isNotEmpty) ...[
              _StatusSection(current: o.status, onChangeStatus: _changeStatus),
              const SizedBox(height: 14),
            ],

            // ─── Items ───────────────────────────────────────────────────
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Ажлын мөрүүд', style: AppTextStyles.h3),
                      if (o.status.canAddItems)
                        TextButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Нэмэх'),
                        ),
                    ],
                  ),
                  if (o.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Ажлын мөр байхгүй', style: AppTextStyles.caption),
                    )
                  else ...[
                    const Divider(height: 16),
                    ...o.items.map(
                      (item) => _ItemRow(
                        item: item,
                        canEdit: o.status.canAddItems,
                        onEdit: () => _editItem(item),
                        onRemove: () => _removeItem(item),
                      ),
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Нийт дүн', style: AppTextStyles.bodyMedium),
                        Text(
                          '${numFmt.format((o.totalAmount ?? 0).toInt())}₮',
                          style: AppTextStyles.h3.copyWith(color: AppColors.accent),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ─── Linked reports ──────────────────────────────────────────
            _DiagnosticsSection(
              order: o,
              dateFmt: dateFmt,
              locked: locked,
              onNewInspection: _openNewInspection,
              onOpenReport: (id) => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReportDetailScreen(reportId: id)),
              ),
            ),
            const SizedBox(height: 14),

            // ─── Payment ──────────────────────────────────────────────────
            _PaymentTile(
              order: o,
              numFmt: numFmt,
              onTap: () {
                final ctrl = context.read<OrderController>();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: ctrl,
                      child: OrderPaymentScreen(orderId: widget.orderId),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Locked banner ────────────────────────────────────────────────────────────

class _LockedBanner extends StatelessWidget {
  final OrderStatus status;
  const _LockedBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final isCompleted = status == OrderStatus.COMPLETED;
    final bg = isCompleted ? AppColors.goodBg : AppColors.dangerBg;
    final fg = isCompleted ? AppColors.good : AppColors.danger;
    final title = isCompleted ? 'Захиалга дууссан' : 'Захиалга цуцлагдсан';
    final sub = isCompleted
        ? 'Дууссан захиалганд өөрчлөлт хийх боломжгүй.'
        : 'Цуцлагдсан захиалганд өөрчлөлт хийх боломжгүй.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: fg.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(Icons.lock_outline_rounded, size: 17, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
                ),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 11, color: fg.withOpacity(0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: AppTextStyles.caption)),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final ServiceItem item;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  const _ItemRow({
    required this.item,
    required this.canEdit,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final numFmt = NumberFormat('#,###');
    final qtyStr = item.quantity % 1 == 0
        ? item.quantity.toInt().toString()
        : item.quantity.toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: item.kind.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimens.radiusSM),
            ),
            child: Text(
              item.kind.label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: item.kind.color),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description, style: AppTextStyles.captionMedium),
                Text(
                  '$qtyStr × ${numFmt.format(item.unitPrice.toInt())}₮',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${numFmt.format(item.total.toInt())}₮', style: AppTextStyles.captionMedium),
          if (canEdit) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onEdit,
              child: const Icon(Icons.edit_outlined, size: 15, color: AppColors.textHint),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.delete_outline, size: 15, color: AppColors.textHint),
            ),
          ],
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

// ─── Status section ───────────────────────────────────────────────────────────

// Metadata per transition
class _StatusMeta {
  final IconData icon;
  final String label;
  final String description;
  const _StatusMeta(this.icon, this.label, this.description);
}

_StatusMeta _statusMeta(OrderStatus from, OrderStatus to) {
  switch (to) {
    case OrderStatus.IN_PROGRESS:
      return from == OrderStatus.WAITING_PARTS
          ? const _StatusMeta(
              Icons.play_arrow_rounded,
              'Үргэлжлүүлэх',
              'Сэлбэг ирсэн тул үйлчилгээг үргэлжлүүлнэ',
            )
          : const _StatusMeta(
              Icons.play_arrow_rounded,
              'Эхлүүлэх',
              'Үйлчилгээг эхлүүлж ажлыг явуулна',
            );
    case OrderStatus.WAITING_PARTS:
      return const _StatusMeta(
        Icons.inventory_2_outlined,
        'Сэлбэг хүлээх',
        'Шаардлагатай сэлбэг ирэх хүртэл хүлээнэ',
      );
    case OrderStatus.COMPLETED:
      return const _StatusMeta(
        Icons.check_circle_outline_rounded,
        'Дуусгах',
        'Захиалгыг амжилттай дуусгана',
      );
    case OrderStatus.CANCELLED:
      return const _StatusMeta(
        Icons.cancel_outlined,
        'Цуцлах',
        'Захиалгыг цуцлах — буцаах боломжгүй',
      );
    default:
      return _StatusMeta(Icons.arrow_forward, to.label, '');
  }
}

class _StatusSection extends StatelessWidget {
  final OrderStatus current;
  final void Function(OrderStatus) onChangeStatus;
  const _StatusSection({required this.current, required this.onChangeStatus});

  @override
  Widget build(BuildContext context) {
    // CANCELLED always goes last
    final nexts = [...current.nextStatuses]
      ..sort((a, b) {
        if (a == OrderStatus.CANCELLED) return 1;
        if (b == OrderStatus.CANCELLED) return -1;
        return 0;
      });

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text('Статус өөрчлөх', style: AppTextStyles.h3),
                const Spacer(),
                _StatusChip(status: current),
              ],
            ),
          ),
          const Divider(height: 1),
          ...nexts.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            return Column(
              children: [
                _StatusActionButton(from: current, to: s, onTap: () => onChangeStatus(s)),
                if (i < nexts.length - 1) const Divider(height: 1, indent: 68, endIndent: 16),
              ],
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _StatusActionButton extends StatelessWidget {
  final OrderStatus from;
  final OrderStatus to;
  final VoidCallback onTap;
  const _StatusActionButton({required this.from, required this.to, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = _statusMeta(from, to);
    final isCancelled = to == OrderStatus.CANCELLED;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMD),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: to.color.withOpacity(isCancelled ? 0.08 : 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(meta.icon, color: to.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta.label,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: to.color),
                  ),
                  if (meta.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(meta.description, style: AppTextStyles.caption),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: to.color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

// ─── Payment summary tile ──────────────────────────────────────────────────────

class _PaymentTile extends StatelessWidget {
  final ServiceOrderDetail order;
  final NumberFormat numFmt;
  final VoidCallback onTap;
  const _PaymentTile({required this.order, required this.numFmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final total = order.totalAmount ?? 0.0;
    final paid = order.paidAmount ?? 0.0;
    final remaining = (total - paid).clamp(0.0, double.infinity);
    final isPaid = order.paymentStatus == PaymentStatus.PAID;

    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLG),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              const Icon(Icons.payments_outlined, size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Төлбөр', style: AppTextStyles.h3),
                        const SizedBox(width: 8),
                        _PaymentChip(status: order.paymentStatus),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isPaid
                          ? '${numFmt.format(total.toInt())}₮ · Бүрэн төлөгдсөн'
                          : remaining > 0
                              ? 'Үлдэгдэл: ${numFmt.format(remaining.toInt())}₮'
                              : '${numFmt.format(total.toInt())}₮',
                      style: AppTextStyles.caption.copyWith(
                        color: isPaid
                            ? AppColors.good
                            : remaining > 0
                                ? AppColors.danger
                                : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add item bottom sheet ─────────────────────────────────────────────────────

// ─── Item form screen (add + edit) ────────────────────────────────────────────

class ItemFormScreen extends StatefulWidget {
  final String orderId;
  final OrderController provider;
  final ServiceItem? editItem;
  const ItemFormScreen({
    super.key,
    required this.orderId,
    required this.provider,
    this.editItem,
  });

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  // Search (add mode only)
  final _searchCtrl = TextEditingController();
  List<CatalogService> _allResults = [];
  ServiceKind? _kindFilter;
  String? _laborCategoryFilter;
  bool _searching = false;
  String? _selectedServiceId;
  bool _serviceSelected = false;

  // Form
  ItemKind _kind = ItemKind.LABOR;
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.editItem != null;

  List<LaborCategory> get _laborCategories {
    final seen = <String>{};
    final result = <LaborCategory>[];
    for (final svc in _allResults) {
      if (svc.type == ServiceKind.LABOR && svc.laborCategory != null && seen.add(svc.laborCategory!.id)) {
        result.add(svc.laborCategory!);
      }
    }
    return result;
  }

  List<CatalogService> get _filtered {
    var list = _kindFilter == null ? _allResults : _allResults.where((s) => s.type == _kindFilter).toList();
    if (_laborCategoryFilter != null) {
      list = list.where((s) => s.laborCategory?.id == _laborCategoryFilter).toList();
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final item = widget.editItem!;
      _kind = item.kind;
      _descCtrl.text = item.description;
      _qtyCtrl.text = item.quantity % 1 == 0
          ? item.quantity.toInt().toString()
          : item.quantity.toStringAsFixed(2);
      _priceCtrl.text = item.unitPrice.toInt().toString();
      _selectedServiceId = item.serviceId;
    } else {
      _loadAll();
      _searchCtrl.addListener(_onSearch);
    }
  }

  @override
  void dispose() {
    if (!_isEdit) _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _searching = true);
    final list = await ServiceCatalogService.getServices(q: '');
    if (mounted) setState(() { _allResults = list; _searching = false; });
  }

  void _onSearch() => _fetch(_searchCtrl.text.trim());

  Future<void> _fetch(String q) async {
    setState(() => _searching = true);
    final list = await ServiceCatalogService.getServices(q: q);
    if (mounted) setState(() { _allResults = list; _searching = false; });
  }

  ItemKind _toItemKind(ServiceKind k) {
    switch (k) {
      case ServiceKind.GOODS: return ItemKind.PART;
      case ServiceKind.DIAGNOSTIC: return ItemKind.DIAGNOSTIC;
      case ServiceKind.LABOR: return ItemKind.LABOR;
    }
  }

  void _selectService(CatalogService svc) {
    setState(() {
      _selectedServiceId = svc.id;
      _kind = _toItemKind(svc.type);
      _descCtrl.text = svc.name;
      _priceCtrl.text = svc.price.toInt().toString();
      if (_qtyCtrl.text.isEmpty) _qtyCtrl.text = '1';
      _serviceSelected = true;
    });
    FocusScope.of(context).unfocus();
  }

  void _clearService() {
    setState(() {
      _selectedServiceId = null;
      _serviceSelected = false;
      _searchCtrl.clear();
      _descCtrl.clear();
      _priceCtrl.clear();
      _qtyCtrl.text = '1';
      _kind = ItemKind.LABOR;
    });
    _loadAll();
  }

  Future<void> _save() async {
    final desc = _descCtrl.text.trim();
    final qty = double.tryParse(_qtyCtrl.text.trim().replaceAll(',', '')) ?? 0;
    final price = double.tryParse(_priceCtrl.text.trim().replaceAll(',', '')) ?? 0;
    if (desc.isEmpty || qty <= 0 || price < 0) return;
    setState(() => _saving = true);
    final ok = _isEdit
        ? await widget.provider.updateItem(
            widget.orderId, widget.editItem!.id,
            kind: _kind, description: desc, quantity: qty, unitPrice: price,
          )
        : await widget.provider.addItem(
            widget.orderId,
            kind: _kind, description: desc, quantity: qty, unitPrice: price,
            serviceId: _selectedServiceId,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final numFmt = NumberFormat('#,###');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Мөр засах' : 'Мөр нэмэх'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Service search (add mode only) ─────────────────────
            if (!_isEdit) ...[
              if (!_serviceSelected) ...[
                // Search field
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Үйлчилгээ хайх...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () { _searchCtrl.clear(); _loadAll(); },
                              )
                            : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),

                // Kind filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _KindFilterChip(
                        label: 'Бүгд',
                        active: _kindFilter == null,
                        onTap: () => setState(() { _kindFilter = null; _laborCategoryFilter = null; }),
                      ),
                      ...ServiceKind.values.map((k) => _KindFilterChip(
                        label: k.label,
                        active: _kindFilter == k,
                        color: _toItemKind(k).color,
                        onTap: () => setState(() {
                          _kindFilter = _kindFilter == k ? null : k;
                          _laborCategoryFilter = null;
                        }),
                      )),
                    ],
                  ),
                ),
                // Labor category chips (LABOR kind сонгогдсон + категори байвал)
                if (_kindFilter == ServiceKind.LABOR && _laborCategories.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _KindFilterChip(
                          label: 'Бүгд',
                          active: _laborCategoryFilter == null,
                          onTap: () => setState(() => _laborCategoryFilter = null),
                        ),
                        ..._laborCategories.map((cat) => _KindFilterChip(
                          label: cat.name,
                          active: _laborCategoryFilter == cat.id,
                          onTap: () => setState(
                              () => _laborCategoryFilter = _laborCategoryFilter == cat.id ? null : cat.id),
                        )),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),

                // Results list
                if (_filtered.isNotEmpty)
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final svc = _filtered[i];
                        final ik = _toItemKind(svc.type);
                        return InkWell(
                          onTap: () => _selectService(svc),
                          borderRadius: i == 0
                              ? const BorderRadius.vertical(top: Radius.circular(AppDimens.radiusLG))
                              : i == _filtered.length - 1
                                  ? const BorderRadius.vertical(bottom: Radius.circular(AppDimens.radiusLG))
                                  : BorderRadius.zero,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: ik.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(AppDimens.radiusSM),
                                  ),
                                  child: Text(ik.label,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ik.color)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(svc.name, style: AppTextStyles.bodyMedium),
                                      if (svc.laborCategory != null)
                                        Text(svc.laborCategory!.name, style: AppTextStyles.caption),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${numFmt.format(svc.price.toInt())}₮',
                                    style: AppTextStyles.captionMedium.copyWith(color: AppColors.accent)),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right, size: 16, color: AppColors.textHint),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else if (!_searching)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text('Үр дүн олдсонгүй', style: AppTextStyles.caption),
                    ),
                  ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('эсвэл гар аргаар бөглөх',
                          style: AppTextStyles.caption.copyWith(fontSize: 11)),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Selected service badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                    border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_descCtrl.text,
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent)),
                      ),
                      GestureDetector(
                        onTap: _clearService,
                        child: const Icon(Icons.close, size: 16, color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],

            // ── Kind selector ────────────────────────────────────────
            Text('Мөрийн төрөл', style: AppTextStyles.label),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ItemKind.values.map((k) {
                  final active = k == _kind;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() { _kind = k; _selectedServiceId = null; }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? k.color.withOpacity(0.12) : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                          border: Border.all(color: active ? k.color : AppColors.divider),
                        ),
                        child: Text(k.label,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                color: active ? k.color : AppColors.textSecondary)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Form fields ──────────────────────────────────────────
            AppTextField(label: 'Тайлбар *', hint: 'Тосны шилжүүлэлт...', controller: _descCtrl),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Тоо *', hint: '1', controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    label: 'Нэгж үнэ (₮) *', hint: '0', controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: _isEdit ? 'Хадгалах' : 'Нэмэх',
                onPressed: _saving ? null : _save,
                loading: _saving,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _KindFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color? color;
  final VoidCallback onTap;
  const _KindFilterChip({required this.label, required this.active, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? c.withOpacity(0.12) : AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
            border: Border.all(color: active ? c : AppColors.divider),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: active ? c : AppColors.textSecondary)),
        ),
      ),
    );
  }
}

// ─── Diagnostics section ─────────────────────────────────────────────────────

class _DiagnosticsSection extends StatelessWidget {
  final ServiceOrderDetail order;
  final DateFormat dateFmt;
  final bool locked;
  final VoidCallback onNewInspection;
  final void Function(String reportId) onOpenReport;
  const _DiagnosticsSection({
    required this.order,
    required this.dateFmt,
    required this.locked,
    required this.onNewInspection,
    required this.onOpenReport,
  });

  @override
  Widget build(BuildContext context) {
    final reports = order.reports;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                const Icon(Icons.assignment_outlined, size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Text('Оношилгоо', style: AppTextStyles.h3),
                const SizedBox(width: 8),
                if (reports.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                    ),
                    child: Text(
                      '${reports.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                const Spacer(),
                if (!locked)
                  TextButton.icon(
                    onPressed: onNewInspection,
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Шинэ оношилгоо', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Body ─────────────────────────────────────────────────────
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Тайлан бүртгээгүй байна.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...reports.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              final type = r.template.type;
              return Column(
                children: [
                  InkWell(
                    onTap: () => onOpenReport(r.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // Type badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: type.bgColor,
                              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                            ),
                            child: Text(
                              type.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: type.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Name + date
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.template.name, style: AppTextStyles.captionMedium),
                                const SizedBox(height: 2),
                                Text(dateFmt.format(r.createdAt), style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          // Chevron
                          const Text(
                            'Үзэх →',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i < reports.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              );
            }),
        ],
      ),
    );
  }
}

// ─── Template picker bottom sheet ────────────────────────────────────────────

class _TemplatePickerSheet extends StatefulWidget {
  const _TemplatePickerSheet();

  @override
  State<_TemplatePickerSheet> createState() => _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends State<_TemplatePickerSheet> {
  List<DiagnosticTemplateSummary>? _templates;
  bool _loading = true;
  final _repo = DiagnosticRepository();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _repo.getTemplates();
    if (mounted) {
      setState(() {
        _templates = result;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.post_add_outlined, size: 16, color: AppColors.accent),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Оношилгооны загвар', style: AppTextStyles.h3),
                    Text('Загвараа сонгоно уу', style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body
          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : (_templates == null || _templates!.isEmpty)
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Идэвхтэй загвар олдсонгүй.\nВеб дашбоардаас загвар үүсгэнэ үү.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.only(bottom: bottom + 16),
                    itemCount: _templates!.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (_, i) {
                      final t = _templates![i];
                      return _TemplateRow(template: t, onTap: () => Navigator.pop(context, t.id));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  final DiagnosticTemplateSummary template;
  final VoidCallback onTap;
  const _TemplateRow({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = template.type;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: type.bgColor,
                borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              ),
              child: Text(
                type.label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: type.color),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(template.name, style: AppTextStyles.bodyMedium),
                  if (template.description != null && template.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      template.description!,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
