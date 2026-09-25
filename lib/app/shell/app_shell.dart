import 'package:carcare_service/app/shell/shell_chrome.dart';
import 'package:carcare_service/app/router.dart';
import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/widgets/adaptive/adaptive.dart';
import 'package:carcare_service/core/widgets/dialogs/confirm_sheet.dart';
import 'package:carcare_service/features/appointments/presentation/screens/appointment_screen.dart';
import 'package:carcare_service/features/controllers.dart';
import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:carcare_service/features/feedback/presentation/screens/feedback_list_screen.dart';
import 'package:carcare_service/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:carcare_service/features/notifications/presentation/screens/notification_screen.dart';
import 'package:carcare_service/features/orders/domain/orders_repository.dart';
import 'package:carcare_service/features/orders/presentation/controllers/order_list_controller.dart';
import 'package:carcare_service/features/orders/presentation/screens/order_list_screen.dart';
import 'package:carcare_service/features/overview/presentation/screens/home_screen.dart';
import 'package:carcare_service/features/profile/presentation/screens/profile_screen.dart';
import 'package:carcare_service/features/settings/presentation/screens/about_screen.dart';
import 'package:carcare_service/features/settings/presentation/screens/help_screen.dart';
import 'package:carcare_service/features/shell/data/working_branch_repository.dart';
import 'package:carcare_service/features/shell/presentation/controllers/working_branch_controller.dart';
import 'package:carcare_service/features/shell/presentation/screens/choose_branch_screen.dart';
import 'package:carcare_service/features/shell/presentation/widgets/working_branch_switcher.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    AdaptiveNavigationDestination(
      icon: Icons.today_outlined,
      selectedIcon: Icons.today_rounded,
      label: 'Өнөөдөр',
    ),
    AdaptiveNavigationDestination(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      label: 'Захиалга',
    ),
    AdaptiveNavigationDestination(
      icon: Icons.event_outlined,
      selectedIcon: Icons.event_rounded,
      label: 'Цаг',
    ),
    AdaptiveNavigationDestination(
      icon: Icons.more_horiz_rounded,
      selectedIcon: Icons.more_horiz_rounded,
      label: 'Бусад',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<OrderController>(
          create: (context) => OrderController(repo: context.read<OrdersRepository>()),
        ),
        // Detail routes receive the same list instance so successful detail
        // mutations can reload the active server query instead of creating a
        // second list with different filters or pagination.
        Provider<OrderListController>(create: (context) => context.read<OrderController>()),
        ChangeNotifierProvider(create: (_) => AppointmentController()),
        ChangeNotifierProvider(
          create: (context) {
            final orders = context.read<OrderController>();
            final appointments = context.read<AppointmentController>();

            Future<void> clearLegacyBranchFilters() async {
              // These controllers' setBranch methods reload immediately. Once
              // the validated X-Working-Branch header is active, retaining a
              // stale ?branchId= would make the API reject the request (422).
              await Future.wait([orders.setBranch(null), appointments.setBranch(null)]);
            }

            return WorkingBranchController(
              repository: RemoteWorkingBranchRepository(),
              onSelectionChanged: clearLegacyBranchFilters,
              onInvalidation: clearLegacyBranchFilters,
            )..load();
          },
        ),
        ChangeNotifierProvider(create: (_) => NotificationController()..load()),
        ChangeNotifierProvider<ShellDepthTracker>.value(value: ShellDepthTracker.instance),
      ],
      child: Builder(
        builder: (shellContext) {
          final branch = shellContext.watch<WorkingBranchController>();
          if (branch.needsChoice) {
            return ChooseBranchScreen(controller: branch);
          }
          final bottomNav = shellContext.watch<BottomNavController>();
          shellContext.watch<ShellDepthTracker>();
          final user = Authenticator.user;
          final destinations = [
            _destinations[0],
            _destinations[1].copyWith(enabled: canSeeView(user, 'orders')),
            _destinations[2].copyWith(enabled: canSeeView(user, 'appointments')),
            _destinations[3],
          ];
          final canSearch = canSeeView(user, 'customers') || canSeeView(user, 'vehicles');
          return AdaptiveScaffold(
            scaffoldKey: bottomNav.scaffoldKey,
            drawer: const _AppDrawer(),
            body: navigationShell,
            destinations: destinations,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              bottomNav.setIndex(index);
              navigationShell.goBranch(index);
            },
            leadingAction: IconButton(
              tooltip: 'Цэс',
              onPressed: bottomNav.openMenu,
              icon: const Icon(Icons.menu_rounded),
            ),
            searchAction: canSearch
                ? IconButton(
                    tooltip: 'Хайлт',
                    onPressed: () => shellContext.push(AppRoutes.search),
                    icon: const Icon(Icons.search_rounded),
                  )
                : null,
            branchSwitcher: const WorkingBranchSwitcher(),
            // Pushed screens own a single app bar with the bell (D: shell
            // header only on top-level tabs; no branch switch mid-flow).
            showHeader: !ShellDepthTracker.instance.isSubPage(navigationShell.currentIndex),
            notificationAction: _NotificationAction(
              unreadCount: shellContext.watch<NotificationController>().unreadCount,
              onPressed: () => _openNotifications(shellContext),
            ),
          );
        },
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())).then((
      _,
    ) {
      if (context.mounted) context.read<NotificationController>().load();
    });
  }
}

