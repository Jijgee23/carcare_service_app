import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/widgets/adaptive/async_state_view.dart';
import 'package:carcare_service/core/widgets/adaptive/breakpoints.dart';
import 'package:carcare_service/features/appointments/domain/appointment.dart';
import 'package:carcare_service/features/appointments/presentation/controllers/calendar_controller.dart';
import 'package:carcare_service/features/appointments/presentation/widgets/calendar/calendar_agenda_list.dart';
import 'package:carcare_service/features/appointments/presentation/widgets/calendar/calendar_day_grid.dart';
import 'package:carcare_service/features/appointments/presentation/widgets/calendar/calendar_legend.dart';

final _dateFmt = DateFormat('yyyy.MM.dd (EEE)', 'mn');

/// Calendar surface — P2-F3. Tablet (>= [AdaptiveBreakpoints.compact]) shows
/// the day grid, phone shows the agenda; both render the same
/// [CalendarController] state built entirely from the server's
/// `GET /appointments/calendar` day-grid TRUTH model. This screen owns only
/// day/branch navigation chrome, the legend and loading/empty/error states —
/// never any schedule computation.
///
/// [onOpenBlock] and [onCreateAt] are left as optional callbacks rather than
/// hard-wired navigation: appointment detail (`P2-F5`) and staff
/// registration (`P2-F4`) are separate, not-yet-integrated slices, and
/// wiring `go_router` routes is `lib/app/router.dart`, a file this slice
/// does not own.
class AppointmentCalendarScreen extends StatefulWidget {
  const AppointmentCalendarScreen({
    super.key,
    required this.controller,
    this.onOpenBlock,
    this.onCreateAt,
  });

  final CalendarController controller;
  final void Function(CalendarBlock block)? onOpenBlock;
  final void Function(DateTime slotStart)? onCreateAt;

  @override
  State<AppointmentCalendarScreen> createState() =>
      _AppointmentCalendarScreenState();
}

class _AppointmentCalendarScreenState extends State<AppointmentCalendarScreen> {
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final theme = CarCareTheme.of(context);
        return Scaffold(
          backgroundColor: theme.shellBackground,
          appBar: AppBar(
            title: const Text('Хуанли'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: widget.controller.refresh,
              ),
            ],
          ),
          body: Column(
            children: [
              _DateNav(controller: widget.controller),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = AdaptiveBreakpoints.ofWidth(
                      constraints.maxWidth,
                    );
                    return AsyncStateView<CalendarDayModel>(
                      state: widget.controller.state,
                      error: (context, error) => _ErrorView(
                        message: error.display,
                        // The dedicated "no branch selected" error carries a
                        // prompt, not a transient failure — offering a retry
                        // button for it would just repeat the same error.
                        onRetry: error.code == 'NO_BRANCH_SELECTED'
                            ? null
                            : widget.controller.refresh,
                      ),
                      builder: (context, model) => Column(
                        children: [
                          if (model.legend.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimens.paddingMD,
                                vertical: AppDimens.paddingSM,
                              ),
                              child: CalendarLegend(entries: model.legend),
                            ),
                          if (model.hasCapacityOverflow)
                            _OverflowBanner(model: model),
                          Expanded(
                            child: size == AdaptiveSize.phone
                                ? CalendarAgendaList(
                                    key: ValueKey('agenda-${model.dateKey}'),
                                    model: model,
                                    onOpenBlock: widget.onOpenBlock,
                                    onCreateAt: widget.onCreateAt,
                                  )
                                : CalendarDayGrid(
                                    key: ValueKey('grid-${model.dateKey}'),
                                    model: model,
                                    onOpenBlock: widget.onOpenBlock,
                                    onCreateAt: widget.onCreateAt,
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DateNav extends StatelessWidget {
  const _DateNav({required this.controller});

  final CalendarController controller;

  @override
  Widget build(BuildContext context) {
    final theme = CarCareTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.panel,
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.paddingSM,
          vertical: AppDimens.paddingXS,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: controller.goToPreviousDay,
              tooltip: 'Өмнөх өдөр',
            ),
            Expanded(
              child: Center(
                child: InkWell(
                  onTap: controller.goToToday,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.paddingSM,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _safeDateLabel(controller.date),
                          style: context.textStyles.h3,
                        ),
                        _MonthCountDot(controller: controller),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: controller.goToNextDay,
              tooltip: 'Дараах өдөр',
            ),
          ],
        ),
      ),
    );
  }

  String _safeDateLabel(DateTime date) {
    try {
      return _dateFmt.format(date);
    } catch (_) {
      return DateFormat('yyyy.MM.dd').format(date);
    }
  }
}

/// The selected day's appointment count, sourced from
/// [CalendarController.monthCounts] (`getMonthCounts` — P2-F1b), never
/// re-derived from the day grid. Renders nothing for a day absent from the
/// map (zero appointments, or counts not yet loaded/failed to load) — a
/// missing entry is not "zero appointments, shown as a dot", it is simply
/// undecorated, matching the repository contract's "absent means zero"
/// rule and this feature's "dots are decoration, never truth" invariant.
class _MonthCountDot extends StatelessWidget {
  const _MonthCountDot({required this.controller});

  final CalendarController controller;

  @override
  Widget build(BuildContext context) {
    final count = controller.countFor(controller.date);
    if (count <= 0) return const SizedBox.shrink();
    final theme = CarCareTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Semantics(
        label: 'Энэ өдөр $count цаг захиалга',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: context.textStyles.caption.copyWith(
              color: theme.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _OverflowBanner extends StatelessWidget {
  const _OverflowBanner({required this.model});

  final CalendarDayModel model;

  @override
  Widget build(BuildContext context) {
    final theme = CarCareTheme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingMD,
        vertical: AppDimens.paddingXS,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingSM,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: theme.warn.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: theme.warn),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Энэ өдөр салбарын багтаамжаас хэтэрсэн цаг захиалга байна.',
              style: context.textStyles.caption.copyWith(color: theme.warn),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = CarCareTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded, size: 48, color: theme.mutedText2),
            const SizedBox(height: AppDimens.paddingSM),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textStyles.body,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppDimens.paddingMD),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Дахин оролдох'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
