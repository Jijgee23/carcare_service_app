import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:carservice_business/app/theme/app_theme.dart';
import 'package:carservice_business/core/widgets/common/common_widgets.dart';
import 'package:carservice_business/core/widgets/dialogs/confirm_sheet.dart';
import 'package:carservice_business/core/widgets/dialogs/message.dart';
import 'package:carservice_business/features/auth/presentation/controllers/auth_controller.dart';
import 'package:carservice_business/features/profile/data/account_closure_repository.dart';
import 'package:carservice_business/features/profile/presentation/controllers/account_closure_controller.dart';

/// Self-service account deactivate/delete — Task 8. Scope is the staff
/// user's own `User` only; tenant/org data is untouched (D1).
///
/// * "Түр хаах" (deactivate) has no expiry — logging back in reactivates the
///   account (D3/D4).
/// * "Бүрмөсөн устгах" (delete forever) anonymizes the account immediately
///   and cannot be undone (D2) — confirmed with an extra dialog before the
///   OTP is even accepted.
///
/// Both require an OTP sent to the account's own phone. On success the
/// screen runs the app's normal [AuthController.logout] flow via
/// [AccountClosureController.onClosed] — see that controller's doc comment
/// for why a forced refresh is never attempted first.
class AccountClosureScreen extends StatefulWidget {
  const AccountClosureScreen({super.key, this.repository, this.onClosed});

  final AccountClosureRepository? repository;

  /// Overrides the logout flow the controller runs on success. Tests use
  /// this to avoid needing a real `AuthController`/provider tree — screens
  /// pushed via the router leave it unset and get the real logout.
  final Future<void> Function()? onClosed;

  @override
  State<AccountClosureScreen> createState() => _AccountClosureScreenState();
}

enum _ClosureKind { deactivate, delete }

class _AccountClosureScreenState extends State<AccountClosureScreen> {
  late final AccountClosureController _controller = AccountClosureController(
    widget.repository ?? RemoteAccountClosureRepository(),
    onClosed: widget.onClosed ??
        () => context.read<AuthController>().logout(serverCleanup: false),
  );

  _ClosureKind? _selected;
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _select(_ClosureKind kind) {
    setState(() {
      _selected = kind;
      _codeController.clear();
    });
    _controller.maskedPhone = null;
  }

  void _reset() {
    setState(() {
      _selected = null;
      _codeController.clear();
    });
  }

  Future<void> _requestOtp() async {
    await _controller.requestOtp(forDelete: _selected == _ClosureKind.delete);
    if (mounted) setState(() {});
  }

  Future<void> _confirm() async {
    final kind = _selected;
    if (kind == null) return;
    final code = _codeController.text.trim();
    final deleteForever = kind == _ClosureKind.delete;

    if (deleteForever) {
      final confirmed = await ConfirmSheet.show(
        context,
        title: 'Бүрмөсөн устгах уу?',
        message:
            'Энэ үйлдлийг буцаах боломжгүй. Бүртгэл бүрмөсөн устана.',
        confirmLabel: 'Устгах',
        icon: Icons.delete_forever_rounded,
        isDangerous: true,
      );
      if (!confirmed || !mounted) return;
    }

    final success = await _controller.submit(
      deleteForever: deleteForever,
      code: code,
    );
    if (success) {
      // Global toast — shown even though logout has already unmounted us.
      messageComplete(
        deleteForever ? 'Бүртгэл устгагдлаа' : 'Бүртгэл идэвхгүй боллоо',
      );
    }
    if (!mounted) return;
    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        leading: _selected == null ? null : BackButton(onPressed: _reset),
        title: const Text('Бүртгэл хаах'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.paddingMD),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _selected == null
                ? _OptionList(onSelected: _select)
                : _ClosureStep(
                    kind: _selected!,
                    maskedPhone: _controller.maskedPhone,
                    codeController: _codeController,
                    requestingOtp: _controller.requestingOtp,
                    submitting: _controller.submitting,
                    error: _controller.error,
                    onRequestOtp: _requestOtp,
                    onConfirm: _confirm,
                  ),
          ),
        ),
      ),
    );
  }
}

