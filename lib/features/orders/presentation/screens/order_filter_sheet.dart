// ignore_for_file: constant_identifier_names

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:flutter/material.dart';
import 'package:carcare_service/features/orders/presentation/feature_theme.dart';
import 'package:intl/intl.dart';

// ─── Filter model ─────────────────────────────────────────────────────────────

enum DatePreset {
  all,
  today,
  week,
  month;

  String get label {
    switch (this) {
      case all:
        return 'Бүгд';
      case today:
        return 'Өнөөдөр';
      case week:
        return '7 хоног';
      case month:
        return 'Энэ сар';
    }
  }

  DateTime? get cutoff => cutoffAt(DateTime.now());

  DateTime? cutoffAt(DateTime now) {
    final todayDate = DateTime(now.year, now.month, now.day);
    switch (this) {
      case all:
        return null;
      case today:
        return todayDate;
      case week:
        return todayDate.subtract(const Duration(days: 6));
      case month:
        return DateTime(todayDate.year, todayDate.month, 1);
    }
  }
}

enum OrderSortBy {
  createdAt,
  scheduledAt,
  totalAmount;

  String get label {
    switch (this) {
      case createdAt:
        return 'Үүсгэсэн огноо';
      case scheduledAt:
        return 'Товлосон огноо';
      case totalAmount:
        return 'Дүн';
    }
  }
}

class OrderFilter {
  final Set<OrderStatus> statuses;
  final Set<PaymentStatus> paymentStatuses;
  final DatePreset datePreset;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? branchId;
  final String? assignedToId;
  final String? customerId;
  final String? vehicleId;
  final bool? postpaid;

  /// Retained for source compatibility with the pre-F1 screen. The server's
  /// list contract has no ordering parameter, so this is never applied
  /// locally or counted as an active filter.
  final OrderSortBy sortBy;
  final bool sortAsc;

  const OrderFilter({
    this.statuses = const {},
    this.paymentStatuses = const {},
    this.datePreset = DatePreset.all,
    this.dateFrom,
    this.dateTo,
    this.branchId,
    this.assignedToId,
    this.customerId,
    this.vehicleId,
    this.postpaid,
    this.sortBy = OrderSortBy.createdAt,
    this.sortAsc = false,
  });

  static const empty = OrderFilter();

  int get activeCount {
    int n = 0;
    if (statuses.isNotEmpty) n++;
    if (paymentStatuses.isNotEmpty) n++;
    if (datePreset != DatePreset.all) n++;
    if (dateFrom != null || dateTo != null) n++;
    if (assignedToId != null) n++;
    if (customerId != null) n++;
    if (vehicleId != null) n++;
    if (postpaid != null) n++;
    return n;
  }

  static const _serverStatuses = <OrderStatus>{
    OrderStatus.SCHEDULED,
    OrderStatus.IN_PROGRESS,
    OrderStatus.COMPLETED,
    OrderStatus.CANCELLED,
  };

  OrderStatus? get serverStatus =>
      statuses.length == 1 && _serverStatuses.contains(statuses.first)
      ? statuses.first
      : null;

  PaymentStatus? get serverPaymentStatus =>
      paymentStatuses.length == 1 ? paymentStatuses.first : null;

  DateTime? get effectiveDateFrom => dateFrom ?? datePreset.cutoff;

