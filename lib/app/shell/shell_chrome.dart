import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:carcare_service/features/notifications/presentation/screens/notification_screen.dart';

/// Tracks how many pages deep each shell tab's navigator is, so the shell can
/// drop its persistent header on pushed screens: those show a single app bar
/// (← + title + [ShellNotificationBell]) instead of two stacked bars.
///
/// Only [PageRoute]s count — dialogs and bottom sheets leave the header alone.
class ShellDepthTracker extends ChangeNotifier {
  ShellDepthTracker._();
  static final instance = ShellDepthTracker._();

  final _depths = <int, int>{};
  final _observers = <int, NavigatorObserver>{};

  /// One observer per tab — a NavigatorObserver may only be attached to a
  /// single navigator.
  NavigatorObserver observerFor(int branch) =>
      _observers.putIfAbsent(branch, () => _BranchObserver(this, branch));

  bool isSubPage(int branch) => (_depths[branch] ?? 1) > 1;

  void _reset(int branch) {
    _depths[branch] = 0;
  }

  void _shift(int branch, int delta) {
    final next = ((_depths[branch] ?? 0) + delta).clamp(0, 1 << 20).toInt();
    if (next == _depths[branch]) return;
    _depths[branch] = next;
    // Observer callbacks fire during navigator updates; defer the rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }
}

class _BranchObserver extends NavigatorObserver {
  _BranchObserver(this._tracker, this._branch);
  final ShellDepthTracker _tracker;
  final int _branch;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // A first route means a freshly built navigator (e.g. after re-login):
    // the old one was disposed without pops, so its count is stale.
    if (previousRoute == null) _tracker._reset(_branch);
    if (route is PageRoute) _tracker._shift(_branch, 1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _tracker._shift(_branch, -1);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _tracker._shift(_branch, -1);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final delta = (newRoute is PageRoute ? 1 : 0) - (oldRoute is PageRoute ? 1 : 0);
    if (delta != 0) _tracker._shift(_branch, delta);
  }
}

/// Notification bell for app bars. Top-level tabs get it from the shell
/// header; pushed screens add it to their own `AppBar.actions`. Renders
/// nothing when the screen is opened outside the shell (no controller).
class ShellNotificationBell extends StatelessWidget {
  const ShellNotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final NotificationController controller;
    try {
      controller = context.watch<NotificationController>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final unread = controller.unreadCount;
    return Badge(
      isLabelVisible: unread > 0,
      label: Text(unread > 99 ? '99+' : '$unread'),
      child: IconButton(
        tooltip: 'Мэдэгдэл',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationScreen()),
        ).then((_) => controller.load()),
        icon: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}
