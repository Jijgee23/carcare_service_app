import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:auto_diagnostic_app/lib/claude_generated_code/auto_app/core/theme/app_theme.dart';
import 'package:auto_diagnostic_app/lib/claude_generated_code/auto_app/providers/providers.dart';
import 'package:auto_diagnostic_app/lib/claude_generated_code/auto_app/lib/home/home_screen.dart';
import 'package:auto_diagnostic_app/lib/claude_generated_code/auto_app/lib/history/history_screen.dart';
import 'package:auto_diagnostic_app/lib/claude_generated_code/auto_app/lib/analytics/analytics_screen.dart';
import 'package:auto_diagnostic_app/lib/claude_generated_code/auto_app/lib/inspection/new_inspection_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final navProv = context.watch<BottomNavProvider>();

    final screens = [
      const HomeScreen(),
      const HistoryScreen(),
      const SizedBox(), // FAB placeholder
      const AnalyticsScreen(),
      const _SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: navProv.index == 2
            ? 0
            : navProv.index > 2
                ? navProv.index - 1
                : navProv.index,
        children: [
          const HomeScreen(),
          const HistoryScreen(),
          const AnalyticsScreen(),
          const _SettingsScreen(),
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
          if (i == 2) return; // FAB slot
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
      child: Row(
        children: [
          _NavItem(
              icon: Icons.home_outlined,
              label: 'Нүүр',
              index: 0,
              current: currentIndex,
              onTap: onTap),
          _NavItem(
              icon: Icons.list_alt_outlined,
              label: 'Жагсаалт',
              index: 1,
              current: currentIndex,
              onTap: onTap),
          const Expanded(child: SizedBox()), // FAB notch space
          _NavItem(
              icon: Icons.bar_chart_outlined,
              label: 'Тайлан',
              index: 3,
              current: currentIndex,
              onTap: onTap),
          _NavItem(
              icon: Icons.settings_outlined,
              label: 'Тохиргоо',
              index: 4,
              current: currentIndex,
              onTap: onTap),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? Colors.white : const Color(0xFF8896B3),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? Colors.white : const Color(0xFF8896B3),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Тохиргоо')),
      body: ListView(
        children: const [
          ListTile(leading: Icon(Icons.person_outline), title: Text('Профайл')),
          ListTile(leading: Icon(Icons.notifications_none), title: Text('Мэдэгдэл')),
          ListTile(leading: Icon(Icons.language), title: Text('Хэл')),
          ListTile(leading: Icon(Icons.help_outline), title: Text('Тусламж')),
          ListTile(leading: Icon(Icons.info_outline), title: Text('Тухай')),
        ],
      ),
    );
  }
}
