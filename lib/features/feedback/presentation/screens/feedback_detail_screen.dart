import 'package:flutter/material.dart' hide Feedback;
import 'package:provider/provider.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/widgets/adaptive/async_state_view.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:carcare_service/features/feedback/data/feedback_repository.dart';
import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:carcare_service/features/feedback/domain/feedback_repository.dart';
import 'package:carcare_service/features/feedback/presentation/controllers/feedback_detail_controller.dart';
import 'package:carcare_service/features/feedback/presentation/widgets/feedback_vocab.dart';

/// Detail thread for one ticket, with a reply composer — P7-F3 (D-176).
/// No status controls exist anywhere on this screen: the repository has no
/// mutator for status and this screen never invents one. Replying to a
/// resolved/dismissed ticket reopens it server-side to `IN_REVIEW` — this
/// screen surfaces that with a toast and the refreshed status badge, it
/// never predicts the outcome locally.
///
/// **Not wired to a route** — intended path: `/feedback/:id`, reached from
/// [FeedbackListScreen]'s row tap.
class FeedbackDetailScreen extends StatefulWidget {
  const FeedbackDetailScreen({super.key, required this.feedbackId, this.repository});

  final String feedbackId;
  final FeedbackRepository? repository;

  @override
  State<FeedbackDetailScreen> createState() => _FeedbackDetailScreenState();
}

class _FeedbackDetailScreenState extends State<FeedbackDetailScreen> {
  late final FeedbackDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FeedbackDetailController(
      feedbackId: widget.feedbackId,
      repo: widget.repository,
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: _controller,
    child: const _Body(),
  );
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply(FeedbackDetailController controller) async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    final result = await controller.reply(text);
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        _replyController.clear();
        if (value.reopened) {
          messageComplete('Тасалбар дахин нээгдлээ');
        }
      case Err(:final error):
        messageError(error.display);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FeedbackDetailController>();
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: const Text('Санал хүсэлт')),
      body: AsyncStateView<FeedbackDetail>(
        state: controller.detailState,
        onRetry: controller.refresh,
        builder: (context, detail) => Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView(
                  padding: const EdgeInsets.all(AppDimens.paddingMD),
                  children: [
                    _TicketHeader(feedback: detail.feedback),
                    const SizedBox(height: 16),
                    if (detail.messages.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Хариу байхгүй байна',
                            style: context.textStyles.caption,
                          ),
                        ),
                      )
                    else
                      ...detail.messages.map((m) => _MessageBubble(message: m)),
                  ],
                ),
              ),
            ),
            _ReplyComposer(
              controller: _replyController,
              sending: controller.replying,
              onSend: () => _sendReply(controller),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketHeader extends StatelessWidget {
  const _TicketHeader({required this.feedback});
  final Feedback feedback;

  @override
  Widget build(BuildContext context) {
    final f = feedback;
    final color = feedbackStatusColor(context, f.status);
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppDimens.radiusLG),
      elevation: AppDimens.cardElevation,
      shadowColor: context.colors.textPrimary.withOpacity(0.12),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(feedbackTypeIcon(f.type), size: 20, color: context.colors.accent),
                const SizedBox(width: AppDimens.paddingSM),
                Expanded(
                  child: Text(feedbackTypeLabel(f.type), style: context.textStyles.bodyMedium),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.paddingSM,
                    vertical: AppDimens.paddingXS,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                  ),
                  child: Text(
                    feedbackStatusLabel(f.status),
                    style: context.textStyles.caption.copyWith(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (f.message != null) ...[
              const SizedBox(height: 10),
              Text(f.message!, style: context.textStyles.body),
            ],
            if (f.screenshotUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                child: Image.network(
                  f.screenshotUrl!,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final FeedbackMessage message;

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitter = message.author == FeedbackAuthor.submitter;
    return Align(
      alignment: isSubmitter ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSubmitter
              ? context.colors.accent.withValues(alpha: 0.12)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMD),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              feedbackAuthorLabel(message.author),
              style: context.textStyles.captionMedium,
            ),
            const SizedBox(height: 4),
            Text(message.message ?? '', style: context.textStyles.body),
            const SizedBox(height: 4),
            Text(_fmtDate(message.createdAt), style: context.textStyles.caption),
          ],
        ),
      ),
    );
  }
}

class _ReplyComposer extends StatelessWidget {
  const _ReplyComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Хариу бичих...'),
            ),
          ),
          const SizedBox(width: 8),
          sending
              ? const Padding(
                  padding: EdgeInsets.all(AppDimens.paddingSM),
                  child: AppLoading(size: 20),
                )
              : IconButton(
                  onPressed: onSend,
                  icon: Icon(Icons.send, color: context.colors.accent),
                ),
        ],
      ),
    ),
  );
}
