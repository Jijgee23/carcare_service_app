import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/features/appointments/domain/appointment.dart';
import 'package:carcare_service/features/appointments/presentation/controllers/appointment_list_controller.dart';
import 'package:carcare_service/features/orders/presentation/feature_theme.dart';

/// List/selection widgets for the Appointments list screen — P2-F2.
/// Mirrors `order_list_widgets.dart`'s shape (phone card + tablet row +
/// selection bar) with a touch-native selection story: a long-press enters
/// selection mode, a plain tap toggles a row while active, and a "select
/// range" toolbar button arms a one-shot mode where the next tapped row
/// selects the contiguous run from the last-selected anchor — the touch
/// equivalent of the web's shift-click, never a drag/right-click
/// transliteration.

class AppointmentStatusChip extends StatelessWidget {
  const AppointmentStatusChip({super.key, required this.status});
  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: context.appointmentStatusBackground(status),
      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
      border: Border.all(
        color: context.appointmentStatusColor(status).withOpacity(0.35),
      ),
    ),
    child: Text(
      status.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: context.appointmentStatusColor(status),
      ),
    ),
  );
}

/// One row's selection interaction wiring, shared by the phone card and the
/// tablet row so both present the same touch affordances.
class AppointmentRowGestures extends StatelessWidget {
  const AppointmentRowGestures({
    super.key,
    required this.controller,
    required this.appointment,
    required this.onOpen,
    required this.child,
  });

  final AppointmentListController controller;
  final AppointmentSummary appointment;
  final VoidCallback onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (controller.rangeSelectArmed) {
          controller.applyRangeSelectTap(appointment.id);
        } else if (controller.selectionMode) {
          controller.toggleSelection(appointment.id);
        } else {
          onOpen();
        }
      },
      onLongPress: controller.selectionMode
          ? null
          : () => controller.enterSelectionMode(appointment.id),
      child: child,
    );
  }
}

class AppointmentPhoneCard extends StatelessWidget {
  const AppointmentPhoneCard({
    super.key,
    required this.appointment,
    required this.selected,
    required this.selectionMode,
  });

  final AppointmentSummary appointment;
  final bool selected;
  final bool selectionMode;

