import 'package:flutter/material.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:carcare_service/features/profile/domain/account_repository.dart';
import 'package:carcare_service/features/profile/presentation/controllers/edit_profile_controller.dart';

/// Edit-profile form (lastName, firstName, email, 8-digit phone) — P8-F2.
///
/// Prefills from [user] (defaulting to `Authenticator.user`), matching
/// `profile-form.tsx`'s labels/order exactly (Овог, Нэр, Имэйл, Утас).
/// `PATCH /api/v1/me` is a whole-record replace, so [_save] always sends all
/// four fields. Server `fieldErrors` show inline under the matching field;
/// on success the repository has already refreshed the cached [User], and
/// [onSaved] is invoked with the updated record.
///
/// **Not wired to a route.** Intended path: `/profile/edit`.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    this.repo,
    this.user,
    this.onSaved,
  });

  final AccountRepository? repo;
  final User? user;

  /// Called with the updated [User] after a successful save.
  final ValueChanged<User>? onSaved;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final EditProfileController _controller = EditProfileController(
    repo: widget.repo,
  );

  User? get _user => widget.user ?? Authenticator.user;

  late final _lastNameCtrl = TextEditingController(text: _user?.lastName ?? '');
  late final _firstNameCtrl = TextEditingController(text: _user?.firstName ?? '');
  late final _emailCtrl = TextEditingController(text: _user?.email ?? '');
  late final _phoneCtrl = TextEditingController(text: _user?.phone ?? '');

  Map<String, String> _fieldErrors = const {};
  String? _generalError;

  @override
  void dispose() {
    _controller.dispose();
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _fieldErrors = const {};
      _generalError = null;
    });
    final result = await _controller.submit(
      lastName: _lastNameCtrl.text.trim(),
      firstName: _firstNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
    );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        messageComplete('Профайл шинэчлэгдлээ');
        widget.onSaved?.call(value);
      case Err(:final error):
        setState(() {
          _fieldErrors = error.fieldErrors ?? const {};
          _generalError = (error.fieldErrors == null || error.fieldErrors!.isEmpty)
              ? error.display
              : null;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final saving = _controller.submitting;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Профайл засах'),
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
              TextField(
                key: const ValueKey('edit_profile_last_name'),
                controller: _lastNameCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Овог',
                  errorText: _fieldErrors['lastName'],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('edit_profile_first_name'),
                controller: _firstNameCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Нэр',
                  errorText: _fieldErrors['firstName'],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('edit_profile_email'),
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Имэйл',
                  errorText: _fieldErrors['email'],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('edit_profile_phone'),
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 8,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!saving) _save();
                },
                decoration: InputDecoration(
                  labelText: 'Утас',
                  errorText: _fieldErrors['phone'],
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
