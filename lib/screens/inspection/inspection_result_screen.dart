import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/models/models.dart';
import 'package:carcare_service/widgets/common/common_widgets.dart';
import 'package:carcare_service/widgets/cards/inspection_cards.dart';

class InspectionResultScreen extends StatelessWidget {
  final InspectionRecord record;
  const InspectionResultScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Бүртгэлийн дэлгэрэнгүй'),
        actions: const [Padding(padding: EdgeInsets.only(right: 16), child: Icon(Icons.share_outlined, size: 20))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.paddingMD),
        children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: record.overallStatus.bgColor, borderRadius: BorderRadius.circular(AppDimens.radiusFull)),
                      child: Text(record.plateNumber, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: record.overallStatus.color)),
                    ),
                    const SizedBox(height: 6),
                    Text(record.vehicleName, style: AppTextStyles.caption),
                    Text('${fmt.format(record.date)} • ${record.mileage} км', style: AppTextStyles.caption),
                  ]),
                ),
                StatusBadge(status: record.overallStatus),
              ]),
              const SizedBox(height: 16),
              Text('Оношилгооны дүн', style: AppTextStyles.captionMedium),
              const SizedBox(height: 10),
              StatCounterRow(good: record.goodCount, warning: record.warningCount, danger: record.dangerCount),
            ]),
          ),
          const SizedBox(height: 14),

          ...record.sections.map((section) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AppCard(
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: Text(section.title, style: AppTextStyles.h3),
                      trailing: StatusBadge(
                        status: section.dangerCount > 0 ? CheckStatus.danger : section.warningCount > 0 ? CheckStatus.warning : CheckStatus.good,
                        compact: true,
                      ),
                      initiallyExpanded: section.dangerCount > 0 || section.warningCount > 0,
                      children: [
                        const Divider(height: 1),
                        ...section.items.map((item) => Column(children: [
                              DetailItemCard(item: item),
                              if (item != section.items.last) const Divider(height: 1),
                            ])),
                      ],
                    ),
                  ),
                ),
              )),

          if (record.photoUrls.isNotEmpty) ...[
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Зураг', style: AppTextStyles.h3),
                const SizedBox(height: 12),
                PhotoGrid(urls: record.photoUrls),
              ]),
            ),
            const SizedBox(height: 14),
          ],

          if (record.comment != null || record.recommendation != null)
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (record.comment != null) ...[
                  Text('Тайлбар', style: AppTextStyles.h3),
                  const SizedBox(height: 8),
                  Text(record.comment!, style: AppTextStyles.body),
                  const SizedBox(height: 14),
                ],
                if (record.recommendation != null) ...[
                  Text('Зөвлөмж', style: AppTextStyles.h3),
                  const SizedBox(height: 8),
                  Text(record.recommendation!, style: AppTextStyles.body),
                ],
              ]),
            ),

          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.share_outlined, size: 18), label: const Text('Хуваалцах'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.picture_as_pdf_outlined, size: 18), label: const Text('PDF татах'))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Засах'))),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
