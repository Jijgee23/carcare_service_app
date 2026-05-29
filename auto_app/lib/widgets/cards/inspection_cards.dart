import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../common/common_widgets.dart';

// ─────────────────────────────────────────
//  INSPECTION LIST CARD
// ─────────────────────────────────────────
class InspectionListCard extends StatelessWidget {
  final InspectionRecord record;
  final VoidCallback? onTap;

  const InspectionListCard({super.key, required this.record, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimens.paddingMD),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left accent bar
          Container(
            width: 3,
            height: 56,
            decoration: BoxDecoration(
              color: record.overallStatus.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fmt.format(record.date), style: AppTextStyles.caption),
                const SizedBox(height: 3),
                Text(record.plateNumber, style: AppTextStyles.h3),
                const SizedBox(height: 2),
                Text(record.vehicleName,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          StatusBadge(status: record.overallStatus, compact: true),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  HOME QUICK ACTION CARD
// ─────────────────────────────────────────
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
          Text(label,
              style: AppTextStyles.captionMedium,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  TODAY SUMMARY CARD (dark navy card)
// ─────────────────────────────────────────
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
                Text('Өнөөдрийн үзлэг',
                    style: AppTextStyles.caption.copyWith(color: Colors.white60)),
                const SizedBox(height: 6),
                Text('$count', style: AppTextStyles.bigNumber),
                const SizedBox(height: 2),
                Text('машин',
                    style: AppTextStyles.body.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          // Car illustration placeholder
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

// ─────────────────────────────────────────
//  DETAIL ROW CARD (section item for detail screen)
// ─────────────────────────────────────────
class DetailItemCard extends StatelessWidget {
  final CheckItem item;

  const DetailItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(child: Text(item.name, style: AppTextStyles.bodyMedium)),
          StatusBadge(status: item.status, compact: true),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  PHOTO GRID
// ─────────────────────────────────────────
class PhotoGrid extends StatelessWidget {
  final List<String> urls;
  final VoidCallback? onAddTap;

  const PhotoGrid({super.key, required this.urls, this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Add button
          if (onAddTap != null)
            GestureDetector(
              onTap: onAddTap,
              child: Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                  border: Border.all(color: AppColors.divider, width: 1.5),
                ),
                child: const Icon(Icons.camera_alt_outlined,
                    size: 28, color: AppColors.textHint),
              ),
            ),
          ...urls.map(
            (url) => Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                color: AppColors.divider,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                child: Image.network(url, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, color: AppColors.textHint)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