extension on AdaptiveNavigationDestination {
  AdaptiveNavigationDestination copyWith({bool? enabled}) => AdaptiveNavigationDestination(
    label: label,
    icon: icon,
    selectedIcon: selectedIcon,
    enabled: enabled ?? this.enabled,
    tooltip: tooltip,
  );
}

class _NotificationAction extends StatelessWidget {
  const _NotificationAction({required this.unreadCount, required this.onPressed});
  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: unreadCount > 0,
      label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
      child: IconButton(
        tooltip: 'Мэдэгдэл',
        onPressed: onPressed,
        icon: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const groups = <_NavigationGroup>[
    _NavigationGroup('Үйлчлүүлэгчид', [
      _NavigationEntry(
        'Үйлчлүүлэгчид',
        Icons.people_outline,
        'customers',
        route: AppRoutes.customers,
      ),
      _NavigationEntry(
        'Машин',
        Icons.directions_car_outlined,
        'vehicles',
        route: AppRoutes.vehicles,
      ),
    ]),
    // D-164: Units ("Нэгж") and Categories ("Ангилал") management is
    // out of mobile scope — both stay owner-gated reference tables on the
    // web's Settings → System page. Their rows are removed here rather
    // than filled in; do not re-add them (see the Phase 4 entry state in
    // `TENANT_MOBILE_SLICES.md`). Хөдөлмөр/Бараа route into `/services`
    // with the corresponding kind preselected via the `type` query param
    // `_ServiceListRoute`/`ServiceListScreen.initialType` consume
    // (`lib/app/router.dart`, P4-F4).
    _NavigationGroup('Үйлчилгээ', [
      _NavigationEntry(
        'Ажил/Үйлчилгээ',
        Icons.build_outlined,
        'services',
        route: '${AppRoutes.services}?type=labor',
      ),
      _NavigationEntry(
        'Сэлбэг/Бараа',
        Icons.inventory_2_outlined,
        'services',
        route: '${AppRoutes.services}?type=goods',
      ),
      _NavigationEntry(
        'Оношилгоо',
        Icons.description_outlined,
        'diagnostics',
        route: AppRoutes.diagnosticsTemplates,
      ),
    ]),
    // _NavigationGroup('Оношилгоо', [
    //   _NavigationEntry(
    //     'Түүх',
    //     Icons.assessment_outlined,
    //     'diagnostics',
    //     route: AppRoutes.diagnosticsReports,
    //   ),
    // ]),
    // P6-F5: the four rows below finally get real destinations. Gating
    // matches each screen's own in-screen gate exactly (D-163) — see each
    // route's registration in `lib/app/router.dart` and the screens'
    // "Not wired to a route" doc comments this slice resolves.
    _NavigationGroup('Ажилын хувиар', [
      _NavigationEntry('Ажилтнууд', Icons.badge_outlined, 'employees', route: AppRoutes.employees),
      _NavigationEntry(
        'Эрхүүд',
        Icons.admin_panel_settings_outlined,
        'owner',
        route: AppRoutes.roles,
      ),
      _NavigationEntry(
        'Ажлын хуваарь',
        Icons.calendar_view_week_outlined,
        'employees',
        route: AppRoutes.schedules,
      ),
      _NavigationEntry(
        'Миний хуваарь',
        Icons.event_available_outlined,
        null,
        route: AppRoutes.mySchedule,
      ),
    ]),
    // P7-F4: the three rows below get real destinations. Тайлан and Санал
    // хүсэлт are visible to any authenticated user (D-174/D-176, matching
    // the web's `requireUser()`-only gate); Аудит stays gated on
    // `audit.view` via `canSeeView`'s existing 'audit' special-case.
    _NavigationGroup('Удирдлага', [
      _NavigationEntry('Тайлан', Icons.bar_chart_outlined, null, route: AppRoutes.reports),
      _NavigationEntry('Аудит', Icons.fact_check_outlined, 'audit', route: AppRoutes.audit),
    ]),
    // Салбарууд / Тохиргоо had no mobile screen (placeholder snackbar only)
    // and were removed with the duplicate Каталог → Оношилгоо row, which
    // pointed at the same route as Оношилгоо → Загвар.
  ];

  @override
  Widget build(BuildContext context) {
    final user = Authenticator.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Бусад')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final group in groups) _NavigationGroupView(group: group, user: user),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.notifications_none_rounded),
            title: const Text('Мэдэгдэл'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Санал хүсэлт'),
            onTap: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => FeedbackListScreen())),
          ),

          ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: const Text('Профайл'),
            onTap: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Гарын авлага'),
            onTap: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
          ),
        ],
      ),
    );
  }
}

