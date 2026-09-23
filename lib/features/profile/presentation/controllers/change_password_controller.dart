import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/profile/data/account_repository.dart';
import 'package:carcare_service/features/profile/domain/account_repository.dart';

/// Change-password form submission — P8-F2.
///
/// Client-side validation mirrors `lib/account/password.ts`'s
/// `changePassword` core exactly (same Mongolian messages), so a caller sees
/// the identical wording whether the failure is caught locally or comes back
/// from the server as a `fieldErrors` entry.
///
/// D-179: on success the server has already revoked every other web session
/// and mobile refresh token, keeping this device's token alive — see
/// [PasswordChangeResult]'s doc comment. This controller does not log out or
/// re-authenticate; the screen only needs to show a success message noting
/// other devices were signed out.
///
/// D-181: a `429 RATE_LIMITED` [Result] is forwarded as-is (not merged into
/// `fieldErrors`) so the screen can show the distinct rate-limit message
/// instead of the generic failure text.
class ChangePasswordController extends ChangeNotifier {
  ChangePasswordController({AccountRepository? repo})
    : _repo = repo ?? RemoteAccountRepository();

  final AccountRepository _repo;
  bool submitting = false;

  /// Талбар бүрийг шалгаад, буруу бол мессежийг буцаана (хоосон бол хүчинтэй).
  /// Матчлана `lib/account/password.ts`-ийн `changePassword`-той.
  static Map<String, String> validate({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    final fieldErrors = <String, String>{};
    if (currentPassword.isEmpty) {
      fieldErrors['currentPassword'] = 'Одоогийн нууц үгээ оруулна уу.';
    }
    if (newPassword.length < 8) {
      fieldErrors['newPassword'] = 'Шинэ нууц үг 8+ тэмдэгт байна.';
    }
    if (newPassword != confirmPassword) {
      fieldErrors['confirmPassword'] = 'Нууц үг таарахгүй байна.';
    }
    return fieldErrors;
  }

  Future<Result<PasswordChangeResult>> submit({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    submitting = true;
    notifyListeners();
    final result = await _repo.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
    submitting = false;
    notifyListeners();
    return result;
  }
}
