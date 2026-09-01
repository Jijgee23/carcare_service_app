import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/features/presentation/controllers/notification_controller.dart';
import 'package:carcare_service/features/presentation/pages/notifications/notification_screen.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/models/user.dart';
import 'package:carcare_service/features/presentation/controllers/controllers.dart';
import 'package:carcare_service/features/presentation/pages/appointments/appointment_screen.dart';
import 'package:carcare_service/features/presentation/pages/history/history_screen.dart';
import 'package:carcare_service/features/presentation/pages/home/home_screen.dart';
import 'package:carcare_service/features/presentation/pages/orders/order_list_screen.dart';
import 'package:carcare_service/shared/widgets/dialogs/confirm_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class IndexScreen extends StatelessWidget {
  const IndexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OrderController()),
        ChangeNotifierProvider(create: (_) => AppointmentController()),
        ChangeNotifierProvider(create: (_) => NotificationController()..load()),
      ],
      child: const _MainShell(),
    );
  }
}

class _MainShell extends StatelessWidget {
  const _MainShell();

  @override
  Widget build(BuildContext context) {
    final navProv = context.watch<BottomNavController>();

    return Scaffold(
      key: navProv.scaffoldKey,
      // index: 0=Нүүр 1=Захиалга 2=Цаг 3=Жагсаалт
      body: IndexedStack(
        index: navProv.index,
        children: const [HomeScreen(), OrderListScreen(), AppointmentScreen(), HistoryScreen()],
      ),
      drawer: _AppDrawer(
        currentIndex: navProv.index,
        onTap: navProv.setIndex,
        unreadCount: context.watch<NotificationController>().unreadCount,
      ),
    );
  }
}

// ─── App Drawer ───────────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final int unreadCount;
  const _AppDrawer({required this.currentIndex, required this.onTap, required this.unreadCount});

  // static const _navItems = [
  //   (icon: Icons.home_rounded, label: 'Нүүр', index: 0),
  //   (icon: Icons.receipt_long_rounded, label: 'Захиалга', index: 1),
  //   (icon: Icons.event_rounded, label: 'Цаг захиалга', index: 2),
  //   (icon: Icons.list_alt_rounded, label: 'Жагсаалт', index: 3),
  // ];

  static const _settingsItems = [
    (icon: Icons.notifications_none_rounded, label: 'Мэдэгдэл'),
    (icon: Icons.language_rounded, label: 'Хэл'),
    (icon: Icons.help_outline_rounded, label: 'Тусламж'),
    (icon: Icons.info_outline_rounded, label: 'Тухай'),
  ];

  @override
  Widget build(BuildContext context) {
    final user = Authenticator.user;

    return Drawer(
      backgroundColor: AppColors.surface,
      child: Column(
        children: [
          if (user != null) _UserHeader(user: user),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8),
              children: [
                // ── Navigation ──────────────────────────────────────────
                // _DrawerSectionLabel('Үндсэн цэс'),
                // ..._navItems.map((item) {
                //   final isActive = item.index == currentIndex;
                //   return Padding(
                //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                //     child: ListTile(
                //       leading: Icon(
                //         item.icon,
                //         color: isActive ? AppColors.accent : AppColors.textSecondary,
                //         size: 22,
                //       ),
                //       title: Text(
                //         item.label,
                //         style: TextStyle(
                //           color: isActive ? AppColors.accent : AppColors.textPrimary,
                //           fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                //           fontSize: 15,
                //         ),
                //       ),
                //       selected: isActive,
                //       selectedTileColor: AppColors.accent.withOpacity(0.08),
                //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                //       onTap: () => onTap(item.index),
                //     ),
                //   );
                // }),
                const SizedBox(height: 8),
                const Divider(height: 1, indent: 16, endIndent: 16),
                const SizedBox(height: 8),

                // ── Settings ─────────────────────────────────────────────
                _DrawerSectionLabel('Тохиргоо'),
                ..._settingsItems.map(
                  (item) {
                    final isNotif = item.label == 'Мэдэгдэл';
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: ListTile(
                        leading: Icon(item.icon, color: AppColors.textSecondary, size: 22),
                        title: Text(
                          item.label,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                        ),
                        trailing: isNotif && unreadCount > 0
                            ? _Badge(count: unreadCount)
                            : null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onTap: isNotif
                            ? () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const NotificationScreen()),
                                ).then((_) {
                                  if (context.mounted) context.read<NotificationController>().load();
                                });
                              }
                            : null,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Гарах', style: TextStyle(color: Colors.red)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                final ok = await ConfirmSheet.show(
                  context,
                  title: 'Гарах уу?',
                  message: 'Та системээс гарахдаа итгэлтэй байна уу?',
                  confirmLabel: 'Гарах',
                  icon: Icons.logout_rounded,
                  isDangerous: true,
                );
                if (ok && context.mounted) context.read<AuthController>().logout();
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DrawerSectionLabel extends StatelessWidget {
  final String label;
  const _DrawerSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textHint,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Badge ────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ─── User header ──────────────────────────────────────────────────────────────

class _UserHeader extends StatelessWidget {
  final User user;
  const _UserHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(20, top + 24, 20, 24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.accent,
            child: Text(
              user.firstName[0],
              style: const TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(user.email, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.role?.name ?? (user.isOwner ? 'Эзэмшигч' : 'Хэрэглэгч'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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
