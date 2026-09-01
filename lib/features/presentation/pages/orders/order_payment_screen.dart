import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/models/order.dart';
import 'package:carcare_service/features/presentation/controllers/controllers.dart';
import 'package:carcare_service/shared/widgets/common/common_widgets.dart';

class OrderPaymentScreen extends StatefulWidget {
  final String orderId;
  const OrderPaymentScreen({super.key, required this.orderId});

  @override
  State<OrderPaymentScreen> createState() => _OrderPaymentScreenState();
}

class _OrderPaymentScreenState extends State<OrderPaymentScreen> with WidgetsBindingObserver {
  bool _qpayEnabled = false;
  OrderPayment? _pending;
  bool _qpayLoading = false;
  bool _manualBusy = false;
  bool _launchedBankApp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadQPay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _launchedBankApp && _pending != null) {
      _launchedBankApp = false;
      _checkQPay();
    }
  }

  Future<void> _loadQPay() async {
    final result = await context.read<OrderController>().getQPay(widget.orderId);
    if (!mounted || result == null) return;
    setState(() {
      _qpayEnabled = result.qpayEnabled;
      _pending = result.pending;
    });
  }

  Future<void> _setManualStatus(PaymentStatus status, {double? paidAmount}) async {
    setState(() => _manualBusy = true);
    final ok = await context.read<OrderController>().updatePayment(
      widget.orderId,
      status,
      paidAmount: paidAmount,
    );
    if (!mounted) return;
    setState(() => _manualBusy = false);
    if (ok) _loadQPay();
  }

  Future<void> _createQPay() async {
    setState(() => _qpayLoading = true);
    final payment = await context.read<OrderController>().createQPay(widget.orderId);
    if (!mounted) return;
    setState(() {
      _qpayLoading = false;
      if (payment != null) _pending = payment;
    });
  }

  Future<void> _checkQPay() async {
    if (_pending == null) return;
    setState(() => _qpayLoading = true);
    final result = await context.read<OrderController>().checkQPay(widget.orderId, _pending!.id);
    if (!mounted) return;
    if (result?.paid == true) {
      setState(() {
        _pending = null;
        _qpayLoading = false;
      });
    } else {
      setState(() => _qpayLoading = false);
    }
  }

  Future<void> _cancelQPay() async {
    if (_pending == null) return;
    await context.read<OrderController>().cancelQPay(widget.orderId, _pending!.id);
    if (!mounted) return;
    setState(() => _pending = null);
  }

  void _showPartialSheet(double total, NumberFormat numFmt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PartialAmountSheet(
        total: total,
        numFmt: numFmt,
        onSave: (amt) => _setManualStatus(PaymentStatus.PARTIAL, paidAmount: amt),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final numFmt = NumberFormat('#,###');
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final order = context.watch<OrderController>().detailState.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Төлбөр')),
      body: order == null
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, order, numFmt, dateFmt),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ServiceOrderDetail o,
    NumberFormat numFmt,
    DateFormat dateFmt,
  ) {
    final total = o.totalAmount ?? 0.0;
    final paid = o.paidAmount ?? 0.0;
    final remaining = (total - paid).clamp(0.0, double.infinity);
    final isPaid = o.paymentStatus == PaymentStatus.PAID;

    return ListView(
      padding: const EdgeInsets.all(AppDimens.paddingMD),
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined, size: 18, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text('Төлбөрийн мэдээлэл', style: AppTextStyles.h3),
                    const Spacer(),
                    _PayStatusChip(status: o.paymentStatus),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ── Summary rows ─────────────────────────────────────────────
              _PayRow(label: 'Нийт дүн', value: '${numFmt.format(total.toInt())}₮'),
              _PayRow(
                label: 'Төлсөн дүн',
                value: paid > 0 ? '${numFmt.format(paid.toInt())}₮' : '—',
                valueColor: paid > 0 ? AppColors.good : AppColors.textHint,
                bold: paid > 0,
              ),
              if (remaining > 0)
                _PayRow(
                  label: 'Үлдэгдэл',
                  value: '${numFmt.format(remaining.toInt())}₮',
                  valueColor: AppColors.danger,
                  bold: true,
                ),
              if (o.paidAt != null)
                _PayRow(
                  label: 'Төлсөн огноо',
                  value: dateFmt.format(o.paidAt!),
                  valueColor: AppColors.textSecondary,
                ),

              // ── Manual payment buttons ────────────────────────────────────
              if (!isPaid) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('Төлбөр бүртгэх', style: AppTextStyles.caption),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PayBtn(
                          label: 'Төлөгдсөн',
                          color: AppColors.good,
                          busy: _manualBusy,
                          onTap: () => _setManualStatus(PaymentStatus.PAID),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PayBtn(
                          label: 'Хагас',
                          color: const Color(0xFFF59E0B),
                          busy: _manualBusy,
                          onTap: () => _showPartialSheet(total, numFmt),
                        ),
                      ),
                      if (o.paymentStatus != PaymentStatus.UNPAID) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PayBtn(
                            label: 'Буцаах',
                            color: AppColors.danger,
                            busy: _manualBusy,
                            onTap: () => _setManualStatus(PaymentStatus.UNPAID),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // ── QPay section ──────────────────────────────────────────────
              if (_qpayEnabled && !isPaid) ...[
                const Divider(height: 1),
                _QPaySection(
                  pending: _pending,
                  loading: _qpayLoading,
                  numFmt: numFmt,
                  onCreate: _createQPay,
                  onCheck: _checkQPay,
                  onCancel: _cancelQPay,
                  onBankLaunch: (url) async {
                    final uri = Uri.tryParse(url);
                    if (uri == null) return;
                    if (await canLaunchUrl(uri)) {
                      _launchedBankApp = true;
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Банкны апп нээх боломжгүй байна.')),
                        );
                      }
                    }
                  },
                ),
              ],

              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _PayStatusChip extends StatelessWidget {
  final PaymentStatus status;
  const _PayStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        border: Border.all(color: status.color.withOpacity(0.35)),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: status.color),
      ),
    );
  }
}

