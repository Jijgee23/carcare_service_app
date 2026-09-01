import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/models/diagnostic.dart';
import 'package:carcare_service/shared/widgets/common/common_widgets.dart';

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
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimens.radiusMD),
            ),
            child: const Icon(Icons.description_outlined, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.vehicle.plate, style: AppTextStyles.h3),
                const SizedBox(height: 2),
                Text(report.vehicle.displayName, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(
                  report.template.name,
                  style: AppTextStyles.caption.copyWith(color: AppColors.accent),
                ),
                Text(fmt.format(report.createdAt), style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textHint),
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
            style: AppTextStyles.captionMedium,
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
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusXL),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
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
                  style: AppTextStyles.caption.copyWith(color: Colors.white60),
                ),
                const SizedBox(height: 6),
                Text('$count', style: AppTextStyles.bigNumber),
                const SizedBox(height: 2),
                Text('машин', style: AppTextStyles.body.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          Container(
            width: 110,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppDimens.radiusMD),
            ),
            child: const Icon(Icons.directions_car, size: 48, color: Colors.white30),
          ),
        ],
      ),
    );
  }
}
