import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/widgets/adaptive/async_state_view.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/features/roles/domain/role.dart';
import 'package:carcare_service/features/roles/domain/roles_repository.dart';
import 'package:carcare_service/features/roles/presentation/controllers/role_list_controller.dart';

/// Owner-only roles list — P6-F3.
///
/// **Not registered by this slice.** Routing is `P6-F5`'s (`AGENTS.md`
/// forbids touching `lib/app/router.dart`/`app_shell.dart` here) — the
/// intended route path is `/roles`, reached from the "Хүмүүс" group's
/// "Үүрэг, эрх" row, gated the same way this screen gates itself
/// (`user.isOwner`), per `TENANT_MOBILE_SLICES.md`'s `P6-F5` gate table.
///
/// Role management is owner-only (D-171) — a non-owner sees a plain refusal
/// state, matching `ServiceListScreen`'s permission-gated refusal `Scaffold`
/// (that one gates on a permission string; this one gates on `isOwner`
/// directly since there is no `roles.*` permission code).
class RoleListScreen extends StatelessWidget {
  const RoleListScreen({
    super.key,
    this.repository,
    this.user,
    this.onSelectRole,
    this.onCreateRole,
  });

  /// Tests and previews inject a fake. Production defaults to the remote
  /// adapter inside [RoleListController].
  final RolesRepository? repository;

  /// Injectable for tests — production reads `Authenticator.user`, matching
  /// `ServiceListScreen`'s convention (D-160).
  final User? user;

  final ValueChanged<Role>? onSelectRole;
  final VoidCallback? onCreateRole;

  @override
  Widget build(BuildContext context) {
    final effectiveUser = user ?? Authenticator.user;
    if (effectiveUser?.isOwner != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Үүрэг, эрх')),
        body: const EmptyState(
          message: 'Зөвхөн эзэмшигч энэ хэсгийг удирдана.',
          icon: Icons.lock_outline,
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => RoleListController(repo: repository)..load(),
      child: _Body(onSelectRole: onSelectRole, onCreateRole: onCreateRole),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({this.onSelectRole, this.onCreateRole});

  final ValueChanged<Role>? onSelectRole;
  final VoidCallback? onCreateRole;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RoleListController>();
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Үүрэг, эрх'),
        actions: [
          IconButton(
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: onCreateRole == null
          ? null
          : FloatingActionButton(
              heroTag: 'role_create_fab',
              onPressed: onCreateRole,
              backgroundColor: context.colors.accent,
              child: Icon(Icons.add, color: CarCareTheme.of(context).onAccent),
            ),
      body: AsyncStateView<List<Role>>(
        state: controller.listState,
        isEmpty: (items) => items.isEmpty,
        empty: const EmptyState(
          message: 'Үүрэг байхгүй байна',
          icon: Icons.badge_outlined,
        ),
        onRetry: controller.refresh,
        builder: (context, items) => RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(AppDimens.paddingMD),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final role = items[index];
              return _RoleCard(
                role: role,
                onTap: onSelectRole == null ? null : () => onSelectRole!(role),
                onDelete: () => _confirmDelete(context, controller, role),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    RoleListController controller,
    Role role,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Үүрэг устгах'),
        content: Text('"${role.name}" үүргийг устгах уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await controller.deleteRole(role.id);
    if (!context.mounted) return;
    if (!ok) {
      final message = controller.deleteError?.display ?? 'Устгаж чадсангүй.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, this.onTap, this.onDelete});

  final Role role;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    borderRadius: BorderRadius.circular(AppDimens.radiusLG),
    elevation: AppDimens.cardElevation,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusLG),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          role.name ?? '—',
                          style: context.textStyles.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!role.isActive)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.textHint.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusFull,
                            ),
                          ),
                          child: Text(
                            'Идэвхгүй',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.colors.textHint,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (role.description != null &&
                      role.description!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      role.description!,
                      style: context.textStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 12,
                        color: context.colors.textHint,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${role.permissions.length} эрх',
                        style: context.textStyles.caption,
                      ),
                      if (role.userCount != null) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.people_outline,
                          size: 12,
                          color: context.colors.textHint,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${role.userCount} хэрэглэгч',
                          style: context.textStyles.caption,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: context.colors.danger,
                  size: 20,
                ),
                onPressed: onDelete,
              ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: context.colors.textHint,
              ),
          ],
        ),
      ),
    ),
  );
}
