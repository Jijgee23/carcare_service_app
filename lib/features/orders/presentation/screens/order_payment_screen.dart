import 'package:carcare_service/app/shell/shell_chrome.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/presentation/controllers/order_payment_controller.dart';
import 'package:carcare_service/features/orders/presentation/feature_theme.dart';

class OrderPaymentScreen extends StatefulWidget {
  final String orderId;
  final User? user;

  const OrderPaymentScreen({super.key, required this.orderId, this.user});

  @override
  State<OrderPaymentScreen> createState() => _OrderPaymentScreenState();
}

class _OrderPaymentScreenState extends State<OrderPaymentScreen>
    with WidgetsBindingObserver {
  bool _openedBankApp = false;
  String? _shownError;

  OrderPaymentController get _controller =>
      context.read<OrderPaymentController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _openedBankApp) {
      _openedBankApp = false;
      if (mounted) _controller.checkQPay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderPaymentController>(
      builder: (context, controller, _) {
        final error = controller.lastError;
        if (error == null) _shownError = null;
        if (error != null && error.display != _shownError) {
          _shownError = error.display;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(error.display)));
          });
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Төлбөр'),
            actions: const [ShellNotificationBell()],
          ),
          body: !controller.canView
              ? const _ForbiddenPaymentView()
              : _buildBody(context, controller),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, OrderPaymentController controller) {
    final detail = controller.order;
    if (detail == null && controller.isLoading) {
      return const AppLoading();
    }
    if (detail == null) {
      return ErrorStateView(
        onRetry: controller.load,
        message: 'Төлбөрийн мэдээлэл ачаалж чадсангүй.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => controller.refresh(),
      child: ListView(
        padding: const EdgeInsets.all(AppDimens.paddingMD),
        children: [
          _SummaryCard(detail: detail),
          if (controller.qpayCheckError case final error?)
            _QPayFeedbackBanner(
              text: 'QPay шалгалтын алдаа: ${error.message}',
              color: context.opsDanger,
              key: const ValueKey('qpay_check_error'),
            )
          else if (controller.qpayCheckResult case final result?)
            _QPayFeedbackBanner(
              text: result.paid
                  ? 'QPay төлбөр амжилттай баталгаажлаа.'
                  : (result.message ?? 'QPay төлбөр төлөгдөөгүй байна.'),
              color: result.paid ? context.opsGood : context.opsWarning,
              key: const ValueKey('qpay_check_feedback'),
            ),
          const SizedBox(height: 12),
          _LedgerCard(controller: controller),
          if (controller.canCreate &&
              detail.paymentStatus != PaymentStatus.PAID) ...[
            const SizedBox(height: 12),
            _ManualPaymentCard(controller: controller),
          ],
          if (controller.qpay?.qpayEnabled == true &&
              detail.paymentStatus != PaymentStatus.PAID) ...[
            const SizedBox(height: 12),
            _QPayCard(controller: controller, onBankLaunch: _launchBank),
          ],
        ],
      ),
    );
  }

  Future<void> _launchBank(String link) async {
    if (!isSafeBankUrl(link)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Банкны холбоос буруу байна.')),
        );
      }
      return;
    }
    final uri = Uri.parse(link);
    if (!await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Банкны апп нээх боломжгүй байна.')),
        );
      }
      return;
    }
    _openedBankApp = true;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _ForbiddenPaymentView extends StatelessWidget {
  const _ForbiddenPaymentView();
  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.lock_outline_rounded,
    message: 'Төлбөрийн мэдээлэл харах эрхгүй байна.',
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.detail});
  final ServiceOrderDetail detail;
  @override
  Widget build(BuildContext context) {
    final total = detail.totalAmountMoney ?? _fallbackMoney(detail.totalAmount);
    final paid = detail.paidAmountMoney ?? _fallbackMoney(detail.paidAmount);
    final remaining =
        detail.paymentTotals?.remainingAmountMoney ??
        (total == null || paid == null
            ? null
            : Money(_subtractDisplayMoney(total.raw, paid.raw)));
    return _PaymentCard(
      title: 'Төлбөрийн мэдээлэл',
      icon: Icons.payments_outlined,
      children: [
        _PaymentRow(label: 'Нийт дүн', value: _displayMoney(total)),
        _PaymentRow(label: 'Төлсөн дүн', value: _displayMoney(paid)),
        if (remaining != null)
          _PaymentRow(
            label: 'Үлдэгдэл',
            value: _displayMoney(remaining),
            color: context.opsDanger,
            bold: true,
          ),
        _PaymentRow(
          label: 'Төлөв',
          value: detail.paymentStatus.label,
          color: context.paymentStatusColor(detail.paymentStatus),
          bold: true,
        ),
      ],
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.controller});
  final OrderPaymentController controller;
  @override
  Widget build(BuildContext context) {
    final state = controller.paymentsState;
    final payments = state.valueOrNull;
    return _PaymentCard(
      title: 'Төлбөрийн түүх',
      icon: Icons.receipt_long_outlined,
      children: [
        if (state is AsyncLoading && payments == null)
          const Padding(
            padding: EdgeInsets.all(AppDimens.paddingMD),
            child: AppLoading(),
          )
        else if (payments == null || payments.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(AppDimens.paddingMD, AppDimens.paddingXS, AppDimens.paddingMD, AppDimens.paddingMD),
            child: Text('Төлбөрийн бүртгэл алга.'),
          )
        else
          ...payments.map(
            (payment) => _LedgerRow(
              payment: payment,
              canReverse: controller.canDelete,
              busy: controller.isBusy,
              onReverse: () => controller.reverse(payment),
            ),
          ),
      ],
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.payment,
    required this.canReverse,
    required this.busy,
    required this.onReverse,
  });
  final OrderPaymentRecord payment;
  final bool canReverse;
  final bool busy;
  final VoidCallback onReverse;
  @override
  Widget build(BuildContext context) {
    final date = DateFormat('yyyy-MM-dd HH:mm')
        .format(payment.paidAt ?? payment.createdAt);
    return ListTile(
      dense: true,
      title: Text(
        '${_displayMoney(payment.amountMoney)} · ${_methodLabel(payment.method)}',
      ),
      subtitle: Text('$date · ${_recordStatusLabel(payment.status)}'),
      trailing: payment.status == OrderPaymentRecordStatus.PAID && canReverse
          ? IconButton(
              key: ValueKey('reverse_payment_${payment.id}'),
              tooltip: 'Буцаах',
              onPressed: busy ? null : onReverse,
              icon: const Icon(Icons.undo_rounded),
            )
          : null,
    );
  }
}