class _OptionList extends StatelessWidget {
  const _OptionList({required this.onSelected});

  final ValueChanged<_ClosureKind> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _OptionCard(
        key: const ValueKey('account_closure_deactivate_option'),
        title: 'Идэвхгүй болгох',
        description:
            'Бүртгэл нуугдана. Хүссэн үедээ дахин нэвтэрч сэргээнэ.',
        destructive: false,
        onTap: () => onSelected(_ClosureKind.deactivate),
      ),
      const SizedBox(height: 12),
      _OptionCard(
        key: const ValueKey('account_closure_delete_option'),
        title: 'Бүрмөсөн устгах',
        description:
            "Нэр, утас, имэйл устгагдана. Таны хийсэн ажил байгууллагын "
            "түүхэнд 'Устгагдсан ажилтан' нэрээр үлдэнэ.",
        destructive: true,
        onTap: () => onSelected(_ClosureKind.delete),
      ),
    ],
  );
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    super.key,
    required this.title,
    required this.description,
    required this.destructive,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.textStyles.h3.copyWith(
              color: destructive ? context.colors.danger : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(description, style: context.textStyles.caption),
        ],
      ),
    );
  }
}

class _ClosureStep extends StatelessWidget {
  const _ClosureStep({
    required this.kind,
    required this.maskedPhone,
    required this.codeController,
    required this.requestingOtp,
    required this.submitting,
    required this.error,
    required this.onRequestOtp,
    required this.onConfirm,
  });

  final _ClosureKind kind;
  final String? maskedPhone;
  final TextEditingController codeController;
  final bool requestingOtp;
  final bool submitting;
  final String? error;
  final Future<void> Function() onRequestOtp;
  final Future<void> Function() onConfirm;

  bool get _delete => kind == _ClosureKind.delete;

  @override
  Widget build(BuildContext context) {
    final busy = requestingOtp || submitting;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _delete ? 'Бүрмөсөн устгах' : 'Идэвхгүй болгох',
            style: context.textStyles.h2.copyWith(
              color: _delete ? context.colors.danger : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _delete
                ? "Нэр, утас, имэйл устгагдана. Таны хийсэн ажил "
                      "байгууллагын түүхэнд 'Устгагдсан ажилтан' нэрээр "
                      "үлдэнэ."
                : 'Бүртгэл нуугдана. Хүссэн үедээ дахин нэвтэрч сэргээнэ.',
            style: context.textStyles.caption,
          ),
          const SizedBox(height: 20),
          // Код авах алхамд гарсан алдаа (409 OPEN_ORDERS, 429 throttle г.м.) —
          // доорх код оруулах хэсэг хараахан харагдаагүй тул энд харуулна.
          if (maskedPhone == null && error != null) ...[
            Text(
              error!,
              key: const ValueKey('account_closure_request_error'),
              style: TextStyle(color: context.colors.danger),
            ),
            const SizedBox(height: 12),
          ],
          if (maskedPhone == null)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                key: const ValueKey('account_closure_request_otp'),
                style: _delete
                    ? FilledButton.styleFrom(
                        backgroundColor: context.colors.danger,
                      )
                    : null,
                onPressed: busy ? null : onRequestOtp,
                child: requestingOtp
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Код авах'),
              ),
            )
          else ...[
            Text('$maskedPhone дугаарт код илгээлээ'),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('account_closure_code_field'),
              controller: codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofillHints: const [AutofillHints.oneTimeCode],
              style: const TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.w700),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                labelText: 'Баталгаажуулах код',
                hintText: '000000',
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: TextStyle(color: context.colors.danger)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                key: const ValueKey('account_closure_confirm'),
                style: _delete
                    ? FilledButton.styleFrom(
                        backgroundColor: context.colors.danger,
                      )
                    : null,
                onPressed: busy ? null : onConfirm,
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_delete ? 'Устгах' : 'Идэвхгүй болгох'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
