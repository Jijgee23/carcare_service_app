import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/subscription.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/services/subscription_service.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/widgets/adaptive/permission_gate.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/core/widgets/dialogs/confirm_sheet.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:carcare_service/features/customers/domain/customer.dart';
import 'package:carcare_service/features/customers/domain/customers_repository.dart';
import 'package:carcare_service/features/customers/presentation/controllers/customer_broadcast_controller.dart';

/// The customer broadcast surface — P3-F7.
///
/// Gated on the `customers.notify` permission (via the shared
/// [PermissionGate] / [canSeeView], no second mechanism) **and** an active
/// subscription (via the existing [SubscriptionService] — best-effort, so an
/// unknown/unreachable subscription state does not itself block the screen,
/// matching that service's own documented "never blocks a screen" contract;
/// only a subscription confirmed `locked` blocks). Both gates are enforced
/// again by the server (403), so a hidden/disabled control here is a UX hint
/// only.
///
/// Reached with an imperative `Navigator.push` from the entry-point
/// affordance (see the class doc comment in `customer_search_tab.dart` for
/// exactly where); `P3-F6`/`P3-X1` may convert this into a route later.
class CustomerBroadcastScreen extends StatefulWidget {
  const CustomerBroadcastScreen({
    super.key,
    this.repo,
    this.user,
    this.subscriptionStatus,
  });

  final CustomersRepository? repo;
  final User? user;

  /// Injectable for tests. Production leaves this null and the screen asks
  /// [SubscriptionService.instance] itself.
  final SubscriptionStatus? subscriptionStatus;

  @override
  State<CustomerBroadcastScreen> createState() =>
      _CustomerBroadcastScreenState();
}

class _CustomerBroadcastScreenState extends State<CustomerBroadcastScreen> {
  late final CustomerBroadcastController _controller;

  User? get _user => widget.user ?? Authenticator.user;