class _PayRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const _PayRow({required this.label, required this.value, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.caption),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool busy;
  final VoidCallback onTap;
  const _PayBtn({
    required this.label,
    required this.color,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppDimens.radiusSM),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
        ),
      ),
    );
  }
}

class _QPaySection extends StatelessWidget {
  final OrderPayment? pending;
  final bool loading;
  final NumberFormat numFmt;
  final VoidCallback onCreate;
  final VoidCallback onCheck;
  final VoidCallback onCancel;
  final Future<void> Function(String url) onBankLaunch;

  const _QPaySection({
    required this.pending,
    required this.loading,
    required this.numFmt,
    required this.onCreate,
    required this.onCheck,
    required this.onCancel,
    required this.onBankLaunch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_rounded, size: 15, color: AppColors.accent),
              const SizedBox(width: 6),
              Text('QPay', style: AppTextStyles.captionMedium.copyWith(color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 10),
          if (pending == null) ...[
            SizedBox(
              width: double.infinity,
              child: _QPayOutlineBtn(label: 'QPay QR үүсгэх', loading: loading, onTap: onCreate),
            ),
          ] else ...[
            Text(
              'Үлдэгдэл: ${numFmt.format(pending!.amount.toInt())}₮',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 10),
            if (pending!.qrImage != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSM),
                  ),
                  child: Image.memory(
                    _base64Decode(pending!.qrImage!),
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                ),
              )
            else
              Center(child: Text('QR үүсэхэд хүлээнэ үү...', style: AppTextStyles.caption)),

            // ── Bank app buttons ────────────────────────────────────────────
            if (pending!.urls.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Банкны аппаар төлөх', style: AppTextStyles.caption),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pending!.urls
                    .map((bank) => _BankAppButton(bank: bank, onTap: () => onBankLaunch(bank.link)))
                    .toList(),
              ),
            ],

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _QPayOutlineBtn(label: 'Төлбөр шалгах', loading: loading, onTap: onCheck),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Цуцлах', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Bank brand meta ─────────────────────────────────────────────────────────

class _BankMeta {
  final Color bg;
  final Color fg;
  final String abbr;
  const _BankMeta(this.bg, this.fg, this.abbr);
}

const _kBankMeta = <String, _BankMeta>{
  'khanbank': _BankMeta(Color(0xFF006633), Colors.white, 'ХБ'),
  'golomtbank': _BankMeta(Color(0xFF003087), Colors.white, 'ГБ'),
  'tdbbank': _BankMeta(Color(0xFFCC0000), Colors.white, 'ХХБ'),
  'statebank': _BankMeta(Color(0xFF005B8E), Colors.white, 'ХАБ'),
  'monpay': _BankMeta(Color(0xFF6200EA), Colors.white, 'MP'),
  'socialpay': _BankMeta(Color(0xFF0288D1), Colors.white, 'SP'),
  'bogdbank': _BankMeta(Color(0xFFF57F17), Colors.white, 'ББ'),
  'capitalbank': _BankMeta(Color(0xFFE65100), Colors.white, 'CB'),
  'transbank': _BankMeta(Color(0xFF37474F), Colors.white, 'ТБ'),
  'mostmoney': _BankMeta(Color(0xFFAD1457), Colors.white, 'MM'),
  'xacbank': _BankMeta(Color(0xFF1565C0), Colors.white, 'ХС'),
  'nibank': _BankMeta(Color(0xFF2E7D32), Colors.white, 'NI'),
  'arigbank': _BankMeta(Color(0xFF880E4F), Colors.white, 'АБ'),
  'mbank': _BankMeta(Color(0xFF01579B), Colors.white, 'МБ'),
};

String _bankKey(String link) {
  // "khanbank://pay?..." → "khanbank"
  final scheme = Uri.tryParse(link)?.scheme ?? '';
  return scheme.toLowerCase();
}

_BankMeta _metaFor(String link, String name) {
  final key = _bankKey(link);
  if (_kBankMeta.containsKey(key)) return _kBankMeta[key]!;
  // Fallback: derive color from first char hash
  final code = name.isNotEmpty ? name.codeUnitAt(0) : 65;
  final colors = [
    const Color(0xFF1565C0),
    const Color(0xFF2E7D32),
    const Color(0xFF6A1B9A),
    const Color(0xFF00695C),
    const Color(0xFFC62828),
    const Color(0xFFE65100),
  ];
  return _BankMeta(
    colors[code % colors.length],
    Colors.white,
    name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase(),
  );
}

// ─── Bank app button ──────────────────────────────────────────────────────────

class _BankAppButton extends StatelessWidget {
  final QPayBankUrl bank;
  final VoidCallback onTap;
  const _BankAppButton({required this.bank, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = _metaFor(bank.link, bank.nameMn.isNotEmpty ? bank.nameMn : bank.name);
    final label = bank.nameMn.isNotEmpty ? bank.nameMn : bank.name;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusSM),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo: try network first, fallback to brand avatar
            _BankIcon(bank: bank, meta: meta),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.open_in_new_rounded, size: 11, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

// ─── Bank icon: network logo → brand avatar fallback ─────────────────────────

class _BankIcon extends StatefulWidget {
  final QPayBankUrl bank;
  final _BankMeta meta;
  const _BankIcon({required this.bank, required this.meta});

  @override
  State<_BankIcon> createState() => _BankIconState();
}

class _BankIconState extends State<_BankIcon> {
  bool _loadFailed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.bank.logo.isNotEmpty && !_loadFailed) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image.network(
          widget.bank.logo,
          width: 24,
          height: 24,
          fit: BoxFit.cover,
          errorBuilder: (_, err, st) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _loadFailed = true);
            });
            return _avatar(widget.meta);
          },
        ),
      );
    }
    return _avatar(widget.meta);
  }

  Widget _avatar(_BankMeta meta) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(color: meta.bg, borderRadius: BorderRadius.circular(5)),
    alignment: Alignment.center,
    child: Text(
      meta.abbr,
      style: TextStyle(
        fontSize: meta.abbr.length > 2 ? 6 : 7,
        fontWeight: FontWeight.w800,
        color: meta.fg,
        letterSpacing: -0.3,
      ),
    ),
  );
}

