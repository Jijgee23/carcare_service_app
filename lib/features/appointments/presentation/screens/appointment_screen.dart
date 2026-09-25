import 'package:carcare_service/core/widgets/filter_pill.dart';
import 'package:carcare_service/core/widgets/adaptive/tight_height_fallback.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/service_catalog.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/services/service_catalog_service.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/widgets/adaptive/breakpoints.dart';
import 'package:carcare_service/core/widgets/adaptive/record_views.dart';
import 'package:carcare_service/core/widgets/branch_filter_bar.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:carcare_service/core/widgets/date_picker/app_date_picker.dart';
import 'package:carcare_service/features/appointments/domain/appointment.dart';
import 'package:carcare_service/features/appointments/presentation/controllers/appointment_controller.dart';
import 'package:carcare_service/features/appointments/presentation/controllers/appointment_list_controller.dart';
import 'package:carcare_service/features/appointments/presentation/controllers/calendar_controller.dart';
import 'package:carcare_service/features/appointments/presentation/screens/appointment_calendar_screen.dart';
import 'package:carcare_service/features/appointments/presentation/screens/appointment_detail_screen.dart';
import 'package:carcare_service/features/appointments/presentation/screens/create_appointment_screen.dart';
import 'package:carcare_service/features/appointments/presentation/widgets/appointment_list_widgets.dart';
import 'package:carcare_service/features/orders/presentation/feature_theme.dart';
import 'package:carcare_service/features/shell/presentation/controllers/working_branch_controller.dart';

