import 'package:flutter/foundation.dart';

import 'package:carservice_business/core/services/auth_storage.dart';
import 'package:carservice_business/core/utils/result.dart';
import 'package:carservice_business/features/profile/data/account_closure_repository.dart';

/// Self-service account deactivate/delete form — Task 8. Mirrors
/// `ChangePasswordController`'s style: a thin `ChangeNotifier` wrapping the
/// repository, with no local validation beyond what the screen already
/// enforces (a 6-digit OTP).
///
/// [onClosed] is the app's own logout flow (`AuthController.logout`, the same
/// one `sessions_controller.dart`'s `pendingLogout` hands off to via
/// `sessions_screen.dart:64`). It is only run after a successful deactivate
/// or delete. By that point the server has already revoked every refresh
/// token for this account, so [onClosed] must not attempt a refresh of its
/// own first — `AuthController.logout()` already treats its server round
/// trip as best-effort and unconditionally clears local state, so it is safe
/// to reuse as-is.
class AccountClosureController extends ChangeNotifier {
  AccountClosureController(this._repo, {required this.onClosed});

  final AccountClosureRepository _repo;
  final Future<void> Function() onClosed;

  bool requestingOtp = false;
  bool submitting = false;

  /// Set on the most recent failure; cleared at the start of the next call.
  String? error;

  /// Set when the server refused with `409 LAST_OWNER` — the caller is the
  /// tenant's last active owner and must hand off ownership before closing
  /// their own account. Surfaced distinctly from [error] so the screen can
  /// show the dedicated copy without also logging out.
  bool lastOwnerBlocked = false;

  /// The masked phone number the OTP was sent to, once requested.
  String? maskedPhone;

  /// Pass [forDelete] when the user chose delete-forever, so the server can
  /// refuse (`409 OPEN_ORDERS`, shown via [error]) before sending an SMS.
  Future<bool> requestOtp({bool forDelete = false}) async {
    requestingOtp = true;
    error = null;
    notifyListeners();
    final result = await _repo.requestOtp(forDelete: forDelete);
    requestingOtp = false;
    switch (result) {
      case Ok(:final value):
        maskedPhone = value;
        notifyListeners();
        return true;
      case Err(error: final err):
        error = err.display;
        notifyListeners();
        return false;
    }
  }

  /// Submits the deactivate or delete request. Returns `true` on success,
  /// after [onClosed] has already run.
  Future<bool> submit({
    required bool deleteForever,
    required String code,
  }) async {
    submitting = true;
    error = null;
    lastOwnerBlocked = false;
    notifyListeners();

    // Guards against this device's own `account_closed` push, which the
    // backend can deliver before this call's HTTP response returns — see
    // `Authenticator.accountClosureInFlight`'s doc. Covers the repository
    // call and `onClosed()` (this device's own logout), since the push could
    // in principle still land in that short window too.
    Authenticator.accountClosureInFlight = true;
    try {
      final result = deleteForever
          ? await _repo.delete(code)
          : await _repo.deactivate(code);
      submitting = false;

      switch (result) {
        case Ok():
          notifyListeners();
          await onClosed();
          return true;
        case Err(error: final err):
          if (err.code == 'LAST_OWNER') {
            lastOwnerBlocked = true;
            error =
                'Та байгууллагын цорын ганц эзэмшигч тул эхлээд өөр эзэмшигч '
                'томилно уу.';
          } else if (err.code == 'OTP_INVALID') {
            error = 'Код буруу эсвэл хугацаа дууссан байна.';
          } else {
            error = err.display;
          }
          notifyListeners();
          return false;
      }
    } finally {
      Authenticator.accountClosureInFlight = false;
    }
  }
}