class _QPayOutlineBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _QPayOutlineBtn({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppDimens.radiusSM),
          border: Border.all(color: AppColors.accent.withOpacity(0.35)),
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
      ),
    );
  }
}

Uint8List _base64Decode(String b64) => base64Decode(b64);

// ─── Partial amount bottom sheet ──────────────────────────────────────────────

class _PartialAmountSheet extends StatefulWidget {
  final double total;
  final NumberFormat numFmt;
  final Future<void> Function(double) onSave;
  const _PartialAmountSheet({required this.total, required this.numFmt, required this.onSave});

  @override
  State<_PartialAmountSheet> createState() => _PartialAmountSheetState();
}

class _PartialAmountSheetState extends State<_PartialAmountSheet> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = double.tryParse(_ctrl.text.trim().replaceAll(',', '')) ?? 0;
    if (amt <= 0) return;
    setState(() => _saving = true);
    await widget.onSave(amt);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Хагас төлбөр', style: AppTextStyles.h3),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Нийт дүн: ${widget.numFmt.format(widget.total.toInt())}₮',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Төлсөн дүн (₮) *',
            hint: '0',
            controller: _ctrl,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Хадгалах',
              onPressed: _saving ? null : _save,
              loading: _saving,
            ),
          ),
        ],
      ),
    );
  }
}
