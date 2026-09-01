import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/models/appointment.dart';
import 'package:carcare_service/features/presentation/controllers/controllers.dart';
import 'package:carcare_service/features/presentation/pages/appointments/create_appointment_screen.dart';
import 'package:carcare_service/shared/widgets/branch_filter_bar.dart';
import 'package:carcare_service/shared/widgets/common/common_widgets.dart';
import 'package:carcare_service/shared/widgets/mn_date_picker.dart';

class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({super.key});

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  bool _loaded = false;
  bool _calendarMode = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AppointmentController>().loadAppointments();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AppointmentController>();
    final items = ctrl.filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Цаг захиалга'),

        actions: [
          IconButton(
            icon: Icon(_calendarMode ? Icons.view_list_rounded : Icons.calendar_month_rounded),
            tooltip: _calendarMode ? 'Жагсаалт' : 'Календар',
            onPressed: () => setState(() => _calendarMode = !_calendarMode),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: ctrl.loadAppointments),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreate(context, ctrl),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // ─── Date navigation (list mode) or calendar (calendar mode) ───
          if (_calendarMode) const _CalendarView() else _DateNav(ctrl: ctrl),

          // ─── Branch filter (owner only) ───────────────────────────────
          BranchFilterBar(
            selectedBranchId: ctrl.selectedBranchId,
            onChanged: ctrl.setBranch,
          ),

          // ─── Status filter chips ────────────────────────────────────────
          _StatusFilter(ctrl: ctrl),

          // ─── Appointment list ────────────────────────────────────────────
          Expanded(
            child: switch (ctrl.listState) {
              AsyncLoading() => const Center(child: CircularProgressIndicator()),
              AsyncError(:final error) => _ErrorView(
                message: error.display,
                onRetry: ctrl.loadAppointments,
              ),
              AsyncData() =>
                items.isEmpty
                    ? EmptyState(
                        message: ctrl.statusFilter != null
                            ? 'Энэ статустай цаг захиалга байхгүй'
                            : 'Энэ өдөр цаг захиалга байхгүй',
                        icon: Icons.event_busy_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: ctrl.loadAppointments,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppDimens.paddingMD),
                          itemCount: items.length,
                          itemBuilder: (_, i) => Padding(
                            key: ValueKey(items[i].id),
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _AppointmentCard(
                              appt: items[i],
                              onTap: () => _showDetail(context, items[i], ctrl),
                            ),
                          ),
                        ),
                      ),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, AppointmentController ctrl) async {
    final result = await Navigator.push<AppointmentSummary>(
      context,
      MaterialPageRoute(builder: (_) => const CreateAppointmentScreen()),
    );
    if (result != null && mounted) {
      ctrl.setDate(result.requestedAt);
    }
  }

  void _showDetail(BuildContext context, AppointmentSummary appt, AppointmentController ctrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(appt: appt, ctrl: ctrl),
    );
  }
}

// ─── Calendar view ────────────────────────────────────────────────────────────

class _CalendarView extends StatefulWidget {
  const _CalendarView();

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  late int _year;
  late int _month;

  static const _weekdays = ['Да', 'Мя', 'Лх', 'Пү', 'Ба', 'Бя', 'Ня'];
  static const _monthNames = [
    '1-р сар',
    '2-р сар',
    '3-р сар',
    '4-р сар',
    '5-р сар',
    '6-р сар',
    '7-р сар',
    '8-р сар',
    '9-р сар',
    '10-р сар',
    '11-р сар',
    '12-р сар',
  ];

