import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../widgets/cards/inspection_cards.dart';
import '../../widgets/common/common_widgets.dart';
import '../inspection/new_inspection_screen.dart';
import '../history/history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<InspectionProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Icon(Icons.menu),
        ),
        title: const Text('Нүүр'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications_none_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => await Future.delayed(const Duration(milliseconds: 600)),
        child: ListView(
          padding: const EdgeInsets.all(AppDimens.paddingMD),
          children: [
            // Today summary
            TodaySummaryCard(count: prov.totalToday),
            const SizedBox(height: 20),

            // Quick actions grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                QuickActionCard(
                  icon: Icons.add_circle_outline,
                  label: 'Шинэ бүртгэл',
                  iconColor: AppColors.accent,
                  bgColor: const Color(0xFFEEF3FF),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider(
                        create: (_) => NewInspectionProvider(),
                        child: const NewInspectionScreen(),
                      ),
                    ),
                  ),
                ),
                QuickActionCard(
                  icon: Icons.list_alt_outlined,
                  label: 'Бүртгэлийн жагсаалт',
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  ),
                ),
                QuickActionCard(
                  icon: Icons.bar_chart_outlined,
                  label: 'Тайлан',
                  iconColor: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFFFBEB),
                  onTap: () {},
                ),
                QuickActionCard(
                  icon: Icons.settings_outlined,
                  label: 'Тохиргоо',
                  iconColor: const Color(0xFF8B5CF6),
                  bgColor: const Color(0xFFF5F3FF),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent records
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Сүүлийн бүртгэлүүд', style: AppTextStyles.h3),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  ),
                  child: Text(
                    'Бүгдийг харах',
                    style: AppTextStyles.caption.copyWith(color: AppColors.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...prov.records.take(5).map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InspectionListCard(
                      record: r,
                      onTap: () => _openDetail(context, r.id),
                    ),
                  ),
                ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (_) => NewInspectionProvider(),
              child: const NewInspectionScreen(),
            ),
          ),
        ),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _openDetail(BuildContext context, String id) {
    // Navigate to detail — implemented in history screen
  }
}