/// Appointments list screen — P2-F2.
///
/// Server-side status/branch/date filtering with generation-guarded
/// list/refresh/load-more (see `AppointmentListController`). Selection is
/// touch-native: long-press enters selection mode, a plain tap toggles a
/// row, and a toolbar "select range" button arms a one-shot pick-the-other-
/// end interaction — deliberately not a transliteration of the web's
/// mouse-drag/right-click range selection. Bulk category shows per-row
/// partial failures then reloads authoritatively from the server; it never
/// patches local rows from the bulk response.
///
/// A permission check here only hides/disables UI — it is not access
/// control. The server independently enforces `appointments.view` /
/// `appointments.edit` on every read and mutation.
///
/// The pre-programme embedded month-calendar toggle that used to live in
/// this screen is removed: its data source (`getMonthCounts`) has no
/// equivalent in the P2-F1 frozen contract, and the real calendar surface is
/// P2-F3's `appointment_calendar_screen.dart`, running in parallel. Owning a
/// second, unsupported calendar view here would both fail to compile against
/// the frozen contract and duplicate P2-F3's scope.
class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({super.key, this.user});

  final User? user;

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  // Long-lived, owned by this State and disposed in `dispose()` below — not
  // a short-lived dialog-scoped controller. That distinction matters: a
  // dialog-scoped `TextEditingController` disposed by an awaiting caller
  // caused a real `TextEditingController was used after being disposed`
  // crash elsewhere in this repo (see `create_appointment_controller.dart`
  // history). This one lives exactly as long as the screen does.
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _didLoad = false;

  // Tablet table sort state — kept in this State (not the controller)
  // exactly like `OrderListScreen`'s equivalent: it is screen-local
  // presentation state, not list/filter truth, and this State already
  // survives branch/tab switches under the shell's `StatefulShellRoute`
  // (each branch keeps its own offstage Navigator), so it needs no extra
  // persistence plumbing here.
  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.extentAfter < 500 && mounted) {
        context.read<AppointmentController>().loadMore();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      final controller = context.read<AppointmentController>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.loadAppointments();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  User? get _user => widget.user ?? Authenticator.user;

  bool _canView(User? user) =>
      user?.isOwner == true ||
      user?.role?.permissions.contains('appointments.view') == true;

  bool _canCreate(User? user) =>
      user?.isOwner == true ||
      user?.role?.permissions.contains('appointments.create') == true;

  bool _canEdit(User? user) =>
      user?.isOwner == true ||
      user?.role?.permissions.contains('appointments.edit') == true;

  Future<void> _openCreate(
    BuildContext context,
    AppointmentController ctrl,
  ) async {
    final result = await Navigator.push<AppointmentSummary>(
      context,
      MaterialPageRoute(builder: (_) => const CreateAppointmentScreen()),
    );
    if (result != null && mounted) {
      final requestedAt = result.requestedAt;
      if (requestedAt != null) {
        await ctrl.setDate(requestedAt);
      } else {
        await ctrl.refresh();
      }
    }
  }

  Future<void> _openCalendar(
    BuildContext context,
    AppointmentController ctrl,
    User? user,
  ) async {
    // Explicit list filter → the shell's working branch → the home branch.
    // The working branch must beat the home branch: calendar requests carry
    // `X-Working-Branch`, and a conflicting `branchId` is a 422. A
    // tenant-wide/ALL selection with no home branch leaves this null, and
    // the calendar renders its dedicated no-branch state.
    final branchId =
        ctrl.selectedBranchId ?? workingBranchIdOf(context) ?? user?.branchId;

    final calendarController = CalendarController(
      repo: ctrl.repository,
      branchId: branchId,
      date: ctrl.selectedDate,
    );
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AppointmentCalendarScreen(
          controller: calendarController,
          onOpenBlock: (block) =>
              _openCalendarBlock(context, ctrl, block, user),
          onCreateAt: _canCreate(user)
              ? (slotStart) async {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CreateAppointmentScreen(initialDate: slotStart),
                    ),
                  );
                  if (context.mounted) await calendarController.refresh();
                }
              : null,
        ),
      ),
    );
    calendarController.dispose();
    if (mounted) await ctrl.refresh();
  }

  void _openCalendarBlock(
    BuildContext context,
    AppointmentController ctrl,
    CalendarBlock block,
    User? user,
  ) {
    AppointmentSummary? appointment;
    for (final item in ctrl.filtered) {
      if (item.id == block.appointmentId) {
        appointment = item;
        break;
      }
    }
    if (appointment == null) {
      messageWarning('Энэ цаг захиалгын дэлгэрэнгүйг жагсаалтаас олсонгүй.');
      return;
    }
    _showDetailFor(context, appointment, ctrl, user);
  }

  Future<void> _changeBulkCategory(AppointmentListController ctrl) async {
    final categoriesResult = await ServiceCatalogService.getLaborCategories();
    if (!mounted) return;
    if (categoriesResult case Err(:final error)) {
      messageError(error.display);
      return;
    }
    final categories = (categoriesResult as Ok<List<LaborCategory>>).value;
    if (categories.isEmpty) {
      messageError('Ажлын төрөл тохируулаагүй байна');
      return;
    }
    final picked = await showModalBottomSheet<LaborCategory>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final category in categories)
              ListTile(
                title: Text(category.name),
                onTap: () => Navigator.pop(sheetContext, category),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final result = await ctrl.bulkChangeCategory(picked.id);
    if (result == null && mounted) {
      // A request-level failure already surfaced via `messageError` inside
      // the controller's underlying repository call chain is not guaranteed
      // here (bulkChangeCategory swallows request-level Err by returning
      // null); tell the user explicitly rather than silently doing nothing.
      messageError('Ажлын төрөл өөрчлөх хүсэлт амжилтгүй боллоо');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AppointmentController>();
    final user = _user;
    if (!_canView(user)) {
      return const Scaffold(
        body: Center(child: Text('Цаг захиалга харах эрхгүй')),
      );
    }

    final state = ctrl.listState;
    return Scaffold(
      backgroundColor: context.opsBackground,
      appBar: AppBar(
        title: const Text('Цаг захиалга'),
        actions: [
          IconButton(
            key: const ValueKey('appointments_calendar_button'),
            tooltip: 'Хуанли',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => _openCalendar(context, ctrl, user),
          ),
          IconButton(
            tooltip: 'Шинэчлэх',
            icon: const Icon(Icons.refresh),
            onPressed: ctrl.refresh,
          ),
        ],
      ),
      floatingActionButton: _canCreate(user)
          ? FloatingActionButton(
              onPressed: () => _openCreate(context, ctrl),
              backgroundColor: context.opsAccent,
              child: Icon(Icons.add, color: context.opsTextOnDark),
            )
          : null,
      bottomNavigationBar: ctrl.selectedCount == 0
          ? null
          : AppointmentSelectionBar(
              count: ctrl.selectedCount,
              rangeArmed: ctrl.rangeSelectArmed,
              canEdit: _canEdit(user),
              onClear: ctrl.clearSelection,
              onSelectAll: ctrl.selectAllVisible,
              onArmRange: ctrl.armRangeSelect,
              onChangeCategory: () => _changeBulkCategory(ctrl),
            ),
      body: TightHeightFallback(
        controls: [
          _DateNav(ctrl: ctrl),
          _SearchBar(
            controller: _searchController,
            onChanged: ctrl.setQuery,
            onClear: () {
              _searchController.clear();
              ctrl.setQuery('');
            },
          ),
          // Same rule as the order list: the header's working branch is the
          // scope; this legacy filter only makes sense while it is "all".
          if (_showLegacyBranchFilter(context))
            BranchFilterBar(
              selectedBranchId: ctrl.selectedBranchId,
              onChanged: ctrl.setBranch,
            ),
          _StatusFilter(ctrl: ctrl),
          AppointmentQuickFilterChips(ctrl: ctrl),
          if (ctrl.lastBulkResult?.failed.isNotEmpty == true)
            AppointmentBulkFailureBanner(result: ctrl.lastBulkResult!),
        ],
        results: _buildResults(ctrl, state, user),
      ),
    );
  }

  bool _showLegacyBranchFilter(BuildContext context) {
    try {
      return context.watch<WorkingBranchController>().isAllBranches;
    } on ProviderNotFoundException {
      // Standalone tests and legacy embeddings have no working-branch
      // provider. Preserve their existing owner-only filter in that case.
      return true;
    }
  }

  Widget _buildResults(
    AppointmentController ctrl,
    AsyncValue<List<AppointmentSummary>> state,
    User? user,
  ) {
    return switch (state) {
      AsyncLoading() => const Center(child: CircularProgressIndicator()),
      AsyncError(:final error) => _ErrorView(
        message: error.display,
        onRetry: ctrl.refresh,
      ),
      AsyncData(:final value) when value.isEmpty => EmptyState(
        message: ctrl.statusFilter != null
            ? 'Энэ статустай цаг захиалга байхгүй'
            : 'Энэ өдөр цаг захиалга байхгүй',
        icon: Icons.event_busy_outlined,
      ),
      AsyncData(:final value) => LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxWidth >= AdaptiveBreakpoints.expanded
            ? _TabletAppointmentsView(
                ctrl: ctrl,
                appointments: value,
                user: user,
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                onSort: _onSort,
              )
            : _PhoneAppointments(
                ctrl: ctrl,
                appointments: value,
                scroll: _scrollController,
                user: user,
              ),
      ),
    };
  }

  void _onSort(int index) {
    setState(() {
      if (_sortColumnIndex == index) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = index;
        _sortAscending = true;
      }
    });
  }
}

