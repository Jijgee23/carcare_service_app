// ignore_for_file: constant_identifier_names

import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/models/order.dart';
import 'package:flutter/material.dart';
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

  DateTime? get cutoff {
    final now = DateTime.now();
    switch (this) {
      case all:
        return null;
      case today:
        return DateTime(now.year, now.month, now.day);
      case week:
        return now.subtract(const Duration(days: 7));
      case month:
        return DateTime(now.year, now.month, 1);
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
  final OrderSortBy sortBy;
  final bool sortAsc;

  const OrderFilter({
    this.statuses = const {},
    this.paymentStatuses = const {},
    this.datePreset = DatePreset.all,
    this.sortBy = OrderSortBy.createdAt,
    this.sortAsc = false,
  });

  static const empty = OrderFilter();

  int get activeCount {
    int n = 0;
    if (statuses.isNotEmpty) n++;
    if (paymentStatuses.isNotEmpty) n++;
    if (datePreset != DatePreset.all) n++;
    if (sortBy != OrderSortBy.createdAt || sortAsc) n++;
    return n;
  }

  OrderFilter copyWith({
    Set<OrderStatus>? statuses,
    Set<PaymentStatus>? paymentStatuses,
    DatePreset? datePreset,
    OrderSortBy? sortBy,
    bool? sortAsc,
  }) => OrderFilter(
    statuses: statuses ?? this.statuses,
    paymentStatuses: paymentStatuses ?? this.paymentStatuses,
    datePreset: datePreset ?? this.datePreset,
    sortBy: sortBy ?? this.sortBy,
    sortAsc: sortAsc ?? this.sortAsc,
  );

  List<ServiceOrderSummary> apply(List<ServiceOrderSummary> list) {
    var result = list.where((o) {
      if (statuses.isNotEmpty && !statuses.contains(o.status)) return false;
      if (paymentStatuses.isNotEmpty && !paymentStatuses.contains(o.paymentStatus)) return false;
      final cutoff = datePreset.cutoff;
      if (cutoff != null && o.createdAt.isBefore(cutoff)) return false;
      return true;
    }).toList();

    result.sort((a, b) {
      int cmp;
      switch (sortBy) {
        case OrderSortBy.scheduledAt:
          final aT = a.scheduledAt ?? a.createdAt;
          final bT = b.scheduledAt ?? b.createdAt;
          cmp = aT.compareTo(bT);
        case OrderSortBy.totalAmount:
          cmp = (a.totalAmount ?? 0).compareTo(b.totalAmount ?? 0);
        case OrderSortBy.createdAt:
          cmp = a.createdAt.compareTo(b.createdAt);
      }
      return sortAsc ? cmp : -cmp;
    });

    return result;
  }
}

// ─── Sheet ────────────────────────────────────────────────────────────────────

Future<OrderFilter?> showOrderFilterSheet(BuildContext context, OrderFilter current) {
  return showModalBottomSheet<OrderFilter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OrderFilterSheet(current: current),
  );
}

class _OrderFilterSheet extends StatefulWidget {
  final OrderFilter current;
  const _OrderFilterSheet({required this.current});

  @override
  State<_OrderFilterSheet> createState() => _OrderFilterSheetState();
}

class _OrderFilterSheetState extends State<_OrderFilterSheet> {
  late Set<OrderStatus> _statuses;
  late Set<PaymentStatus> _paymentStatuses;
  late DatePreset _datePreset;
  late OrderSortBy _sortBy;
  late bool _sortAsc;

  @override
  void initState() {
    super.initState();
    _statuses = Set.from(widget.current.statuses);
    _paymentStatuses = Set.from(widget.current.paymentStatuses);
    _datePreset = widget.current.datePreset;
    _sortBy = widget.current.sortBy;
    _sortAsc = widget.current.sortAsc;
  }

  OrderFilter get _built => OrderFilter(
    statuses: _statuses,
    paymentStatuses: _paymentStatuses,
    datePreset: _datePreset,
    sortBy: _sortBy,
    sortAsc: _sortAsc,
  );

  void _reset() => setState(() {
    _statuses = {};
    _paymentStatuses = {};
    _datePreset = DatePreset.all;
    _sortBy = OrderSortBy.createdAt;
    _sortAsc = false;
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
          decoration: const BoxDecoration(
            color: AppColors.surface,
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
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    const Text('Шүүлтүүр', style: AppTextStyles.h3),
                    const Spacer(),
                    TextButton(
                      onPressed: _reset,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('Бүгдийг арилгах', style: TextStyle(fontSize: 13)),
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
                    // ── Статус ────────────────────────────────────────
                    _Section(
                      title: 'Статус',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: OrderStatus.values.map((s) {
                          final active = _statuses.contains(s);
                          return _FilterChip(
                            label: s.label,
                            active: active,
                            activeColor: s.color,
                            onTap: () => setState(() {
                              active ? _statuses.remove(s) : _statuses.add(s);
                            }),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Төлбөр ────────────────────────────────────────
                    _Section(
                      title: 'Төлбөрийн байдал',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PaymentStatus.values.map((s) {
                          final active = _paymentStatuses.contains(s);
                          return _FilterChip(
                            label: s.label,
                            active: active,
                            activeColor: s.color,
                            onTap: () => setState(() {
                              active ? _paymentStatuses.remove(s) : _paymentStatuses.add(s);
                            }),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Огноо ─────────────────────────────────────────
                    _Section(
                      title: 'Огноо',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: DatePreset.values.map((p) {
                          final active = p == _datePreset;
                          return _FilterChip(
                            label: p.label,
                            active: active,
                            activeColor: AppColors.accent,
                            onTap: () => setState(() => _datePreset = p),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Дараалал ──────────────────────────────────────
                    _Section(
                      title: 'Дараалал',
                      child: Column(
                        children: OrderSortBy.values.map((s) {
                          final active = s == _sortBy;
                          return InkWell(
                            onTap: () => setState(() {
                              if (_sortBy == s) {
                                _sortAsc = !_sortAsc;
                              } else {
                                _sortBy = s;
                                _sortAsc = false;
                              }
                            }),
                            borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: active
                                    ? AppColors.accent.withOpacity(0.08)
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                                border: Border.all(
                                  color: active
                                      ? AppColors.accent.withOpacity(0.4)
                                      : AppColors.divider,
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
                                    color: active ? AppColors.accent : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    s.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                                      color: active ? AppColors.accent : AppColors.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (active)
                                    Icon(
                                      _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                                      size: 16,
                                      color: AppColors.accent,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
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
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.divider)),
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor.withOpacity(0.12) : AppColors.background,
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          border: Border.all(
            color: active ? activeColor.withOpacity(0.5) : AppColors.divider,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? activeColor : AppColors.textSecondary,
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
    if (filter.sortBy != OrderSortBy.createdAt || filter.sortAsc) {
      chips.add('${filter.sortBy.label} ${filter.sortAsc ? '↑' : '↓'}');
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      color: AppColors.accent.withOpacity(0.06),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 14, color: AppColors.accent),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: chips
                    .map(
                      (c) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                        ),
                        child: Text(
                          c,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
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
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.close, size: 16, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