  bool _loadingSubscription = true;
  SubscriptionStatus? _subscription;

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = CustomerBroadcastController(repo: widget.repo);
    if (widget.subscriptionStatus != null) {
      _subscription = widget.subscriptionStatus;
      _loadingSubscription = false;
    } else {
      unawaited(_loadSubscription());
    }
    unawaited(_controller.loadRecipientCount());
  }

  Future<void> _loadSubscription() async {
    final sub = await SubscriptionService.instance.getStatus();
    if (!mounted) return;
    setState(() {
      _subscription = sub;
      _loadingSubscription = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  /// Best-effort: an unknown subscription state (null) never blocks, a
  /// confirmed `locked` one always does. Matches `SubscriptionService`'s own
  /// documented contract.
  bool get _subscriptionOk => _subscription?.locked != true;

  Future<void> _confirmAndSend() async {
    final ctrl = _controller;
    if (!ctrl.canSend) return;
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    final count = ctrl.recipientCount ?? 0;
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Зар илгээх үү?',
      message:
          '$count үйлчлүүлэгчид push мэдэгдэл очно. Энэ үйлдлийг буцаах '
          'боломжгүй.',
      confirmLabel: 'Илгээх',
      icon: Icons.campaign_outlined,
      isDangerous: true,
    );
    if (!confirmed || !mounted) return;
    final result = await ctrl.send(title: title, body: body);
    if (!mounted || result == null) return;
    switch (result) {
      case Ok(:final value):
        messageComplete('${value.notified} үйлчлүүлэгчид илгээгдлээ');
        Navigator.of(context).pop(true);
      case Err(:final error):
        final failure = CustomerFailure.classify(
          statusCode: error.statusCode,
          code: error.code,
          fieldErrors: error.fieldErrors,
        );
        if (failure != CustomerFailure.validation) {
          messageError(error.display);
        }
        setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CustomerBroadcastController>.value(
      value: _controller,
      child: Scaffold(
        appBar: AppBar(title: const Text('Зар мэдээ илгээх')),
        body: _loadingSubscription
            ? const AppLoading()
            : PermissionGate(
                permission: 'customers.notify',
                user: _user,
                fallback: const _GateMessage(
                  icon: Icons.lock_outline,
                  message: 'Танд зар мэдээ илгээх эрх байхгүй байна.',
                ),
                child: !_subscriptionOk
                    ? const _GateMessage(
                        icon: Icons.workspace_premium_outlined,
                        message:
                            'Идэвхтэй захиалга (subscription) байхгүй тул '
                            'зар мэдээ илгээх боломжгүй байна.',
                      )
                    : _BroadcastForm(
                        controller: _controller,
                        titleCtrl: _titleCtrl,
                        bodyCtrl: _bodyCtrl,
                        onSend: _confirmAndSend,
                      ),
              ),
      ),
    );
  }
}

class _GateMessage extends StatelessWidget {
  const _GateMessage({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: context.colors.textSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textStyles.body.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BroadcastForm extends StatelessWidget {
  const _BroadcastForm({
    required this.controller,
    required this.titleCtrl,
    required this.bodyCtrl,
    required this.onSend,
  });

  final CustomerBroadcastController controller;
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CustomerBroadcastController>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Not decorative: the server only ever counts account-linked
          // customers. A staff member who thinks every customer just got
          // messaged, when the walk-ins in their ledger never will, is
          // worse served than one told this plainly up front.
          Container(
            padding: const EdgeInsets.all(AppDimens.paddingSM),
            decoration: BoxDecoration(
              color: context.colors.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppDimens.radiusMD),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: AppDimens.iconSM,
                  color: context.colors.accent,
                ),
                const SizedBox(width: AppDimens.paddingSM),
                Expanded(
                  child: Text(
                    'Зөвхөн апп-д бүртгэлтэй (онлайн акаунттай) '
                    'үйлчлүүлэгчид энэ мэдэгдлийг хүлээн авна. Апп '
                    'ашигладаггүй, зөвхөн биечлэн үйлчлүүлдэг '
                    'үйлчлүүлэгчид (walk-in) хүрэхгүй.',
                    style: context.textStyles.body.copyWith(
                      color: context.colors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.paddingMD),
          _RecipientCount(
            state: ctrl.recipientCountState,
            onRetry: ctrl.refresh,
          ),
          const SizedBox(height: 20),
          if (ctrl.lastError != null && ctrl.fieldErrors.isEmpty) ...[
            // Non-field failures — chiefly the 422 `DAILY_LIMIT_REACHED`
            // plan-limit rejection — shown verbatim and inline rather than
            // only as a transient toast, so the message survives long
            // enough to actually be read (and is present for tests).
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimens.paddingSM),
              decoration: BoxDecoration(
                color: context.colors.dangerBg,
                borderRadius: BorderRadius.circular(AppDimens.radiusMD),
              ),
              child: Text(
                ctrl.lastError!.display,
                style: context.textStyles.body.copyWith(
                  color: context.colors.danger,
                ),
              ),
            ),
            const SizedBox(height: AppDimens.paddingSM),
          ],
          TextField(
            controller: titleCtrl,
            enabled: !ctrl.sending,
            decoration: InputDecoration(
              labelText: 'Гарчиг',
              errorText: ctrl.fieldErrors['title'],
            ),
          ),
          const SizedBox(height: AppDimens.paddingSM),
          TextField(
            controller: bodyCtrl,
            enabled: !ctrl.sending,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Агуулга',
              errorText: ctrl.fieldErrors['body'],
            ),
          ),
          const SizedBox(height: AppDimens.paddingLG),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('broadcast_send_button'),
              onPressed: ctrl.canSend ? onSend : null,
              child: ctrl.sending
                  ? const AppLoading(size: 18)
                  : const Text('Илгээх'),
            ),
          ),
          if ((ctrl.recipientCount ?? 0) == 0 &&
              ctrl.recipientCountState is AsyncData) ...[
            const SizedBox(height: AppDimens.paddingXS),
            Text(
              'Хүлээн авагч байхгүй тул илгээх боломжгүй. Илгээх товч '
              'идэвхжихгүй — өдрийн зар илгээх эрхийг дэмий зарцуулахгүйн '
              'тулд хүлээн авагчгүй үед илгээхийг зөвшөөрдөггүй.',
              style: context.textStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _RecipientCount extends StatelessWidget {
  const _RecipientCount({required this.state, required this.onRetry});
  final AsyncValue<int> state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      AsyncLoading() => Row(
        children: [
          const AppLoading(size: 16),
          const SizedBox(width: 10),
          Text(
            'Хүлээн авагчийн тоог ачааллаж байна...',
            style: context.textStyles.body.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
      AsyncError(:final error) => Row(
        children: [
          Expanded(
            child: Text(
              error.display,
              style: context.textStyles.body.copyWith(
                color: context.colors.danger,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Дахин')),
        ],
      ),
      AsyncData(:final value) => Row(
        children: [
          Icon(
            Icons.groups_outlined,
            size: AppDimens.iconMD,
            color: context.colors.accent,
          ),
          const SizedBox(width: AppDimens.paddingSM),
          Text(
            'Хүлээн авагч: $value',
            style: context.textStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: value == 0
                  ? context.colors.danger
                  : context.colors.textPrimary,
            ),
          ),
        ],
      ),
    };
  }
}
