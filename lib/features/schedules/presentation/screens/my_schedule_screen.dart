import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/widgets/adaptive/async_state_view.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/features/schedules/data/schedule_repository.dart';
import 'package:carcare_service/features/schedules/domain/schedule.dart';
import 'package:carcare_service/features/schedules/domain/schedules_repository.dart';
import 'package:carcare_service/features/schedules/presentation/controllers/my_schedule_controller.dart';
import 'package:carcare_service/features/schedules/presentation/schedule_dates.dart';
import 'package:carcare_service/features/schedules/presentation/widgets/schedule_day_detail_sheet.dart';
import 'package:carcare_service/features/schedules/presentation/widgets/schedule_legend.dart';

const _kMonthNames = [
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
const _kWeekdayHeaders = ['Да', 'Мя', 'Лх', 'Пү', 'Ба', 'Бя', 'Ня'];

/// Real month calendar of the caller's own resolved schedule —
/// `GET /api/v1/me/schedule` — P6-F4. No permission gate: every
/// authenticated user may see their own schedule, and there is no write
/// affordance here at all (parity with `app/dashboard/my-schedule/
/// month-calendar.tsx`).
///
/// **Not wired to a route** — `P6-F5`'s. Intended route: `/my-schedule`,
/// reachable to any signed-in user.
class MyScheduleScreen extends StatelessWidget {
  const MyScheduleScreen({super.key, this.repository});

  final SchedulesRepository? repository;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => MyScheduleController(repo: repository)..load(),
    child: const _Body(),
  );
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MyScheduleController>();
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Миний хуваарь'),
        actions: [
          IconButton(
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _MonthNav(controller: controller),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final wd in _kWeekdayHeaders)
                  Expanded(
                    child: Center(
                      child: Text(wd, style: context.textStyles.caption),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: AsyncStateView<MySchedule>(
              state: controller.state,
              onRetry: controller.refresh,
              builder: (context, mySchedule) =>
                  _MonthGrid(month: controller.month, mySchedule: mySchedule),
            ),
          ),
          const Padding(padding: EdgeInsets.all(12), child: ScheduleLegend()),
        ],
      ),
    );
  }
}

class _MonthNav extends StatelessWidget {
  const _MonthNav({required this.controller});
  final MyScheduleController controller;

  @override
  Widget build(BuildContext context) {
    final m = controller.month;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            key: const ValueKey('my_schedule_prev_month'),
            icon: const Icon(Icons.chevron_left),
            onPressed: controller.prevMonth,
          ),
          Text(
            '${_kMonthNames[m.month - 1]} ${m.year}',
            style: context.textStyles.h3,
          ),
          IconButton(
            key: const ValueKey('my_schedule_next_month'),
            icon: const Icon(Icons.chevron_right),
            onPressed: controller.nextMonth,
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.mySchedule});
  final DateTime month;
  final MySchedule mySchedule;

  @override
  Widget build(BuildContext context) {
    final cells = monthGrid(month);
    return GridView.builder(
      key: const ValueKey('my_schedule_month_grid'),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.8,
      ),
      itemCount: cells.length,
      itemBuilder: (context, index) {
        final monthCell = cells[index];
        final dateStr = ymd(monthCell.date);
        final cell = mySchedule.cells[dateStr];
        return _DayTile(
          date: monthCell.date,
          inMonth: monthCell.inMonth,
          cell: cell,
        );
      },
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.date, required this.inMonth, this.cell});
  final DateTime date;
  final bool inMonth;
  final ScheduleCell? cell;

  @override
  Widget build(BuildContext context) {
    final working = cell?.working ?? false;
    return InkWell(
      key: ValueKey('my_schedule_day_${ymd(date)}'),
      onTap: () => ScheduleDayDetailSheet.show(context, date: date, cell: cell),
      child: Opacity(
        opacity: inMonth ? 1 : 0.35,
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: working ? context.colors.goodBg : context.colors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: context.colors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${date.day}', style: context.textStyles.caption),
              const Spacer(),
              if (cell != null)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: scheduleSourceColor(context, cell!.source),
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                working ? 'Ажил' : 'Амрах',
                style: const TextStyle(fontSize: 9),
                overflow: TextOverflow.ellipsis,
              ),
              if (working && cell != null && cell!.segments.isNotEmpty)
                Text(
                  cell!.segments.first.startTime ?? '',
                  style: const TextStyle(fontSize: 8),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
