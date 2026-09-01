import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/models/diagnostic.dart';
import 'package:carcare_service/features/presentation/controllers/controllers.dart';
import 'package:carcare_service/shared/widgets/common/common_widgets.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _range = '7 хоног';

  int get _rangeDays => _range == '7 хоног'
      ? 7
      : _range == '1 сар'
      ? 30
      : 90;

  List<DiagnosticReportSummary> _filterByRange(List<DiagnosticReportSummary> all) {
    final cutoff = DateTime.now().subtract(Duration(days: _rangeDays));
    return all.where((r) => r.createdAt.isAfter(cutoff)).toList();
  }

  // Бүх өдрийг 0-ээс эхлүүлж, filtered-ийн өгөгдлөөр дүүргэнэ
  Map<String, int> _dailyStats(List<DiagnosticReportSummary> filtered) {
    final result = <String, int>{};
    final now = DateTime.now();
    for (int i = _rangeDays - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = _dayKey(d);
      result[key] = 0;
    }
    for (final r in filtered) {
      final key = _dayKey(r.createdAt);
      if (result.containsKey(key)) result[key] = result[key]! + 1;
    }
    return result;
  }

  String _dayKey(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  // Template төрлөөр бүлэглэх
  Map<String, int> _typeStats(List<DiagnosticReportSummary> filtered) {
    final result = <String, int>{};
    for (final r in filtered) {
      final label = r.template.type.label;
      result[label] = (result[label] ?? 0) + 1;
    }
    return result;
  }

  // Өнөөдөр / өчигдөр
  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  bool _isYesterday(DateTime dt) {
    final yest = DateTime.now().subtract(const Duration(days: 1));
    return dt.year == yest.year && dt.month == yest.month && dt.day == yest.day;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<InspectionController>();
    final filtered = _filterByRange(prov.reports);
    final dailyStats = _dailyStats(filtered);
    final typeStats = _typeStats(filtered);

    final total = filtered.length;
    final todayCount = filtered.where((r) => _isToday(r.createdAt)).length;
    final yesterdayCount = filtered.where((r) => _isYesterday(r.createdAt)).length;

    final now = DateTime.now();
    final rangeStart = now.subtract(Duration(days: _rangeDays - 1));
    final dateFmt = DateFormat('yyyy-MM-dd');
    final rangeLabel = '${dateFmt.format(rangeStart)} – ${dateFmt.format(now)}';

    // Bar chart: too many bars → skip some labels
    final labelStep = _rangeDays <= 7
        ? 1
        : _rangeDays <= 30
        ? 5
        : 15;
    final maxY = dailyStats.values.isEmpty
        ? 5.0
        : (dailyStats.values.reduce((a, b) => a > b ? a : b) + 2).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тайлан'),
        actions: [
          if (prov.loading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(icon: const Icon(Icons.refresh), onPressed: prov.loadReports),
        ],
      ),
      body: prov.loading && prov.reports.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppDimens.paddingMD),
              children: [
                // ─── Range selector ────────────────────────────────────────────
                Row(
                  children: ['7 хоног', '1 сар', '3 сар'].map((r) {
                    final active = r == _range;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _range = r),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: active ? AppColors.accent : AppColors.surface,
                            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                            border: Border.all(
                              color: active ? AppColors.accent : AppColors.divider,
                            ),
                          ),
                          child: Text(
                            r,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: active ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // ─── Summary card ──────────────────────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(rangeLabel, style: AppTextStyles.caption),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 36,
                                    sections: total == 0
                                        ? [
                                            PieChartSectionData(
                                              color: AppColors.divider,
                                              value: 1,
                                              showTitle: false,
                                              radius: 28,
                                            ),
                                          ]
                                        : [
                                            PieChartSectionData(
                                              color: AppColors.accent,
                                              value: total.toDouble(),
                                              showTitle: false,
                                              radius: 28,
                                            ),
                                          ],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$total',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text('Нийт', style: AppTextStyles.caption),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _LegendRow(
                                  color: AppColors.accent,
                                  label: 'Нийт',
                                  count: total,
                                  total: total,
                                ),
                                const SizedBox(height: 8),
                                _LegendRow(
                                  color: AppColors.good,
                                  label: 'Өнөөдөр',
                                  count: todayCount,
                                  total: total,
                                ),
                                const SizedBox(height: 8),
                                _LegendRow(
                                  color: AppColors.warning,
                                  label: 'Өчигдөр',
                                  count: yesterdayCount,
                                  total: total,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ─── Daily bar chart ───────────────────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Өдөр бүрийн үзлэг', style: AppTextStyles.h3),
                      const SizedBox(height: 4),
                      Text(rangeLabel, style: AppTextStyles.caption),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 160,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxY,
                            barTouchData: BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 24,
                                  getTitlesWidget: (value, _) {
                                    final idx = value.toInt();
                                    if (idx % labelStep != 0) return const SizedBox.shrink();
                                    final keys = dailyStats.keys.toList();
                                    if (idx < 0 || idx >= keys.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        keys[idx],
                                        style: AppTextStyles.label.copyWith(fontSize: 9),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: maxY <= 4 ? 1 : 2,
                                  reservedSize: 28,
                                  getTitlesWidget: (v, _) => Text(
                                    v.toInt().toString(),
                                    style: AppTextStyles.label.copyWith(fontSize: 10),
                                  ),
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: maxY <= 4 ? 1 : 2,
                              getDrawingHorizontalLine: (_) =>
                                  const FlLine(color: AppColors.divider, strokeWidth: 1),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: List.generate(
                              dailyStats.length,
                              (i) => BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: dailyStats.values.elementAt(i).toDouble(),
                                    color: dailyStats.values.elementAt(i) > 0
                                        ? AppColors.accent
                                        : AppColors.divider,
                                    width: _rangeDays <= 7
                                        ? 22
                                        : _rangeDays <= 30
                                        ? 8
                                        : 4,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ─── Template type breakdown ───────────────────────────────────
                if (typeStats.isNotEmpty)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Загварын төрлөөр', style: AppTextStyles.h3),
                        const SizedBox(height: 14),
                        ...typeStats.entries.map((e) {
                          final pct = total > 0 ? e.value / total : 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(e.key, style: AppTextStyles.captionMedium),
                                    Text(
                                      '${e.value} (${(pct * 100).round()}%)',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 8,
                                    backgroundColor: AppColors.divider,
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      AppColors.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final int total;
  const _LegendRow({
    required this.color,
    required this.label,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).round() : 0;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: AppTextStyles.caption)),
        Text(
          '$count ($pct%)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}
