import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/widgets/adaptive/async_state_view.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/core/widgets/dialogs/confirm_sheet.dart';
import 'package:carcare_service/core/widgets/mixin/pagination_mixin.dart';
import 'package:carcare_service/features/auth/presentation/controllers/auth_controller.dart';
import 'package:carcare_service/features/profile/domain/account_repository.dart';
import 'package:carcare_service/features/profile/domain/account_session.dart';
import 'package:carcare_service/features/profile/presentation/controllers/sessions_controller.dart';
import 'package:carcare_service/features/profile/presentation/widgets/session_tile.dart';

/// "Нэвтэрсэн төхөөрөмжүүд" — P8-F3 (D-178). One unified list across web
/// `UserSession` and mobile `RefreshToken` rows, tagged by source. Revoking
/// the row that is the caller's own device runs the app's normal
/// [AuthController.logout] flow — this screen never reimplements token
/// clearing (D-179/D-180). Revoking others is hidden once
/// `otherActiveCount == 0`, matching the web's `revokeOtherSessionsAction`
/// gating in `app/dashboard/profile/page.tsx`.
class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key, this.repository});

  final AccountRepository? repository;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => SessionsController(repo: repository),
    child: const _Body(),
  );
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> with PaginationMixin {
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      final controller = context.read<SessionsController>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        initPagination(() {
          if (mounted) controller.loadMore();
        });
        controller.load();
      });
    }
  }

  Future<void> _handlePendingLogout(SessionsController controller) async {
    if (!controller.pendingLogout) return;
    controller.acknowledgeLogout();
    if (!mounted) return;
    await context.read<AuthController>().logout();
  }

  Future<void> _revoke(
    BuildContext context,
    SessionsController controller,
    AccountSession session,
  ) async {
    final ok = await ConfirmSheet.show(
      context,
      title: session.current ? 'Энэ төхөөрөмжөөс гарах уу?' : 'Гаргах уу?',
      message: session.current
          ? 'Та энэ төхөөрөмж дээрх нэвтрэлтээ дуусгах гэж байна.'
          : '${session.deviceLabel.isNotEmpty ? session.deviceLabel : "Энэ төхөөрөмж"} дэх нэвтрэлт цуцлагдана.',
      confirmLabel: 'Гаргах',
      icon: Icons.logout_rounded,
      isDangerous: true,
    );
    if (!ok || !mounted) return;
    final success = await controller.revoke(session);
    if (!mounted) return;
    if (!success) {
      final err = controller.actionError;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.display)),
        );
      }
      return;
    }
    await _handlePendingLogout(controller);
  }

  Future<void> _revokeOthers(
    BuildContext context,
    SessionsController controller,
  ) async {
    final ok = await ConfirmSheet.show(
      context,
      title: 'Бусдыг гаргах уу?',
      message:
          '${controller.otherActiveCount} өөр төхөөрөмж дээрх нэвтрэлт цуцлагдана. Энэ төхөөрөмж нөлөөлөхгүй.',
      confirmLabel: 'Гаргах',
      icon: Icons.logout_rounded,
      isDangerous: true,
    );
    if (!ok || !mounted) return;
    final success = await controller.revokeOthers();
    if (!mounted || success) return;
    final err = controller.actionError;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.display)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionsController>();
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Нэвтэрсэн төхөөрөмжүүд'),
        actions: [
          IconButton(
            tooltip: 'Шинэчлэх',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: controller.refresh,
          ),
        ],
      ),
      body: AsyncStateView<List<AccountSession>>(
        state: controller.activeState,
        isEmpty: (items) => items.isEmpty,
        empty: const _EmptyActive(),
        onRetry: controller.refresh,
        builder: (context, active) {
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(AppDimens.paddingMD),
              children: [
                Text('Идэвхтэй', style: context.textStyles.h3),
                const SizedBox(height: 10),
                for (final session in active) ...[
                  ActiveSessionTile(
                    session: session,
                    busy: controller.actionInFlight,
                    onRevoke: () => _revoke(context, controller, session),
                  ),
                  const SizedBox(height: 8),
                ],
                if (controller.otherActiveCount > 0) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: controller.actionInFlight
                          ? null
                          : () => _revokeOthers(context, controller),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.danger,
                        side: BorderSide(color: context.colors.danger),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusMD,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text(
                        'Бусдыг гаргах (${controller.otherActiveCount})',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text('Дууссан', style: context.textStyles.h3),
                const SizedBox(height: 10),
                if (controller.ended.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Дууссан нэвтрэлт алга',
                      style: context.textStyles.caption,
                    ),
                  )
                else
                  for (final session in controller.ended) ...[
                    EndedSessionTile(session: session),
                    const SizedBox(height: 8),
                  ],
                _ListFooter(controller: controller),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyActive extends StatelessWidget {
  const _EmptyActive();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.devices_other_rounded, size: 56, color: context.colors.textHint),
        const SizedBox(height: 12),
        Text(
          'Идэвхтэй нэвтрэлт алга',
          style: context.textStyles.body.copyWith(color: context.colors.textSecondary),
        ),
      ],
    ),
  );
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});
  final SessionsController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final loadMoreError = controller.loadMoreError;
    if (loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton.icon(
          onPressed: controller.loadMore,
          icon: const Icon(Icons.refresh),
          label: Text('Дахин оролдох: ${loadMoreError.display}'),
        ),
      );
    }
    if (controller.hasNext) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton.icon(
          onPressed: controller.loadMore,
          icon: const Icon(Icons.expand_more),
          label: const Text('Дараагийн хуудас'),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