class _NavigationGroupView extends StatelessWidget {
  const _NavigationGroupView({required this.group, required this.user});
  final _NavigationGroup group;
  final User? user;

  @override
  Widget build(BuildContext context) {
    final visible = group.entries.where((entry) => canSeeView(user, entry.permission)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(group.label, style: Theme.of(context).textTheme.labelLarge),
        ),
        for (final entry in visible)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(entry.icon),
            title: Text(entry.label),
            minVerticalPadding: 10,
            onTap: () {
              final route = entry.route;
              if (route != null) {
                context.push(route);
              } else {
                _showUnavailable(context, entry);
              }
            },
          ),
      ],
    );
  }

  void _showUnavailable(BuildContext context, _NavigationEntry entry) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${entry.label}: удахгүй')));
  }
}

class _NavigationGroup {
  const _NavigationGroup(this.label, this.entries);
  final String label;
  final List<_NavigationEntry> entries;
}

class _NavigationEntry {
  const _NavigationEntry(this.label, this.icon, this.permission, {this.route});
  final String label;
  final IconData icon;
  final String? permission;

  /// A `go_router` location to push instead of the "удахгүй" placeholder
  /// snackbar. `null` (the default, and every row outside Каталог today)
  /// keeps the pre-existing placeholder behaviour — added by `P4-F4`
  /// narrowly for the two rows it wires, not a blanket change to every
  /// `MoreScreen` entry.
  final String? route;
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    final user = Authenticator.user;
    final unreadCount = context.watch<NotificationController>().unreadCount;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            if (user != null)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: context.colors.accent,
                  child: Text(
                    user.firstName.isNotEmpty ? user.firstName[0] : '?',
                    style: TextStyle(
                      color: CarCareTheme.of(context).onAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(user.fullName),
                subtitle: Text(user.email),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                },
              ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_none_rounded),
                    title: Text('Мэдэгдэл'),
                    trailing: unreadCount > 0
                        ? CircleAvatar(
                            radius: 10,
                            backgroundColor: context.colors.danger,
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: TextStyle(
                                color: CarCareTheme.of(context).onAccent,
                                fontSize: 10,
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded),
                    title: const Text('Тусламж'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('Тухай'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout, color: context.colors.danger),
              title: Text('Гарах', style: TextStyle(color: context.colors.danger)),
              onTap: () async {
                final ok = await ConfirmSheet.show(
                  context,
                  title: 'Гарах уу?',
                  message: 'Та системээс гарахдаа итгэлтэй байна уу?',
                  confirmLabel: 'Гарах',
                  icon: Icons.logout_rounded,
                  isDangerous: true,
                );
                if (ok && context.mounted) {
                  context.read<AuthController>().logout();
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class SubscriptionLockedScreen extends StatelessWidget {
  const SubscriptionLockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 56, color: context.colors.danger),
                const SizedBox(height: 16),
                Text(
                  'Захиалга идэвхгүй байна',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Байгууллагын захиалга дуусгавар болсон тул үргэлжлүүлэхийн тулд админтайгаа холбогдоно уу.',
                  style: TextStyle(fontSize: 13, color: context.colors.textSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => context.read<AuthController>().logout(),
                  child: const Text('Гарах'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