// ─── Date navigation ────────────────────────────────────────────────────────

class _DateNav extends StatelessWidget {
  final AppointmentListController ctrl;
  const _DateNav({required this.ctrl});

  static final _weekdays = ['Да', 'Мя', 'Лх', 'Пү', 'Ба', 'Бя', 'Ня'];
  static final _fmt = DateFormat('yyyy/MM/dd');

  @override
  Widget build(BuildContext context) {
    final d = ctrl.selectedDate;
    final now = DateTime.now();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    final weekday = _weekdays[d.weekday % 7];

    return Container(
      color: context.opsPrimary,
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          IconButton.outlined(
            tooltip: 'Өмнөх өдөр',
            icon: Icon(Icons.chevron_left, color: context.opsTextOnDark),
            onPressed: ctrl.prevDay,
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _pickDate(context),
              child: Column(
                children: [
                  Text(
                    '${_fmt.format(d)} $weekday',
                    style: TextStyle(
                      color: context.opsTextOnDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isToday)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: context.opsTextOnDark.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Өнөөдөр',
                        style: TextStyle(
                          color: context.opsTextOnDark.withOpacity(0.7),
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton.outlined(
            tooltip: 'Дараах өдөр',
            icon: Icon(Icons.chevron_right, color: context.opsTextOnDark),
            onPressed: ctrl.nextDay,
          ),
          if (!isToday)
            TextButton(
              onPressed: ctrl.goToday,
              child: Text(
                'Өнөөдөр',
                style: TextStyle(
                  color: context.opsTextOnDark.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await AppDatePicker.single(
      context,
      initial: ctrl.selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) await ctrl.setDate(picked);
  }
}

// ─── Search ─────────────────────────────────────────────────────────────────
//
// Debounce and the stale-response generation guard both live in
// `AppointmentListController.setQuery`/`loadAppointments` — this widget only
// forwards `onChanged`, matching `OrderListScreen`'s `_SearchBar`.

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
    color: context.opsPrimary,
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: context.opsTextOnDark),
      decoration: InputDecoration(
        hintText: 'Үйлчлүүлэгч, утас, тэмдэглэл...',
        prefixIcon: Icon(
          Icons.search,
          color: context.opsTextOnDark.withOpacity(.6),
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Хайлт цэвэрлэх',
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
  );
}

// ─── Status filter ────────────────────────────────────────────────────────────

class _StatusFilter extends StatelessWidget {
  final AppointmentListController ctrl;
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
      color: context.opsSurface,
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = _filters[i];
          return FilterPill(
            label: _label(f),
            selected: ctrl.statusFilter == f,
            color: f == null ? null : context.appointmentStatusColor(f),
            onTap: () => ctrl.setStatusFilter(f),
          );
        },
      ),
    );
  }
}

// ─── Phone / tablet lists ───────────────────────────────────────────────────

class _PhoneAppointments extends StatelessWidget {
  const _PhoneAppointments({
    required this.ctrl,
    required this.appointments,
    required this.scroll,
    required this.user,
  });
  final AppointmentController ctrl;
  final List<AppointmentSummary> appointments;
  final ScrollController scroll;
  final User? user;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: ctrl.refresh,
    child: ListView.separated(
      controller: scroll,
      padding: const EdgeInsets.all(AppDimens.paddingMD),
      itemCount: appointments.length + 1,
      separatorBuilder: (_, index) =>
          SizedBox(height: index == appointments.length - 1 ? 4 : 10),
      itemBuilder: (_, index) {
        if (index == appointments.length) {
          return AppointmentListFooter(
            loadingMore: ctrl.loadingMore,
            loadMoreError: ctrl.loadMoreError?.display,
            hasNext: ctrl.hasNext,
            total: ctrl.total,
            onLoadMore: ctrl.loadMore,
          );
        }
        final appt = appointments[index];
        return AppointmentRowGestures(
          controller: ctrl,
          appointment: appt,
          onOpen: () => _showDetailFor(context, appt, ctrl, user),
          child: AppointmentPhoneCard(
            appointment: appt,
            selected: ctrl.isSelected(appt.id),
            selectionMode: ctrl.selectionMode,
          ),
        );
      },
    ),
  );
}

/// Tablet (>= [AdaptiveBreakpoints.expanded]) all-appointments view — P5.
/// Sortable [DataTableView] list. The appointment detail always opens as its
/// own full-screen route (`_showDetailFor`, the same push phones use) rather
/// than an embedded side pane — small tablets (~600-900dp) are this app's
/// primary device, and a two-pane split left too little room for the detail
/// content at that width. Row selection/bulk-action gestures are preserved:
/// a long-press still enters selection mode and a plain tap opens the
/// detail route (or toggles selection while selection mode is on).
class _TabletAppointmentsView extends StatelessWidget {
  const _TabletAppointmentsView({
    required this.ctrl,
    required this.appointments,
    required this.user,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
  });

  final AppointmentController ctrl;
  final List<AppointmentSummary> appointments;
  final User? user;
  final int? sortColumnIndex;
  final bool sortAscending;
  final ValueChanged<int> onSort;

  static final _timeFmt = DateFormat('HH:mm');

  List<AppointmentSummary> _sorted() {
    if (sortColumnIndex == null) return appointments;
    final sorted = [...appointments];
    int cmp(AppointmentSummary a, AppointmentSummary b) =>
        switch (sortColumnIndex) {
          0 => (a.requestedAt ?? DateTime(0)).compareTo(
            b.requestedAt ?? DateTime(0),
          ),
          1 => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
          2 => (a.displayVehicle?.plate ?? '').compareTo(
            b.displayVehicle?.plate ?? '',
          ),
          3 => (a.category?.name ?? '').compareTo(b.category?.name ?? ''),
          4 => a.status.label.compareTo(b.status.label),
          _ => 0,
        };
    sorted.sort(cmp);
    if (!sortAscending) return sorted.reversed.toList(growable: false);
    return sorted;
  }

  List<RecordColumn<AppointmentSummary>> get _columns => [
    RecordColumn(
      label: 'Цаг',
      flex: 1,
      builder: (context, appt) => Text(
        appt.requestedAt == null ? '—' : _timeFmt.format(appt.requestedAt!),
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      ),
    ),
    RecordColumn(
      label: 'Үйлчлүүлэгч',
      flex: 3,
      builder: (context, appt) =>
          Text(appt.displayName, overflow: TextOverflow.ellipsis),
    ),
    RecordColumn(
      label: 'Машин',
      flex: 2,
      builder: (context, appt) => Text(
        appt.displayVehicle?.plate ?? '—',
        overflow: TextOverflow.ellipsis,
      ),
    ),
    RecordColumn(
      label: 'Ажлын төрөл',
      flex: 2,
      builder: (context, appt) =>
          Text(appt.category?.name ?? '—', overflow: TextOverflow.ellipsis),
    ),
    RecordColumn(
      label: 'Төлөв',
      flex: 2,
      builder: (context, appt) => AppointmentStatusChip(status: appt.status),
    ),
  ];

  Widget _buildTable(BuildContext context) {
    final sorted = _sorted();
    return RefreshIndicator(
      onRefresh: ctrl.refresh,
      child: Column(
        children: [
          Expanded(
            child: DataTableView<AppointmentSummary>(
              records: sorted,
              columns: _columns,
              forceTable: true,
              sortColumnIndex: sortColumnIndex,
              sortAscending: sortAscending,
              onSort: onSort,
              onTap: (appt) {
                if (ctrl.rangeSelectArmed) {
                  ctrl.applyRangeSelectTap(appt.id);
                } else if (ctrl.selectionMode) {
                  ctrl.toggleSelection(appt.id);
                } else {
                  _showDetailFor(context, appt, ctrl, user);
                }
              },
              onLongPress: ctrl.selectionMode
                  ? null
                  : (appt) => ctrl.enterSelectionMode(appt.id),
              empty: EmptyState(
                message: 'Энэ өдөр цаг захиалга байхгүй',
                icon: Icons.event_busy_outlined,
              ),
            ),
          ),
          AppointmentListFooter(
            loadingMore: ctrl.loadingMore,
            loadMoreError: ctrl.loadMoreError?.display,
            hasNext: ctrl.hasNext,
            total: ctrl.total,
            onLoadMore: ctrl.loadMore,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _buildTable(context);
}

void _showDetailFor(
  BuildContext context,
  AppointmentSummary appt,
  AppointmentController ctrl,
  User? user,
) {
  unawaited(
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AppointmentDetailScreen(
          initial: appt,
          repo: ctrl.repository,
          user: user,
        ),
      ),
    ).then((_) {
      if (context.mounted) unawaited(ctrl.refresh());
    }),
  );
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
    final ok = await widget.ctrl.transition(widget.appt.id, status);
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
      decoration: BoxDecoration(
        color: context.opsSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.opsDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  appt.requestedAt == null
                      ? '—'
                      : _dtFmt.format(appt.requestedAt!),
                  style: context.textStyles.h3,
                ),
              ),
              AppointmentStatusChip(status: appt.status),
            ],
          ),
          const SizedBox(height: 16),
          _Row(icon: Icons.person_outline, text: appt.displayName),
          _Row(icon: Icons.phone_outlined, text: appt.displayPhone),
          if (v != null)
            _Row(
              icon: Icons.directions_car_outlined,
              text: '${v.plate ?? ''}  ${v.displayName}'.trim(),
            ),
          if (appt.branch?.name != null)
            _Row(icon: Icons.storefront_outlined, text: appt.branch!.name!),
          if (appt.note?.isNotEmpty == true)
            _Row(icon: Icons.notes_outlined, text: appt.note!),
          if (appt.serviceOrder != null)
            _Row(
              icon: Icons.receipt_long_outlined,
              text: 'Захиалга #${appt.serviceOrder!.number}',
              color: context.opsAccent,
            ),
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
                    .map(
                      (s) =>
                          _ActionButton(status: s, onTap: () => _doAction(s)),
                    )
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
          Icon(icon, size: 15, color: color ?? context.opsTextSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.textStyles.body.copyWith(color: color),
            ),
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
      icon: Icon(
        _icon,
        size: 16,
        color: context.appointmentStatusColor(status),
      ),
      label: Text(
        status.label,
        style: TextStyle(color: context.appointmentStatusColor(status)),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: context.appointmentStatusColor(status).withOpacity(0.5),
        ),
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
            Icon(Icons.error_outline, size: 48, color: context.opsDanger),
            const SizedBox(height: 12),
            Text(
              message,
              style: context.textStyles.body,
              textAlign: TextAlign.center,
            ),
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