  static final _timeFmt = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final requestedAt = appointment.requestedAt;
    final v = appointment.displayVehicle;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: selected ? context.opsAccent.withOpacity(.08) : null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selectionMode)
              SizedBox(
                width: 44,
                child: Center(
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    color: selected ? context.opsAccent : context.opsTextHint,
                  ),
                ),
              )
            else
              Container(
                width: 60,
                color: context.appointmentStatusBackground(appointment.status),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      requestedAt == null ? '—' : _timeFmt.format(requestedAt),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.appointmentStatusColor(
                          appointment.status,
                        ),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            appointment.displayName,
                            style: context.textStyles.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: AppointmentStatusChip(
                            status: appointment.status,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      appointment.displayPhone,
                      style: context.textStyles.caption,
                    ),
                    if (v != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${v.plate ?? ''}  ${v.displayName}'.trim(),
                        style: context.textStyles.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (appointment.category?.name != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        appointment.category!.name!,
                        style: context.textStyles.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppointmentTableRow extends StatelessWidget {
  const AppointmentTableRow({
    super.key,
    required this.appointment,
    required this.selected,
    required this.selectionMode,
  });

  final AppointmentSummary appointment;
  final bool selected;
  final bool selectionMode;

  static final _timeFmt = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final requestedAt = appointment.requestedAt;
    return Material(
      color: selected ? context.opsAccent.withOpacity(.08) : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: selectionMode
                  ? Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      color: selected ? context.opsAccent : context.opsTextHint,
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        requestedAt == null
                            ? '—'
                            : _timeFmt.format(requestedAt),
                        style: context.textStyles.captionMedium.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                appointment.displayName,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.bodyMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                appointment.displayVehicle?.plate ?? '—',
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.captionMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                appointment.category?.name ?? '—',
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.caption,
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppointmentStatusChip(status: appointment.status),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saved quick filters — P5. "Миний" (assignee-scoped) is deliberately
/// omitted: the frozen `AppointmentListQuery` (P2-F1) has no assignee field
/// and the appointments API has no notion of a staff assignee at all (unlike
/// Orders), so there is nothing to filter by. Adding a client-only "my
/// appointments" filter would either silently do nothing or mislead staff
/// into thinking assignment exists here.
class AppointmentQuickFilterChips extends StatelessWidget {
  const AppointmentQuickFilterChips({super.key, required this.ctrl});

  final AppointmentListController ctrl;

  bool get _isToday {
    final d = ctrl.selectedDate;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool get _isOpenGroup => _setEquals(ctrl.statusGroup, const {
    AppointmentStatus.PENDING,
    AppointmentStatus.CONFIRMED,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _QuickFilterChip(
            key: const ValueKey('appointment_quick_filter_today'),
            label: 'Өнөөдөр',
            selected: _isToday,
            onTap: ctrl.goToday,
          ),
          _QuickFilterChip(
            key: const ValueKey('appointment_quick_filter_open'),
            label: 'Нээлттэй',
            selected: _isOpenGroup,
            onTap: () => ctrl.setStatusGroup(
              _isOpenGroup
                  ? null
                  : const {
                      AppointmentStatus.PENDING,
                      AppointmentStatus.CONFIRMED,
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    visualDensity: VisualDensity.compact,
  );
}

/// Minimal set-equality check for quick-filter chip highlighting, avoiding a
/// new dependency on `package:collection` for one comparison.
bool _setEquals<T>(Set<T>? a, Set<T> b) {
  if (a == null) return false;
  if (a.length != b.length) return false;
  return a.containsAll(b);
}

class AppointmentSelectionBar extends StatelessWidget {
  const AppointmentSelectionBar({
    super.key,
    required this.count,
    required this.rangeArmed,
    required this.canEdit,
    required this.onClear,
    required this.onSelectAll,
    required this.onArmRange,
    required this.onChangeCategory,
  });

  final int count;
  final bool rangeArmed;
  final bool canEdit;
  final VoidCallback onClear;
  final VoidCallback onSelectAll;
  final VoidCallback onArmRange;
  final VoidCallback onChangeCategory;

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
            const SizedBox(width: 8),
            if (rangeArmed)
              Chip(
                key: const ValueKey('range_select_armed_chip'),
                label: const Text('Мужийн төгсгөлийг товшино уу'),
                visualDensity: VisualDensity.compact,
              ),
            const Spacer(),
            IconButton(
              key: const ValueKey('appointment_select_all_button'),
              tooltip: 'Бүгдийг сонгох',
              onPressed: onSelectAll,
              icon: const Icon(Icons.select_all),
            ),
            IconButton(
              key: const ValueKey('appointment_range_select_button'),
              tooltip: 'Мужаар сонгох',
              onPressed: onArmRange,
              icon: const Icon(Icons.linear_scale_rounded),
            ),
            if (canEdit)
              IconButton(
                key: const ValueKey('appointment_bulk_category_button'),
                tooltip: 'Ажлын төрөл өөрчлөх',
                onPressed: onChangeCategory,
                icon: const Icon(Icons.category_outlined),
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

class AppointmentBulkFailureBanner extends StatelessWidget {
  const AppointmentBulkFailureBanner({super.key, required this.result});
  final AppointmentBulkResult result;

  @override
  Widget build(BuildContext context) => MaterialBanner(
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Зарим мөрийн үйлдэл амжилтгүй болсон'),
        for (final failure in result.failed)
          Text(
            '${failure.appointmentId}: ${failure.code} — ${failure.message}',
          ),
      ],
    ),
    leading: Icon(Icons.warning_amber_rounded, color: context.opsWarning),
    actions: const [SizedBox.shrink()],
  );
}

class AppointmentListFooter extends StatelessWidget {
  const AppointmentListFooter({
    super.key,
    required this.loadingMore,
    required this.loadMoreError,
    required this.hasNext,
    required this.total,
    required this.onLoadMore,
  });

  final bool loadingMore;
  final String? loadMoreError;
  final bool hasNext;
  final int total;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton.icon(
          onPressed: onLoadMore,
          icon: const Icon(Icons.refresh),
          label: Text('Дахин оролдох: $loadMoreError'),
        ),
      );
    }
    if (hasNext) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton.icon(
          onPressed: onLoadMore,
          icon: const Icon(Icons.expand_more),
          label: const Text('Дараагийн хуудас'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          'Нийт $total цаг захиалга',
          style: context.textStyles.caption,
        ),
      ),
    );
  }
}
