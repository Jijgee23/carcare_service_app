import 'package:flutter/material.dart' hide Feedback;
import 'package:provider/provider.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/widgets/adaptive/async_state_view.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/core/widgets/mixin/pagination_mixin.dart';
import 'package:carcare_service/features/feedback/data/feedback_repository.dart';
import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:carcare_service/features/feedback/domain/feedback_repository.dart';
import 'package:carcare_service/features/feedback/presentation/controllers/feedback_list_controller.dart';
import 'package:carcare_service/features/feedback/presentation/widgets/feedback_vocab.dart';

/// The caller's own tenant's Feedback tickets — P7-F3 (D-176). No
/// permission gate: feedback requires authentication only, matching the
/// web (`requireUser()` and nothing else on every feedback route/action).
///
/// **Not wired to a route** — `lib/app/router.dart` is owned by `P7-F4`.
/// Intended routes: `/feedback` (this screen), `/feedback/new`
/// ([FeedbackCreateScreen]), `/feedback/:id` ([FeedbackDetailScreen]).
/// [onTapTicket]/[onCreate] are hooks for that slice to wire.
class FeedbackListScreen extends StatelessWidget {
  const FeedbackListScreen({
    super.key,
    this.repository,
    this.onTapTicket,
    this.onCreate,
  });

  final FeedbackRepository? repository;
  final ValueChanged<Feedback>? onTapTicket;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => FeedbackListController(repo: repository),
    child: _Body(onTapTicket: onTapTicket, onCreate: onCreate),
  );
}

class _Body extends StatefulWidget {
  const _Body({this.onTapTicket, this.onCreate});
  final ValueChanged<Feedback>? onTapTicket;
  final VoidCallback? onCreate;

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
      final controller = context.read<FeedbackListController>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        initPagination(() {
          if (mounted) controller.loadMore();
        });
        controller.loadFeedback();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FeedbackListController>();
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Санал хүсэлт'),
        actions: [
          IconButton(onPressed: controller.refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: widget.onCreate == null
          ? null
          : FloatingActionButton(
              heroTag: 'feedback_create_fab',
              onPressed: widget.onCreate,
              backgroundColor: context.colors.accent,
              child: Icon(Icons.add, color: CarCareTheme.of(context).onAccent),
            ),
      body: AsyncStateView<List<Feedback>>(
        state: controller.listState,
        isEmpty: (items) => items.isEmpty,
        empty: const _EmptyView(),
        onRetry: controller.refresh,
        builder: (context, items) {
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.all(AppDimens.paddingMD),
              itemCount: items.length + 1,
              separatorBuilder: (_, i) => SizedBox(height: i == items.length - 1 ? 4 : 8),
              itemBuilder: (_, index) {
                if (index == items.length) {
                  return _ListFooter(controller: controller);
                }
                final ticket = items[index];
                return _TicketCard(
                  feedback: ticket,
                  onTap: widget.onTapTicket == null
                      ? null
                      : () => widget.onTapTicket!(ticket),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.forum_outlined, size: 56, color: context.colors.textHint),
        const SizedBox(height: 12),
        Text(
          'Санал хүсэлт бүртгэгдээгүй байна',
          style: context.textStyles.body.copyWith(color: context.colors.textSecondary),
        ),
      ],
    ),
  );
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});
  final FeedbackListController controller;

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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text('Нийт ${controller.total} тасалбар', style: context.textStyles.caption),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.feedback, this.onTap});

  final Feedback feedback;
  final VoidCallback? onTap;

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final f = feedback;
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppDimens.radiusLG),
      elevation: AppDimens.cardElevation,
      shadowColor: context.colors.textPrimary.withOpacity(0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(feedbackTypeIcon(f.type), size: 20, color: context.colors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            feedbackTypeLabel(f.type),
                            style: context.textStyles.bodyMedium,
                          ),
                        ),
                        _StatusBadge(status: f.status),
                      ],
                    ),
                    if (f.message != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        f.message!,
                        style: context.textStyles.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(_fmtDate(f.createdAt), style: context.textStyles.caption),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, size: 18, color: context.colors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final FeedbackStatus status;

  @override
  Widget build(BuildContext context) {
    final color = feedbackStatusColor(context, status);
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
      ),
      child: Text(
        feedbackStatusLabel(status),
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