class _ManualPaymentCard extends StatefulWidget {
  const _ManualPaymentCard({required this.controller});
  final OrderPaymentController controller;
  @override
  State<_ManualPaymentCard> createState() => _ManualPaymentCardState();
}

class _ManualPaymentCardState extends State<_ManualPaymentCard> {
  final _amount = TextEditingController();
  OrderPaymentMethod _method = OrderPaymentMethod.CASH;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PaymentCard(
    title: 'Төлбөр бүртгэх',
    icon: Icons.add_card_outlined,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppDimens.paddingMD, AppDimens.paddingXS, AppDimens.paddingMD, AppDimens.paddingXS),
        child: TextField(
          key: const ValueKey('payment_amount_input'),
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Дүн', suffixText: '₮'),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingMD, vertical: AppDimens.paddingXS),
        child: DropdownButtonFormField<OrderPaymentMethod>(
          key: const ValueKey('payment_method_input'),
          value: _method,
          decoration: const InputDecoration(labelText: 'Арга'),
          items: const [
            DropdownMenuItem(
              value: OrderPaymentMethod.CASH,
              child: Text('Бэлэн'),
            ),
            DropdownMenuItem(
              value: OrderPaymentMethod.CARD,
              child: Text('Карт'),
            ),
            DropdownMenuItem(
              value: OrderPaymentMethod.OTHER,
              child: Text('Бусад'),
            ),
          ],
          onChanged: widget.controller.isBusy
              ? null
              : (value) => setState(() => _method = value ?? _method),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(AppDimens.paddingMD, AppDimens.paddingSM, AppDimens.paddingMD, AppDimens.paddingMD),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('create_manual_payment'),
            onPressed: widget.controller.isBusy
                ? null
                : () => widget.controller.createManual(
                    amount: _amount.text,
                    method: _method,
                  ),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Бүртгэх'),
          ),
        ),
      ),
    ],
  );
}

