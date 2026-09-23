import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/features/reports/domain/report.dart';
import 'package:carcare_service/features/reports/presentation/widgets/report_widgets.dart';

/// The income trend chart — `<IncomeChart>` on the web, ported with
/// `fl_chart`'s `LineChart` (the app already draws bar charts with
/// `fl_chart` in the retired `AnalyticsScreen`; this is the same library,
/// a line series instead of bars). Shows the change-% pill the web renders
/// next to the section title.
class ReportIncomeChart extends StatelessWidget {
  final ReportIncome income;
  const ReportIncomeChart({super.key, required this.income});

  @override
  Widget build(BuildContext context) {
    final points = income.points;
    final changePct = income.changePct;
    final up = (changePct ?? 0) >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (changePct != null) _ChangePill(pct: changePct, up: up),
        if (changePct != null) const SizedBox(height: 10),
        if (points.isEmpty)
          const ReportSectionEmpty()
        else
          SizedBox(
            height: 160,
            child: _Chart(points: points, up: up),
          ),
      ],
    );
  }
}

class _ChangePill extends StatelessWidget {
  final double pct;
  final bool up;
  const _ChangePill({required this.pct, required this.up});

  @override
  Widget build(BuildContext context) {
    final color = up ? context.colors.accent : context.colors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${pct.abs().toStringAsFixed(1)}%',
            style: context.textStyles.captionMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  final List<ReportIncomePoint> points;
  final bool up;
  const _Chart({required this.points, required this.up});

  @override
  Widget build(BuildContext context) {
    final color = up ? context.colors.accent : context.colors.danger;
    final maxY = points.map((p) => p.value).fold<double>(
      0,
      (a, b) => b > a ? b : a,
    );
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].value),
    ];
    final labelStep = (points.length / 4).ceil().clamp(1, points.length);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.15,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 ||
                    idx >= points.length ||
                    idx % labelStep != 0) {
                  return const SizedBox.shrink();
                }
                final label = points[idx].label ?? '';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label, style: context.textStyles.caption),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }
}
