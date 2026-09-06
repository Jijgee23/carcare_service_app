import 'package:carcare_service/core/services/notification_router.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/features/models/notification_item.dart';
import 'package:carcare_service/features/presentation/controllers/notification_controller.dart';
import 'package:carcare_service/shared/mixin/pagination_mixin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotificationController()..load(),
      child: const _Body(),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> with PaginationMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initPagination(() => context.read<NotificationController>().loadMore());
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<NotificationController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnDark,
        title: const Text(
          'Мэдэгдэл',
          style: TextStyle(color: AppColors.textOnDark, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          if ((ctrl.listState.valueOrNull ?? []).any((n) => n.isUnread))
            TextButton(
              onPressed: ctrl.markAllRead,
              child: const Text(
                'Бүгдийг уншсан',
                style: TextStyle(color: AppColors.accentLight, fontSize: 13),
              ),
            ),
        ],
      ),
      body: switch (ctrl.listState) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => _ErrorView(message: error.display, onRetry: ctrl.load),
        AsyncData(:final value) =>
          value.isEmpty
              ? const _EmptyView()
              : _List(items: value, ctrl: ctrl, scrollController: scrollController),
      },
    );
  }
}

class _List extends StatelessWidget {
  final List<NotificationItem> items;
  final NotificationController ctrl;
  final ScrollController scrollController;

  const _List({required this.items, required this.ctrl, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length + (ctrl.loadingMore ? 1 : 0),
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.divider),
      itemBuilder: (context, i) {
        if (i == items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return _NotificationTile(
          item: items[i],
          onTap: () {
            if (items[i].isUnread) ctrl.markRead(items[i].id);
            NotificationRouter.route(items[i].data);
          },
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: item.isUnread ? AppColors.accent.withOpacity(0.05) : AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TypeIcon(type: item.type, isUnread: item.isUnread),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: item.isUnread ? FontWeight.w600 : FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (item.isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, top: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _fmtDate(item.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'Дөнгөж сая';
    if (diff.inHours < 1) return '${diff.inMinutes}м өмнө';
    if (diff.inHours < 24) return '${diff.inHours}ц өмнө';
    if (diff.inDays < 7) return '${diff.inDays}х өмнө';
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }
}

class _TypeIcon extends StatelessWidget {
  final String type;
  final bool isUnread;
  const _TypeIcon({required this.type, required this.isUnread});

  @override
  Widget build(BuildContext context) {
    final (icon, bg) = switch (type) {
      'appointment_confirmed' => (Icons.check_circle_outline_rounded, AppColors.goodBg),
      'appointment_rejected' => (Icons.cancel_outlined, AppColors.dangerBg),
      'appointment_reminder' => (Icons.alarm_rounded, AppColors.warningBg),
      'appointment_created' => (
        Icons.calendar_today_rounded,
        AppColors.accentLight.withOpacity(0.15),
      ),
      'appointment_cancelled' => (Icons.event_busy_rounded, AppColors.dangerBg),
      _ => (Icons.notifications_none_rounded, AppColors.divider),
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppDimens.radiusMD)),
      child: Icon(icon, size: 20, color: isUnread ? AppColors.accent : AppColors.textSecondary),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded, size: 56, color: AppColors.textHint),
          SizedBox(height: 12),
          Text('Мэдэгдэл байхгүй', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Дахин оролдох')),
        ],
      ),
    );
  }
}