  DateTime? get effectiveDateTo {
    if (dateTo != null) return dateTo;
    if (datePreset == DatePreset.all) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  OrderFilter copyWith({
    Set<OrderStatus>? statuses,
    Set<PaymentStatus>? paymentStatuses,
    DatePreset? datePreset,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? branchId,
    String? assignedToId,
    String? customerId,
    String? vehicleId,
    bool? postpaid,
    OrderSortBy? sortBy,
    bool? sortAsc,
  }) => OrderFilter(
    statuses: statuses ?? this.statuses,
    paymentStatuses: paymentStatuses ?? this.paymentStatuses,
    datePreset: datePreset ?? this.datePreset,
    dateFrom: dateFrom ?? this.dateFrom,
    dateTo: dateTo ?? this.dateTo,
    branchId: branchId ?? this.branchId,
    assignedToId: assignedToId ?? this.assignedToId,
    customerId: customerId ?? this.customerId,
    vehicleId: vehicleId ?? this.vehicleId,
    postpaid: postpaid ?? this.postpaid,
    sortBy: sortBy ?? this.sortBy,
    sortAsc: sortAsc ?? this.sortAsc,
  );

  /// Compatibility shim. Filtering and ordering pages on the client is
  /// incorrect; callers must use [OrderListController]'s server query.
  List<ServiceOrderSummary> apply(List<ServiceOrderSummary> list) => list;
}

// ─── Reusable form body ─────────────────────────────────────────────────────
//
// Extracted for `TENANT_UI_UX_PLAN.md` Phase 5 so the same filter controls
// back both the phone bottom sheet (buffered, applied on a button tap) and
// the ≥1200dp persistent tablet panel (applied immediately, no buffering).
// Every edit is expressed as a brand-new [OrderFilter] built from [filter]
// rather than `OrderFilter.copyWith`, because `copyWith`'s `x ?? this.x`
// pattern can never clear a nullable field back to null.

const Object _unset = Object();

OrderFilter _withFilter(
  OrderFilter f, {
  Object? statuses = _unset,
  Object? paymentStatuses = _unset,
  Object? datePreset = _unset,
  Object? assignedToId = _unset,
  Object? customerId = _unset,
  Object? vehicleId = _unset,
  Object? postpaid = _unset,
  Object? sortBy = _unset,
  Object? sortAsc = _unset,
}) => OrderFilter(
  statuses: identical(statuses, _unset) ? f.statuses : statuses as Set<OrderStatus>,
  paymentStatuses: identical(paymentStatuses, _unset)
      ? f.paymentStatuses
      : paymentStatuses as Set<PaymentStatus>,
  datePreset: identical(datePreset, _unset) ? f.datePreset : datePreset as DatePreset,
  dateFrom: f.dateFrom,
  dateTo: f.dateTo,
  branchId: f.branchId,
  assignedToId: identical(assignedToId, _unset)
      ? f.assignedToId
      : assignedToId as String?,
  customerId: identical(customerId, _unset) ? f.customerId : customerId as String?,
  vehicleId: identical(vehicleId, _unset) ? f.vehicleId : vehicleId as String?,
  postpaid: identical(postpaid, _unset) ? f.postpaid : postpaid as bool?,
  sortBy: identical(sortBy, _unset) ? f.sortBy : sortBy as OrderSortBy,
  sortAsc: identical(sortAsc, _unset) ? f.sortAsc : sortAsc as bool,
);

/// The filter form's field set, with no sheet/panel chrome of its own.
///
/// [onChanged] fires with a complete, ready-to-apply [OrderFilter] on every
/// edit. The phone sheet buffers those into local state and only calls the
/// controller on "Хэрэглэх"; the tablet panel passes the controller's
/// `setFilter` straight through so a chip tap applies immediately.
class OrderFilterFormBody extends StatelessWidget {
  const OrderFilterFormBody({
    super.key,
    required this.filter,
    required this.onChanged,
    this.assignableUsers = const [],
    this.showSort = true,
  });

  final OrderFilter filter;
  final ValueChanged<OrderFilter> onChanged;
  final List<AssignableUser> assignableUsers;

