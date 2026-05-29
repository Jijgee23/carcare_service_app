import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../widgets/common/common_widgets.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _range = '7 хоног';

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<InspectionProvider>();
    final stats = prov.weeklyStats;
    final total = prov.totalGood + prov.totalWarning + prov.totalDanger;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тайлан'),
        actions: [
          IconButton(icon: const Icon(Icons.ios_share_outlined), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.paddingMD),
        children: [
          // Range picker
          Row(
            children: ['7 хоног', '1 сар', '3 сар'].map((r) {
              final active = r == _range;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _range = r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
          const SizedBox(height: 16),

          // Date range label
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text('Лэлэл    2024-05-14 – 2024-05-20',
                        style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: 20),

                // Donut chart + legend
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
                              sections: [
                                PieChartSectionData(
                                  color: AppColors.good,
                                  value: prov.totalGood.toDouble(),
                                  showTitle: false,
                                  radius: 28,
                                ),
                                PieChartSectionData(
                                  color: AppColors.warning,
                                  value: prov.totalWarning.toDouble(),
                                  showTitle: false,
                                  radius: 28,
                                ),
                                PieChartSectionData(
                                  color: AppColors.danger,
                                  value: prov.totalDanger.toDouble(),
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
                              Text('Нийт',
                                  style: AppTextStyles.caption),
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
                            color: AppColors.good,
                            label: 'Хэвийн',
                            count: prov.totalGood,
                            total: total,
                          ),
                          const SizedBox(height: 10),
                          _LegendRow(
                            color: AppColors.warning,
                            label: 'Анхаарах',
                            count: prov.totalWarning,
                            total: total,
                          ),
                          const SizedBox(height: 10),
                          _LegendRow(
                            color: AppColors.danger,
                            label: 'Засвар\nшаарддагатай',
                            count: prov.totalDanger,
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

          // Daily bar chart
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Өдөр бүрийн үзлэг', style: AppTextStyles.h3),
                const SizedBox(height: 20),
                SizedBox(
                  height: 160,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 20,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, _) {
                              final keys = stats.keys.toList();
                              final idx = value.toInt();
                              if (idx < 0 || idx >= keys.length) return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  keys[idx].substring(3),
                                  style: AppTextStyles.label.copyWith(fontSize: 10),
                                ),
                              );
                            },
                            reservedSize: 24,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 5,
                            getTitlesWidget: (v, _) => Text(
                              v.toInt().toString(),
                              style: AppTextStyles.label.copyWith(fontSize: 10),
                            ),
                            reservedSize: 28,
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 5,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AppColors.divider,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(stats.length, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: stats.values.elementAt(i).toDouble(),
                              color: AppColors.accent,
                              width: 22,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
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
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: AppTextStyles.caption),
        ),
        Text('$count ($pct%)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
