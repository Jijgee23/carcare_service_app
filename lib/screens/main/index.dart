import 'package:carcare_service/authentication/auth_provider.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/models/user.dart';
import 'package:carcare_service/providers/providers.dart';
import 'package:carcare_service/screens/analytics/analytics_screen.dart';
import 'package:carcare_service/screens/history/history_screen.dart';
import 'package:carcare_service/screens/home/home_screen.dart';
import 'package:carcare_service/screens/inspection/new_inspection_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class IndexScreen extends StatelessWidget {
  const IndexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InspectionProvider()),
        ChangeNotifierProvider(create: (_) => BottomNavProvider()),
      ],
      child: const _MainShell(),
    );
  }
}

class _MainShell extends StatelessWidget {
  const _MainShell();

  @override
  Widget build(BuildContext context) {
    final navProv = context.watch<BottomNavProvider>();

    return Scaffold(
      body: IndexedStack(
        index: navProv.index > 2 ? navProv.index - 1 : navProv.index,
        children: const [
          HomeScreen(),
          HistoryScreen(),
          AnalyticsScreen(),
          _SettingsScreen(),
        ],
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
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomNav(
        currentIndex: navProv.index,
        onTap: (i) {
          if (i == 2) return;
          navProv.setIndex(i);
        },
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: AppColors.primary,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      padding: EdgeInsets.zero,
      height: 64,
      child: Row(children: [
        _NavItem(icon: Icons.home_outlined, label: 'Нүүр', index: 0, current: currentIndex, onTap: onTap),
        _NavItem(icon: Icons.list_alt_outlined, label: 'Жагсаалт', index: 1, current: currentIndex, onTap: onTap),
        const Expanded(child: SizedBox()),
        _NavItem(icon: Icons.bar_chart_outlined, label: 'Тайлан', index: 3, current: currentIndex, onTap: onTap),
        _NavItem(icon: Icons.settings_outlined, label: 'Тохиргоо', index: 4, current: currentIndex, onTap: onTap),
      ]),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final Function(int) onTap;
  const _NavItem({required this.icon, required this.label, required this.index, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 22, color: isActive ? Colors.white : const Color(0xFF8896B3)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10, color: isActive ? Colors.white : const Color(0xFF8896B3), fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
        ]),
      ),
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) {
    final user = Authenticator.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Тохиргоо')),
      body: ListView(children: [
        if (user != null) _UserHeader(user: user),
        ListTile(leading: const Icon(Icons.notifications_none), title: const Text('Мэдэгдэл'), onTap: () {}),
        ListTile(leading: const Icon(Icons.language), title: const Text('Хэл'), onTap: () {}),
        ListTile(leading: const Icon(Icons.help_outline), title: const Text('Тусламж'), onTap: () {}),
        ListTile(leading: const Icon(Icons.info_outline), title: const Text('Тухай'), onTap: () {}),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Гарах', style: TextStyle(color: Colors.red)),
          onTap: () => context.read<AuthProvider>().logout(),
        ),
      ]),
    );
  }
}

class _UserHeader extends StatelessWidget {
  final User user;
  const _UserHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Row(children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.accent,
          child: Text(user.firstName[0], style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.fullName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(user.email, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Text(user.role.name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
      ]),
    );
  }
}
