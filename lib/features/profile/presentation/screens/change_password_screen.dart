import 'package:flutter/material.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:carcare_service/features/profile/domain/account_repository.dart';
import 'package:carcare_service/features/profile/presentation/controllers/change_password_controller.dart';
import 'package:carcare_service/features/profile/presentation/widgets/password_field.dart';

const _rateLimitedMessage =
    'Хэт олон удаа буруу оролдсон тул түр хугацаагаар хориглогдлоо. '
    '15 минутын дараа дахин оролдоно уу.';

/// Change-password form (current, new, confirm) with show/hide toggles —
/// P8-F2. Client-side validation and wording mirror
/// `ChangePasswordController.validate` / `lib/account/password.ts` exactly.
///
/// Server `fieldErrors` show inline under the matching field. A
/// `429 RATE_LIMITED` [Result] (D-181) shows [_rateLimitedMessage] instead of
/// the generic failure text. On success (D-179) the server has revoked every
/// other web session and mobile refresh token but kept this device signed
/// in, so [_save] shows a success message noting other devices were logged
/// out rather than navigating away or forcing re-authentication.
///
/// **Not wired to a route.** Intended path: `/profile/password`.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({
    super.key,
    this.repo,
    this.onChanged,
  });

  final AccountRepository? repo;

  /// Called after a successful password change.
  final VoidCallback? onChanged;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  late final ChangePasswordController _controller = ChangePasswordController(
    repo: widget.repo,
  );

  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  Map<String, String> _fieldErrors = const {};
  String? _generalError;

  @override
  void dispose() {
    _controller.dispose();
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _fieldErrors = const {};
      _generalError = null;
    });

    final currentPassword = _currentCtrl.text;
    final newPassword = _newCtrl.text;
    final confirmPassword = _confirmCtrl.text;

    final clientErrors = ChangePasswordController.validate(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
    if (clientErrors.isNotEmpty) {
      setState(() => _fieldErrors = clientErrors);
      return;
    }

    final result = await _controller.submit(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        _currentCtrl.clear();
        _newCtrl.clear();
        _confirmCtrl.clear();
        messageComplete('Нууц үг солигдлоо. Бусад төхөөрөмжөөс гарлаа.');
        widget.onChanged?.call();
      case Err(:final error):
        setState(() {
          if (error.code == 'RATE_LIMITED' || error.statusCode == 429) {
            _generalError = _rateLimitedMessage;
            _fieldErrors = const {};
          } else {
            _fieldErrors = error.fieldErrors ?? const {};
            _generalError = (error.fieldErrors == null || error.fieldErrors!.isEmpty)
                ? error.display
                : null;
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final saving = _controller.submitting;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Нууц үг солих'),
        actions: [
          TextButton(
            onPressed: saving ? null : _save,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Хадгалах'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_generalError != null) ...[
                Text(
                  _generalError!,
                  style: TextStyle(color: context.colors.danger),
                ),
                const SizedBox(height: 10),
              ],
              PasswordField(
                key: const ValueKey('change_password_current'),
                controller: _currentCtrl,
                labelText: 'Одоогийн нууц үг',
                errorText: _fieldErrors['currentPassword'],
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              PasswordField(
                key: const ValueKey('change_password_new'),
                controller: _newCtrl,
                labelText: 'Шинэ нууц үг',
                helperText: _fieldErrors['newPassword'] == null ? '8+ тэмдэгт' : null,
                errorText: _fieldErrors['newPassword'],
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              PasswordField(
                key: const ValueKey('change_password_confirm'),
                controller: _confirmCtrl,
                labelText: 'Шинэ нууц үг давтан',
                errorText: _fieldErrors['confirmPassword'],
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!saving) _save();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