  /// The phone sheet still offers a client sort order (kept for source
  /// compatibility; the server has no ordering parameter — see
  /// [OrderFilter.sortBy]). The tablet table sorts via its own column
  /// headers instead, so the persistent panel hides this section.
  final bool showSort;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: const ValueKey('order_filter_customer_id'),
          initialValue: filter.customerId,
          decoration: const InputDecoration(
            labelText: 'Харилцагчийн ID',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => onChanged(
            _withFilter(
              filter,
              customerId: value.trim().isEmpty ? null : value.trim(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('order_filter_vehicle_id'),
          initialValue: filter.vehicleId,
          decoration: const InputDecoration(
            labelText: 'Машины ID',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => onChanged(
            _withFilter(
              filter,
              vehicleId: value.trim().isEmpty ? null : value.trim(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _Section(
          title: 'Төлбөрийн төрөл',
          child: Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: 'Бүгд',
                active: filter.postpaid == null,
                activeColor: context.opsAccent,
                onTap: () => onChanged(_withFilter(filter, postpaid: null)),
              ),
              _FilterChip(
                label: 'Дараа төлөх',
                active: filter.postpaid == true,
                activeColor: context.opsAccent,
                onTap: () => onChanged(_withFilter(filter, postpaid: true)),
              ),
              _FilterChip(
                label: 'Энгийн',
                active: filter.postpaid == false,
                activeColor: context.opsAccent,
                onTap: () => onChanged(_withFilter(filter, postpaid: false)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (assignableUsers.isNotEmpty) ...[
          DropdownButtonFormField<String?>(
            key: const ValueKey('order_filter_assignee'),
            value: filter.assignedToId,
            decoration: const InputDecoration(
              labelText: 'Хариуцагч',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Бүгд')),
              ...assignableUsers.map(
                (user) => DropdownMenuItem<String?>(
                  value: user.id,
                  child: Text(user.fullName),
                ),
              ),
            ],
            onChanged: (value) =>
                onChanged(_withFilter(filter, assignedToId: value)),
          ),
          const SizedBox(height: 20),
        ],
        _Section(
          title: 'Статус',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                const [
                  OrderStatus.SCHEDULED,
                  OrderStatus.IN_PROGRESS,
                  OrderStatus.COMPLETED,
                  OrderStatus.CANCELLED,
                ].map((s) {
                  final active = filter.statuses.contains(s);
                  return _FilterChip(
                    label: s.label,
                    active: active,
                    activeColor: context.orderStatusColor(s),
                    onTap: () => onChanged(
                      _withFilter(
                        filter,
                        statuses: active ? const <OrderStatus>{} : {s},
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        _Section(
          title: 'Төлбөрийн байдал',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PaymentStatus.values.map((s) {
              final active = filter.paymentStatuses.contains(s);
              return _FilterChip(
                label: s.label,
                active: active,
                activeColor: context.paymentStatusColor(s),
                onTap: () => onChanged(
                  _withFilter(
                    filter,
                    paymentStatuses: active ? const <PaymentStatus>{} : {s},
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        _Section(
          title: 'Огноо',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DatePreset.values.map((p) {
              final active = p == filter.datePreset;
              return _FilterChip(
                label: p.label,
                active: active,
                activeColor: context.opsAccent,
                onTap: () => onChanged(_withFilter(filter, datePreset: p)),
              );
            }).toList(),
          ),
        ),
        if (showSort) ...[
          const SizedBox(height: 20),
          _Section(
            title: 'Дараалал',
            child: Column(
              children: OrderSortBy.values.map((s) {
                final active = s == filter.sortBy;
                return InkWell(
                  onTap: () => onChanged(
                    _withFilter(
                      filter,
                      sortBy: s,
                      sortAsc: filter.sortBy == s ? !filter.sortAsc : false,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                  child: AnimatedContainer(
                    duration: MediaQuery.of(context).disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 120),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? context.opsAccent.withOpacity(0.08)
                          : context.opsBackground,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                      border: Border.all(
                        color: active
                            ? context.opsAccent.withOpacity(0.4)
                            : context.opsDivider,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          s == OrderSortBy.totalAmount
                              ? Icons.monetization_on_outlined
                              : s == OrderSortBy.scheduledAt
                              ? Icons.event_outlined
                              : Icons.access_time_outlined,
                          size: 16,
                          color: active
                              ? context.opsAccent
                              : context.opsTextSecondary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          s.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: active
                                ? context.opsAccent
                                : context.opsTextPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (active)
                          Icon(
                            filter.sortAsc
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 16,
                            color: context.opsAccent,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

/// The persistent filter panel shown beside the tablet table at ≥1200dp
/// (`TENANT_UI_UX_PLAN.md` Phase 5). Reuses [OrderFilterFormBody] and applies
/// every edit immediately — there is no separate "apply" step because the
/// panel is always visible, unlike the phone sheet it shares its fields with.
class OrderFilterPanel extends StatelessWidget {
  const OrderFilterPanel({
    super.key,
    required this.filter,
    required this.onChanged,
    required this.onClear,
    this.assignableUsers = const [],
  });

  final OrderFilter filter;
  final ValueChanged<OrderFilter> onChanged;
  final VoidCallback onClear;
  final List<AssignableUser> assignableUsers;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('order_filter_panel'),
      width: 300,
      decoration: BoxDecoration(
        color: context.opsSurface,
        border: Border(right: BorderSide(color: context.opsDivider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text('Шүүлтүүр', style: context.textStyles.h3),
                const Spacer(),
                if (filter.activeCount > 0)
                  TextButton(
                    onPressed: onClear,
                    style: TextButton.styleFrom(
                      foregroundColor: context.opsDanger,
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text(
                      'Арилгах',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: OrderFilterFormBody(
                filter: filter,
                assignableUsers: assignableUsers,
                onChanged: onChanged,
                showSort: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sheet ────────────────────────────────────────────────────────────────────

Future<OrderFilter?> showOrderFilterSheet(
  BuildContext context,
  OrderFilter current, {
  List<AssignableUser> assignableUsers = const [],
}) {
  return showModalBottomSheet<OrderFilter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _OrderFilterSheet(current: current, assignableUsers: assignableUsers),
  );
}

class _OrderFilterSheet extends StatefulWidget {
  final OrderFilter current;
  final List<AssignableUser> assignableUsers;
  const _OrderFilterSheet({
    required this.current,
    this.assignableUsers = const [],
  });

  @override
  State<_OrderFilterSheet> createState() => _OrderFilterSheetState();
}

class _OrderFilterSheetState extends State<_OrderFilterSheet> {
  late Set<OrderStatus> _statuses;
  late Set<PaymentStatus> _paymentStatuses;
  late DatePreset _datePreset;
  late OrderSortBy _sortBy;
  late bool _sortAsc;
  late String? _assignedToId;
  late bool? _postpaid;
  late String? _customerId;
  late String? _vehicleId;

  @override
  void initState() {
    super.initState();
    _statuses = Set.from(widget.current.statuses);
    _paymentStatuses = Set.from(widget.current.paymentStatuses);
    _datePreset = widget.current.datePreset;
    _sortBy = widget.current.sortBy;
    _sortAsc = widget.current.sortAsc;
    _assignedToId = widget.current.assignedToId;
    _postpaid = widget.current.postpaid;
    _customerId = widget.current.customerId;
    _vehicleId = widget.current.vehicleId;
  }

  OrderFilter get _built => OrderFilter(
    statuses: _statuses,
    paymentStatuses: _paymentStatuses,
    datePreset: _datePreset,
    dateFrom: widget.current.dateFrom,
    dateTo: widget.current.dateTo,
    assignedToId: _assignedToId,
    customerId: _customerId,
    vehicleId: _vehicleId,
    postpaid: _postpaid,
    sortBy: _sortBy,
    sortAsc: _sortAsc,
  );

  void _reset() => setState(() {
    _statuses = {};
    _paymentStatuses = {};
    _datePreset = DatePreset.all;
    _sortBy = OrderSortBy.createdAt;
    _sortAsc = false;
    _assignedToId = null;
    _postpaid = null;
    _customerId = null;
    _vehicleId = null;
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: context.opsSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.opsDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Text('Шүүлтүүр', style: context.textStyles.h3),
                    Spacer(),
                    TextButton(
                      onPressed: _reset,
                      style: TextButton.styleFrom(
                        foregroundColor: context.opsDanger,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(
                        'Бүгдийг арилгах',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
                  children: [
                    OrderFilterFormBody(
                      filter: _built,
                      assignableUsers: widget.assignableUsers,
                      onChanged: (next) => setState(() {
                        _statuses = next.statuses;
                        _paymentStatuses = next.paymentStatuses;
                        _datePreset = next.datePreset;
                        _assignedToId = next.assignedToId;
                        _postpaid = next.postpaid;
                        _customerId = next.customerId;
                        _vehicleId = next.vehicleId;
                        _sortBy = next.sortBy;
                        _sortAsc = next.sortAsc;
                      }),
                    ),
                  ],
                ),
              ),

              // Apply button
              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: context.opsSurface,
                  border: Border(top: BorderSide(color: context.opsDivider)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _built),
                    child: Text(
                      _built.activeCount > 0
                          ? 'Хэрэглэх  ·  ${_built.activeCount} шүүлт'
                          : 'Хэрэглэх',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.opsTextOnDark,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.opsTextSecondary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: AnimatedContainer(
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? activeColor.withOpacity(0.12)
                    : context.opsBackground,
                borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                border: Border.all(
                  color: active ? activeColor.withOpacity(0.5) : context.opsDivider,
                  width: active ? 1.5 : 1,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? activeColor : context.opsTextSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Active filter summary widget (used in list screen) ───────────────────────

class ActiveFilterBar extends StatelessWidget {
  final OrderFilter filter;
  final VoidCallback onClear;
  final NumberFormat numFmt = NumberFormat('#,###');

  ActiveFilterBar({super.key, required this.filter, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final chips = <String>[];

    for (final s in filter.statuses) {
      chips.add(s.label);
    }
    for (final p in filter.paymentStatuses) {
      chips.add(p.label);
    }
    if (filter.datePreset != DatePreset.all) chips.add(filter.datePreset.label);
    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      color: context.opsAccent.withOpacity(0.06),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 14, color: context.opsAccent),
          SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: chips
                    .map(
                      (c) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: context.opsAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusFull,
                          ),
                        ),
                        child: Text(
                          c,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.opsAccent,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.close, size: 16, color: context.opsAccent),
            ),
          ),
        ],
      ),
    );
  }
}