  @override
  void initState() {
    super.initState();
    final d = context.read<AppointmentController>().selectedDate;
    _year = d.year;
    _month = d.month;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchCounts());
  }

  void _fetchCounts() {
    if (!mounted) return;
    context.read<AppointmentController>().loadMonthCounts(_year, _month);
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) {
        _year--;
        _month = 12;
      } else {
        _month--;
      }
    });
    _fetchCounts();
  }

  void _nextMonth() {
    setState(() {
      if (_month == 12) {
        _year++;
        _month = 1;
      } else {
        _month++;
      }
    });
    _fetchCounts();
  }

  List<DateTime?> _buildCells() {
    final firstDay = DateTime(_year, _month, 1);
    final startOffset = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final cells = <DateTime?>[
      ...List.filled(startOffset, null),
      for (int d = 1; d <= daysInMonth; d++) DateTime(_year, _month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    // watch so dots appear as soon as monthCounts updates
    final ctrl = context.watch<AppointmentController>();
    final cells = _buildCells();
    final selected = ctrl.selectedDate;
    final now = DateTime.now();

    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Column(
        children: [
          // ── Month header ──────────────────────────────────────────────
          Row(
            children: [
              IconButton.outlined(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: _prevMonth,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    final today = DateTime(now.year, now.month, now.day);
                    setState(() {
                      _year = today.year;
                      _month = today.month;
                    });
                    ctrl.setDate(today);
                    _fetchCounts();
                  },
                  child: Text(
                    '$_year оны ${_monthNames[_month - 1]}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              IconButton.outlined(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: _nextMonth,
              ),
            ],
          ),

          // ── Weekday header row ────────────────────────────────────────
          Row(
            children: _weekdays
                .map(
                  (l) => Expanded(
                    child: Text(
                      l,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),

          // ── Day grid ──────────────────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.82,
            ),
            itemCount: cells.length,
            itemBuilder: (_, i) {
              final day = cells[i];
              if (day == null) return const SizedBox();

              final isSelected =
                  day.year == selected.year &&
                  day.month == selected.month &&
                  day.day == selected.day;
              final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
              final isCurrentMonth = day.month == _month;
              final count = ctrl.monthCounts[_dateKey(day)] ?? 0;

              return GestureDetector(
                onTap: () => ctrl.setDate(day),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? AppColors.accent : Colors.transparent,
                          border: isToday && !isSelected
                              ? Border.all(color: Colors.white38, width: 1.5)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : isCurrentMonth
                                  ? Colors.white.withOpacity(0.85)
                                  : Colors.white24,
                              fontSize: 13,
                              fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      // ── Appointment dot ───────────────────────────────
                      SizedBox(
                        height: 5,
                        child: count > 0
                            ? Center(
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.8)
                                        : AppColors.accent.withOpacity(0.9),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Date navigation (list mode) ─────────────────────────────────────────────

class _DateNav extends StatelessWidget {
  final AppointmentController ctrl;
  const _DateNav({required this.ctrl});

  static final _weekdays = ['Да', 'Мя', 'Лх', 'Пү', 'Ба', 'Бя', 'Ня'];
  static final _fmt = DateFormat('yyyy/MM/dd');

  @override
  Widget build(BuildContext context) {
    final d = ctrl.selectedDate;
    final now = DateTime.now();
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    final weekday = _weekdays[d.weekday % 7];

    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          IconButton.outlined(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: ctrl.prevDay,
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _pickDate(context),
              child: Column(
                children: [
                  Text(
                    '${_fmt.format(d)} $weekday',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isToday)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Өнөөдөр',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton.outlined(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: ctrl.nextDay,
          ),
          if (!isToday)
            TextButton(
              onPressed: ctrl.goToday,
              child: const Text('Өнөөдөр', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showMnDatePicker(
      context,
      initialDate: ctrl.selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) ctrl.setDate(picked);
  }
}

// ─── Status filter ────────────────────────────────────────────────────────────

class _StatusFilter extends StatelessWidget {
  final AppointmentController ctrl;
  const _StatusFilter({required this.ctrl});

  static const _filters = <AppointmentStatus?>[
    null,
    AppointmentStatus.PENDING,
    AppointmentStatus.CONFIRMED,
    AppointmentStatus.REJECTED,
    AppointmentStatus.NO_SHOW,
    AppointmentStatus.CANCELLED,
  ];

  String _label(AppointmentStatus? s) => s?.label ?? 'Бүгд';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final f = _filters[i];
          final active = ctrl.statusFilter == f;
          final color = f?.color ?? AppColors.accent;
          return GestureDetector(
            onTap: () => ctrl.setStatusFilter(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: active ? color.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                border: Border.all(
                  color: active ? color : AppColors.divider,
                  width: active ? 1.5 : 1,
                ),
              ),
              child: Text(
                _label(f),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active ? color : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Appointment card ─────────────────────────────────────────────────────────

class _AppointmentCard extends StatelessWidget {
  final AppointmentSummary appt;
  final VoidCallback onTap;
  const _AppointmentCard({required this.appt, required this.onTap});

  static final _timeFmt = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final v = appt.displayVehicle;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Time sidebar ──────────────────────────────────────────────
            Container(
              width: 60,
              decoration: BoxDecoration(
                color: appt.status.bgColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppDimens.radiusMD),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _timeFmt.format(appt.requestedAt),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: appt.status.color,
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            appt.displayName,
                            style: AppTextStyles.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(status: appt.status),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 12, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(appt.displayPhone, style: AppTextStyles.caption),
                      ],
                    ),
                    if (v != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.directions_car_outlined,
                            size: 12,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${v.plate}  ${v.displayName}',
                            style: AppTextStyles.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                    if (appt.note?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        appt.note!,
                        style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Arrow ─────────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final AppointmentStatus status;
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
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: status.color),
      ),
    );
  }
}

// ─── Detail bottom sheet ──────────────────────────────────────────────────────

class _DetailSheet extends StatefulWidget {
  final AppointmentSummary appt;
  final AppointmentController ctrl;
  const _DetailSheet({required this.appt, required this.ctrl});

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  bool _loading = false;

  static final _dtFmt = DateFormat('yyyy-MM-dd HH:mm');

  Future<void> _doAction(AppointmentStatus status) async {
    setState(() => _loading = true);
    final ok = await widget.ctrl.updateStatus(widget.appt.id, status);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appt = widget.appt;
    final v = appt.displayVehicle;
    final bottom = MediaQuery.of(context).padding.bottom;
    final nexts = appt.status.nextStatuses;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Expanded(child: Text(_dtFmt.format(appt.requestedAt), style: AppTextStyles.h3)),
              _StatusChip(status: appt.status),
            ],
          ),
          const SizedBox(height: 16),

          // Info rows
          _Row(icon: Icons.person_outline, text: appt.displayName),
          _Row(icon: Icons.phone_outlined, text: appt.displayPhone),
          if (v != null)
            _Row(icon: Icons.directions_car_outlined, text: '${v.plate}  ${v.displayName}'),
          _Row(icon: Icons.storefront_outlined, text: appt.branch.name),
          if (appt.note?.isNotEmpty == true) _Row(icon: Icons.notes_outlined, text: appt.note!),
          if (appt.serviceOrder != null)
            _Row(
              icon: Icons.receipt_long_outlined,
              text: 'Захиалга #${appt.serviceOrder!.number}',
              color: AppColors.accent,
            ),

          // Action buttons
          if (nexts.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: 10,
                children: nexts
                    .map((s) => _ActionButton(status: s, onTap: () => _doAction(s)))
                    .toList(),
              ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _Row({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTextStyles.body.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final AppointmentStatus status;
  final VoidCallback onTap;
  const _ActionButton({required this.status, required this.onTap});

  IconData get _icon => switch (status) {
    AppointmentStatus.CONFIRMED => Icons.check_circle_outline_rounded,
    AppointmentStatus.REJECTED => Icons.cancel_outlined,
    AppointmentStatus.NO_SHOW => Icons.person_off_outlined,
    AppointmentStatus.CANCELLED => Icons.block_outlined,
    _ => Icons.arrow_forward,
  };

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(_icon, size: 16, color: status.color),
      label: Text(status.label, style: TextStyle(color: status.color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: status.color.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

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
