import 'package:carcare_service/features/presentation/controllers/notification_controller.dart';
import 'package:carcare_service/features/presentation/pages/appointments/appointment_screen.dart';
import 'package:carcare_service/features/presentation/pages/notifications/notification_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/presentation/controllers/controllers.dart';
import 'package:carcare_service/features/presentation/pages/history/history_screen.dart';
import 'package:carcare_service/features/presentation/pages/inspection/new_inspection_screen.dart';
import 'package:carcare_service/features/presentation/pages/inspection/report_detail_screen.dart';
import 'package:carcare_service/features/presentation/pages/orders/order_list_screen.dart';
import 'package:carcare_service/features/presentation/pages/search/search_screen.dart';
import 'package:carcare_service/features/presentation/pages/services/service_list_screen.dart';
import 'package:carcare_service/shared/widgets/cards/inspection_cards.dart';
import 'package:carcare_service/shared/widgets/common/common_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InspectionController>().loadReports();
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Өглөөний мэнд';
    if (h < 18) return 'Өдрийн мэнд';
    return 'Оройн мэнд';
  }

  String get _dateStr {
    const weekdays = ['Ням', 'Даваа', 'Мягмар', 'Лхагва', 'Пүрэв', 'Баасан', 'Бямба'];
    const months = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'];
    final now = DateTime.now();
    return '${weekdays[now.weekday % 7]}, ${now.year} оны ${months[now.month - 1]}-р сарын ${now.day}';
  }

  int _todayOrderCount(OrderController prov) {
    final now = DateTime.now();
    return (prov.listState.valueOrNull ?? [])
        .where(
          (o) =>
              o.createdAt.year == now.year &&
              o.createdAt.month == now.month &&
              o.createdAt.day == now.day,
        )
        .length;
  }

  void _pushNewInspection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => NewInspectionController(),
          child: const NewInspectionScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insProv = context.watch<InspectionController>();
    final orderProv = context.watch<OrderController>();
    final unreadCount = context.watch<NotificationController>().unreadCount;
    final user = Authenticator.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ─── Pinned header ───────────────────────────────────────────────
          _Header(
            greeting: _greeting,
            name: user?.firstName ?? 'Хэрэглэгч',
            dateStr: _dateStr,
            unreadCount: unreadCount,
            onMenu: () => context.read<BottomNavController>().openMenu(),
            onSearch: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
            onNotification: () =>
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationScreen()),
                ).then((_) {
                  if (context.mounted) context.read<NotificationController>().load();
                }),
          ),

          // ─── Scrollable content ──────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: insProv.loadReports,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                children: [
                  // ─── Stats row ───────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          count: insProv.todayCount,
                          label: 'Өнөөдрийн\nоношилгоо',
                          icon: Icons.fact_check_outlined,
                          color: AppColors.accent,
                          bgColor: const Color(0xFFEEF3FF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          count: _todayOrderCount(orderProv),
                          label: 'Өнөөдрийн\nзахиалга',
                          icon: Icons.receipt_long_outlined,
                          color: const Color(0xFF10B981),
                          bgColor: const Color(0xFFECFDF5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ─── Menu ──────────────────────────────────────────────
                  Text('Цэс', style: AppTextStyles.h3),
                  const SizedBox(height: 10),
                  _MenuSection(
                    items: [
                      _MenuEntry(
                        icon: Icons.add_circle_outline_rounded,
                        color: const Color(0xFF3B6FF5),
                        label: 'Шинэ оношилгоо',
                        subtitle: 'Тээврийн хэрэгсэл бүртгэх',
                        onTap: _pushNewInspection,
                      ),
                      _MenuEntry(
                        icon: Icons.receipt_long_rounded,
                        color: const Color(0xFF10B981),
                        label: 'Захиалгууд',
                        subtitle: 'Үйлчилгээний захиалга харах',
                        onTap: () {
                          final ctrl = context.read<OrderController>();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChangeNotifierProvider.value(
                                value: ctrl,
                                child: const OrderListScreen(),
                              ),
                            ),
                          );
                        },
                      ),
                      _MenuEntry(
                        icon: Icons.person_search_rounded,
                        color: const Color(0xFFF59E0B),
                        label: 'Үйлчлүүлэгч хайх',
                        subtitle: 'Нэр, утас, дугаараар хайх',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SearchScreen()),
                        ),
                      ),
                      _MenuEntry(
                        icon: Icons.build_circle_rounded,
                        color: const Color(0xFF8B5CF6),
                        label: 'Үйлчилгээ',
                        subtitle: 'Үнийн жагсаалт удирдах',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ServiceListScreen()),
                        ),
                      ),
                      _MenuEntry(
                        icon: Icons.event_rounded,
                        color: const Color(0xFF0EA5E9),
                        label: 'Цаг захиалга',
                        subtitle: 'Өнөөдрийн цаг захиалга харах',
                        onTap: () {
                          final ctrl = context.read<AppointmentController>();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChangeNotifierProvider.value(
                                value: ctrl,
                                child: const AppointmentScreen(),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ─── Recent inspections ────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Сүүлийн бүртгэлүүд', style: AppTextStyles.h3),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HistoryScreen()),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Бүгдийг харах',
                          style: AppTextStyles.caption.copyWith(color: AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (insProv.loading)
                    const Center(child: CircularProgressIndicator())
                  else if (insProv.reports.isEmpty)
                    const EmptyState(
                      message: 'Оношилгооны бүртгэл байхгүй',
                      icon: Icons.inventory_2_outlined,
                    )
                  else
                    ...insProv.reports
                        .take(5)
                        .map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ReportListCard(
                              report: r,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReportDetailScreen(reportId: r.id),
                                ),
                              ),
                            ),
                          ),
                        ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String greeting;
  final String name;
  final String dateStr;
  final int unreadCount;
  final VoidCallback onMenu;
  final VoidCallback onSearch;
  final VoidCallback onNotification;
  const _Header({
    required this.greeting,
    required this.name,
    required this.dateStr,
    required this.unreadCount,
    required this.onMenu,
    required this.onSearch,
    required this.onNotification,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBtn(icon: Icons.menu_rounded, onTap: onMenu),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting,',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _NotifIconBtn(count: unreadCount, onTap: onNotification),
              const SizedBox(width: 8),
              _IconBtn(icon: Icons.search_rounded, onTap: onSearch),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.white38),
              const SizedBox(width: 6),
              Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }
}

class _NotifIconBtn extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _NotifIconBtn({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(Icons.notifications_none_outlined, color: Colors.white70, size: 20),
            ),
            if (count > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final int count;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  const _StatCard({
    required this.count,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Menu section ─────────────────────────────────────────────────────────────

class _MenuEntry {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _MenuEntry({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
}

class _MenuSection extends StatelessWidget {
  final List<_MenuEntry> items;
  const _MenuSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final isLast = i == items.length - 1;
          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? const Radius.circular(16) : Radius.zero,
                  bottom: isLast ? const Radius.circular(16) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, color: item.color, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
                    ],
                  ),
                ),
              ),
              if (!isLast) const Divider(height: 1, indent: 70, endIndent: 0),
            ],
          );
        }),
      ),
    );
  }
}
