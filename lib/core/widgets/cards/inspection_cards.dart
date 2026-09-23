import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/diagnostic.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';

class ReportListCard extends StatelessWidget {
  final DiagnosticReportSummary report;
  final VoidCallback? onTap;
  const ReportListCard({super.key, required this.report, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimens.paddingMD),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.colors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimens.radiusMD),
            ),
            child: Icon(
              Icons.description_outlined,
              color: context.colors.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.vehicle.plate, style: context.textStyles.h3),
                const SizedBox(height: 2),
                Text(
                  report.vehicle.displayName,
                  style: context.textStyles.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  report.template.name,
                  style: context.textStyles.caption.copyWith(
                    color: context.colors.accent,
                  ),
                ),
                Text(
                  fmt.format(report.createdAt),
                  style: context.textStyles.caption,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.colors.textHint),
        ],
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback? onTap;
  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: context.textStyles.captionMedium,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class TodaySummaryCard extends StatelessWidget {
  final int count;
  const TodaySummaryCard({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingLG),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.colors.brandSurface, context.colors.brandSurface2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusXL),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandSurface.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Өнөөдрийн үзлэг',
                  style: context.textStyles.caption.copyWith(
                    color: CarCareTheme.of(context).onAccent.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 6),
                Text('$count', style: context.textStyles.bigNumber),
                const SizedBox(height: 2),
                Text(
                  'машин',
                  style: context.textStyles.body.copyWith(
                    color: CarCareTheme.of(context).onAccent.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 110,
            height: 70,
            decoration: BoxDecoration(
              color: CarCareTheme.of(context).onAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppDimens.radiusMD),
            ),
            child: Icon(
              Icons.directions_car,
              size: 48,
              color: CarCareTheme.of(context).onAccent.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}