class _QPayCard extends StatelessWidget {
  const _QPayCard({required this.controller, required this.onBankLaunch});
  final OrderPaymentController controller;
  final Future<void> Function(String) onBankLaunch;
  @override
  Widget build(BuildContext context) {
    final pending = controller.qpay?.pending;
    return _PaymentCard(
      title: 'QPay',
      icon: Icons.qr_code_rounded,
      children: [
        if (pending == null && controller.canCreate)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppDimens.paddingMD, AppDimens.paddingXS, AppDimens.paddingMD, AppDimens.paddingMD),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const ValueKey('create_qpay'),
                onPressed: controller.isBusy ? null : controller.createQPay,
                child: const Text('QPay QR үүсгэх'),
              ),
            ),
          )
        else if (pending == null)
          const Padding(
            padding: EdgeInsets.fromLTRB(AppDimens.paddingMD, AppDimens.paddingXS, AppDimens.paddingMD, AppDimens.paddingMD),
            child: Text('QPay нэхэмжлэл үүсгэх эрхгүй байна.'),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(AppDimens.paddingMD, AppDimens.paddingXS, AppDimens.paddingMD, AppDimens.paddingXS),
            child: Text(
              'Нэхэмжлэл хүлээгдэж байна · ${_displayMoney(pending.amountMoney)}',
            ),
          ),
          if (decodeQrImage(pending.qrImage) case final bytes?)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Container(
                  // QR codes need a guaranteed-white backing to stay
                  // scannable, independent of the active theme.
                  color: Colors.white,
                  padding: const EdgeInsets.all(AppDimens.paddingSM),
                  child: Image.memory(
                    bytes,
                    width: 180,
                    height: 180,
                    errorBuilder: (_, _, _) => const _QrFallback(),
                  ),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(AppDimens.paddingMD),
              child: Center(child: _QrFallback()),
            ),
          if (pending.urls.any((item) => isSafeBankUrl(item.link)))
            Padding(
              padding: const EdgeInsets.fromLTRB(AppDimens.paddingMD, 0, AppDimens.paddingMD, AppDimens.paddingSM),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final bank in pending.urls)
                    if (isSafeBankUrl(bank.link))
                      OutlinedButton(
                        onPressed: controller.isBusy
                            ? null
                            : () => onBankLaunch(bank.link),
                        child: Text(bank.nameMn),
                      ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppDimens.paddingMD, AppDimens.paddingXS, AppDimens.paddingMD, AppDimens.paddingMD),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('check_qpay'),
                    onPressed: controller.canEdit && !controller.isBusy
                        ? controller.checkQPay
                        : null,
                    child: const Text('Төлбөр шалгах'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  key: const ValueKey('cancel_qpay'),
                  onPressed: controller.canDelete && !controller.isBusy
                      ? controller.cancelQPay
                      : null,
                  child: const Text('Цуцлах'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _QPayFeedbackBanner extends StatelessWidget {
  const _QPayFeedbackBanner({
    super.key,
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(AppDimens.radiusMD),
      border: Border.all(color: color.withOpacity(0.35)),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    ),
  );
}

class _QrFallback extends StatelessWidget {
  const _QrFallback();
  @override
  Widget build(BuildContext context) => Text(
    'QR зураг боломжгүй байна. Банкны аппын холбоос ашиглана уу.',
    textAlign: TextAlign.center,
    style: context.textStyles.caption,
  );
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: context.opsAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.h3,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        ...children,
      ],
    ),
  );
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.label,
    required this.value,
    this.color,
    this.bold = false,
  });
  final String label;
  final String value;
  final Color? color;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    child: Row(
      children: [
        Text(label, style: context.textStyles.caption),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: color ?? context.opsTextPrimary,
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

String _displayMoney(Money? money) => money == null ? '—' : '${money.raw}₮';
Money? _fallbackMoney(double? value) =>
    value == null ? null : Money(value.toString());

String _methodLabel(OrderPaymentMethod method) => switch (method) {
  OrderPaymentMethod.CASH => 'Бэлэн',
  OrderPaymentMethod.CARD => 'Карт',
  OrderPaymentMethod.OTHER => 'Бусад',
  OrderPaymentMethod.QPAY => 'QPay',
  OrderPaymentMethod.BANK_TRANSFER => 'Шилжүүлэг',
};

String _recordStatusLabel(OrderPaymentRecordStatus status) => switch (status) {
  OrderPaymentRecordStatus.PENDING => 'Хүлээгдэж байна',
  OrderPaymentRecordStatus.PAID => 'Төлөгдсөн',
  OrderPaymentRecordStatus.CANCELLED => 'Буцаасан',
  OrderPaymentRecordStatus.FAILED => 'Амжилтгүй',
};

/// Decodes both a data URI and a plain base64 QR value defensively.
Uint8List? decodeQrImage(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final comma = value.indexOf(',');
  final encoded = value.toLowerCase().startsWith('data:')
      ? (comma < 0 ? null : value.substring(comma + 1))
      : value;
  if (encoded == null || encoded.isEmpty) return null;
  try {
    final bytes = base64.decode(encoded);
    return bytes.isEmpty ? null : Uint8List.fromList(bytes);
  } on FormatException {
    return null;
  }
}

bool isSafeBankUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  final scheme = uri?.scheme.toLowerCase() ?? '';
  if (uri == null || scheme.isEmpty) {
    return false;
  }
  if (scheme == 'https') return uri.host.isNotEmpty;
  return const {
    'khanbank',
    'golomtbank',
    'tdbbank',
    'statebank',
    'monpay',
    'socialpay',
    'bogdbank',
    'mostmoney',
    'qpay',
  }.contains(scheme);
}

String _subtractDisplayMoney(String left, String right) {
  final a = _parts(left);
  final b = _parts(right);
  final scale = a.$2.length > b.$2.length ? a.$2.length : b.$2.length;
  final av =
      BigInt.parse(a.$1) * BigInt.from(10).pow(scale) +
      _fractionPart(a.$2, scale);
  final bv =
      BigInt.parse(b.$1) * BigInt.from(10).pow(scale) +
      _fractionPart(b.$2, scale);
  final value = av - bv;
  if (value <= BigInt.zero) return '0';
  final raw = value.toString().padLeft(scale + 1, '0');
  if (scale == 0) return raw;
  return '${raw.substring(0, raw.length - scale)}.${raw.substring(raw.length - scale)}';
}

(String, String) _parts(String value) {
  final split = value.split('.');
  return (split.first, split.length == 1 ? '' : split.last);
}

// scale == 0 үед бутархай хоосон — BigInt.parse('') шиддэг.
BigInt _fractionPart(String digits, int scale) {
  final padded = digits.padRight(scale, '0');
  return padded.isEmpty ? BigInt.zero : BigInt.parse(padded);
}
