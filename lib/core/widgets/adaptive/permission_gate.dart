import 'package:flutter/material.dart';

import '../../domain/user.dart';
import '../../services/auth_storage.dart';

/// Client-side visibility affordance only. APIs must still enforce the same
/// permission server-side; this prevents inaccessible controls being shown.
class PermissionGate extends StatelessWidget {
  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback = const SizedBox.shrink(),
    this.disable = false,
    this.user,
  });
  final String? permission;
  final Widget child;
  final Widget fallback;
  final bool disable;
  final User? user;

  @override
  Widget build(BuildContext context) {
    final allowed = canSeeView(user ?? Authenticator.user, permission);
    if (allowed) return child;
    if (!disable) return fallback;
    return IgnorePointer(child: Opacity(opacity: .45, child: child));
  }
}

bool canSeeView(User? user, String? view) {
  // Items with no view restriction are visible to every signed-in user. The
  // server remains authoritative; this helper only controls client affordances.
  if (view == null || view.isEmpty) return true;
  if (user?.isOwner == true) return true;
  if (user == null || view == 'owner') return false;
  final required = view == 'audit'
      ? 'audit.view'
      : view.contains('.')
      ? view
      : '$view.view';
  final permissions = user.role?.permissions ?? const <String>[];
  // Orders have a server-scoped own-record permission. It is enough to show
  // the Orders affordance; the API still limits the returned rows to the
  // caller's own orders. Do not generalize this fallback to other resources.
  if (view == 'orders' && permissions.contains('orders.viewOwn')) return true;
  return permissions.contains(required);
}
