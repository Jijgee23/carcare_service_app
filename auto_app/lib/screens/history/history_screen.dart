import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/cards/inspection_cards.dart';
import '../../widgets/common/common_widgets.dart';
import '../inspection/inspection_result_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<InspectionProvider>();

    final tabs = ['Бүгд', 'Хэвийн', 'Анхаарах', 'Засвар шаарддагатай'];
    final tabColors = [
      AppColors.textSecondary,
      AppColors.good,
      AppColors.warning,
      AppColors.danger,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Бүртгэлийн жагсаалт'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
          IconButton(icon: const Icon(Icons.sort), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Filter tabs
          Container(
            color: AppColors.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: List.generate(tabs.length, (i) {
                  final isActive = prov.currentTab == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => prov.setTab(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isActive ? tabColors[i].withOpacity(0.12) : AppColors.background,
                          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                          border: Border.all(
                            color: isActive ? tabColors[i] : AppColors.divider,
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          tabs[i],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isActive ? tabColors[i] : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // List
          Expanded(
            child: prov.filteredRecords.isEmpty
                ? const EmptyState(
                    message: 'Бүртгэл олдсонгүй',
                    icon: Icons.inventory_2_outlined,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppDimens.paddingMD),
                    itemCount: prov.filteredRecords.length,
                    itemBuilder: (_, i) {
                      final record = prov.filteredRecords[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InspectionListCard(
                          record: record,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InspectionResultScreen(record: record),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
