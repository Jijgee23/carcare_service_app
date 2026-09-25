import 'dart:async';

import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/services/branch_service.dart';
import 'package:carcare_service/core/services/device_service.dart';
import 'package:carcare_service/core/services/saved_login_store.dart';
import 'package:carcare_service/core/services/subscription_service.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

enum AuthState { firstInstall, policyNotAgreed, noLogged, authorized, finding }

/// Login card steps. `identifier` asks for email **or** phone; the server's
/// `check-email` decides between [password], [activate] and [notRegistered].
/// [resetPassword] is the self-service "forgot password" flow.
enum LoginStep { identifier, password, activate, notRegistered, resetPassword }

/// One pre-login API reply. Every HTTP status comes back as a value — no
/// exception, no global toast, and never through the token interceptor's
/// "401 → force logout" path (a wrong password or OTP is a 401 here and
/// must not reset the login screen).
class AuthResponse {
  const AuthResponse(this.status, this.data);

  final int status;
  final Map<String, dynamic> data;

  bool get ok => status >= 200 && status < 300;

  /// The server's `{ error }` message, verbatim.
  String? get error => data['error'] as String?;
}

typedef AuthTransport = Future<AuthResponse> Function(
  String path,
  Map<String, dynamic> body,
);

Future<AuthResponse> _dioTransport(
  String path,
  Map<String, dynamic> body,
) async {
  final res = await ApiService.instance.dio.post<dynamic>(
    path,
    data: body,
    options: Options(validateStatus: (_) => true),
  );
  final data = res.data;
  return AuthResponse(
    res.statusCode ?? 0,
    data is Map ? Map<String, dynamic>.from(data) : const {},
  );
}

/// Staff sign-in against the tenant mobile API (`/api/v1/auth/*`):
///
/// - `check-email {identifier}` → `password` | `activate` | `not_registered`
/// - `login {identifier, password}` → tokens
/// - `activate/request-otp`, `activate {identifier, code, password}` → tokens
///   (first sign-in: the SMS code sets the initial password)
/// - `password/request-otp`, `password/reset {identifier, code, password}`
///   → forgot password; on success the user signs in with the new password
///
/// `identifier` is an email or a phone number; after `check-email` the
/// controller always sends the server's canonical value back.
class AuthController extends ChangeNotifier {
  AuthController({
    AuthTransport? transport,
    SavedLoginStore? savedLogins,
    Future<void> Function()? onSignedIn,
  }) : _post = transport ?? _dioTransport,
       _savedLogins = savedLogins ?? HiveSavedLoginStore.instance,
       _onSignedIn = onSignedIn ?? DeviceService.instance.registerAfterLogin;

  final AuthTransport _post;
  final SavedLoginStore _savedLogins;

  /// Post-login side effect (push-token registration); injectable for tests.
  final Future<void> Function() _onSignedIn;

  /// Last account that signed in on this device (no secrets) — prefills the
  /// identifier on the login page, including right after logout.
  SavedLogin? savedLogin;

  /// Seconds before an SMS code can be requested again — keeps staff well
  /// inside the server's OTP throttle.
  static const resendCooldownSeconds = 60;

  bool loading = false;
  AuthState authState = AuthState.finding;
  LoginStep step = LoginStep.identifier;

  final identifierCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  final newPasswordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  /// Canonical identifier from `check-email` (lowercase email / 8-digit phone).
  String? _identifier;

  String? maskedPhone;

  /// Set when login answered 423 — the password card then offers a reset.
  bool lockedOut = false;

  /// Inline error for the current card (wrong password, wrong code, …).
  String? errorText;

  int resendIn = 0;
  Timer? _resendTimer;

  String get identifierForDisplay {
    final typed = identifierCtrl.text.trim();
    return typed.isNotEmpty ? typed : (_identifier ?? '');
  }

  /// Whether the user typed a phone number rather than an email.
  bool get isPhoneIdentifier => !identifierForDisplay.contains('@');

  String get _canonical => _identifier ?? identifierCtrl.text.trim();

  @override
  void dispose() {
    _resendTimer?.cancel();
    identifierCtrl.dispose();
    passwordCtrl.dispose();
    otpCtrl.dispose();
    newPasswordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _setLoading(bool v) {
    loading = v;
    notifyListeners();
  }

  void setAuthState(AuthState v) {
    authState = v;
    notifyListeners();
  }

  void _clearSecrets() {
    passwordCtrl.clear();
    otpCtrl.clear();
    newPasswordCtrl.clear();
    confirmPasswordCtrl.clear();
  }

  void resetToIdentifier() {
    step = LoginStep.identifier;
    _clearSecrets();
    _identifier = null;
    maskedPhone = null;
    lockedOut = false;
    errorText = null;
    _stopCooldown();
    notifyListeners();
  }

  void clearError() {
    if (errorText == null) return;
    errorText = null;
    notifyListeners();
  }

  /// Runs one auth call with the loading flag; a network failure becomes a
  /// friendly [errorText] instead of an exception.
  Future<AuthResponse?> _call(String path, Map<String, dynamic> body) async {
    _setLoading(true);
    errorText = null;
    try {
      final res = await _post(path, body);
      if (res.status == 429 && res.error == null) {
        errorText =
            'Хэт олон хүсэлт илгээлээ. Түр хүлээгээд дахин оролдоно уу.';
      } else if (res.status >= 500) {
        errorText = 'Серверийн алдаа гарлаа. Дахин оролдоно уу.';
      }
      return res;
    } on DioException {
      errorText = 'Сервертэй холбогдож чадсангүй. Интернэтээ шалгана уу.';
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ─── Resend cooldown ───────────────────────────────────────────────────────

  void _startCooldown() {
    _resendTimer?.cancel();
    resendIn = resendCooldownSeconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      resendIn--;
      if (resendIn <= 0) {
        resendIn = 0;
        t.cancel();
      }
      notifyListeners();
    });
  }

  void _stopCooldown() {
    _resendTimer?.cancel();
    resendIn = 0;
  }

  // ─── App start ─────────────────────────────────────────────────────────────

  Future<void> loadUser() async {
    Authenticator.onUnauthorized = logout;
    final user = Authenticator.user;
    if (user != null) {
      setAuthState(AuthState.authorized);
      return;
    }
    await _prefillIdentifier();
    setAuthState(AuthState.noLogged);
  }

  Future<void> logout() async {
    // Best-effort server cleanup before clearing local state — a failure here
    // must never block local sign-out. After a forced 401 logout the session
    // is already gone, so there is nothing to send.
    if (Authenticator.user != null) {
      try {
        // Unregister first: this call can itself refresh (rotate) the tokens…
        final unregistered = await DeviceService.instance.unregister();
        // …so read the refresh token only now. Reading it earlier revoked an
        // already-rotated token and left the new one valid for 7 days.
        final refreshToken = Authenticator.user?.refreshToken;
        if (refreshToken != null && refreshToken.isNotEmpty) {
          final res = await api(
            Api.post,
            'auth/logout',
            body: {'refreshToken': refreshToken},
          );
          if (res != null && res.statusCode == 200) {
            debugPrint('Logout successful, device unregistered: $unregistered');
          } else {
            debugPrint('Logout failed, device unregistered: $unregistered');
          }
        }
      } catch (_) {}
    }

    // Always — forced logouts too — so the next account on this device never
    // sees the previous tenant's branches or subscription state.
    _clearSessionCaches();
    await Authenticator.clear();
    step = LoginStep.identifier;
    _clearSecrets();
    _identifier = null;
    maskedPhone = null;
    lockedOut = false;
    errorText = null;
    _stopCooldown();
    await _prefillIdentifier();
    setAuthState(AuthState.noLogged);
  }

  void _clearSessionCaches() {
    SubscriptionService.instance.invalidate();
    BranchService.instance.invalidate();
  }

  /// Puts the last signed-in identifier back into the field (email or phone,
  /// exactly as typed). Leaves the field alone when nothing is saved.
  Future<void> _prefillIdentifier() async {
    savedLogin = await _savedLogins.read();
    final saved = savedLogin?.identifier;
    if (saved != null && saved.isNotEmpty) identifierCtrl.text = saved;
  }

  // ─── Step 1: имэйл / утас шалгах ──────────────────────────────────────────

  Future<void> checkIdentifier() async {
    final raw = identifierCtrl.text.trim();
    if (raw.isEmpty) {
      errorText = 'Имэйл эсвэл утасны дугаараа оруулна уу.';
      notifyListeners();
      return;
    }
    final res = await _call('auth/check-email', {'identifier': raw});
    if (res == null || errorText != null) return notifyListeners();
    if (!res.ok) {
      errorText = res.error ?? 'Имэйл эсвэл утасны дугаар буруу.';
      return notifyListeners();
    }
    _identifier = res.data['identifier'] as String? ?? raw;
    lockedOut = false;
    switch (res.data['status']) {
      case 'password':
        step = LoginStep.password;
      case 'activate':
        step = LoginStep.activate;
        maskedPhone = res.data['maskedPhone'] as String?;
        if (res.data['otpSent'] == false) {
          // Code not sent (e.g. throttled) — stay on the step so the user can
          // resend, and say why.
          errorText = res.data['message'] as String?;
        } else {
          _startCooldown();
        }
      default:
        step = LoginStep.notRegistered;
    }
    notifyListeners();
  }

  // ─── Step 2a: нууц үгээр нэвтрэх ─────────────────────────────────────────

  Future<void> login() async {
    if (passwordCtrl.text.isEmpty) {
      errorText = 'Нууц үгээ оруулна уу.';
      return notifyListeners();
    }
    final res = await _call('auth/login', {
      'identifier': _canonical,
      'password': passwordCtrl.text,
    });
    if (res == null || errorText != null) return notifyListeners();
    if (res.ok) return _handleLoginResponse(res.data);
    passwordCtrl.clear();
    lockedOut = res.status == 423;
    errorText = res.error ?? 'Нэвтрэх нэр эсвэл нууц үг буруу.';
    notifyListeners();
  }

  // ─── Step 2b: анхны нэвтрэлт (OTP + шинэ нууц үг) ──────────────────────

  Future<void> activate() async {
    if (!_validateCodeAndNewPassword()) return;
    final res = await _call('auth/activate', {
      'identifier': _canonical,
      'code': otpCtrl.text.trim(),
      'password': newPasswordCtrl.text,
    });
    if (res == null || errorText != null) return notifyListeners();
    if (res.ok) return _handleLoginResponse(res.data);
    if (res.status == 409) {
      // Already activated elsewhere — sign in with the password instead.
      step = LoginStep.password;
      _clearSecrets();
      _stopCooldown();
    }
    errorText = res.error ?? 'Код буруу байна.';
    notifyListeners();
  }

  Future<void> requestOtp() => _requestCode('auth/activate/request-otp');

  // ─── Нууц үг сэргээх ───────────────────────────────────────────────────────

  /// "Нууц үг мартсан уу?" — sends a reset code to the account's phone and
  /// opens the reset card.
  Future<void> startPasswordReset() async {
    step = LoginStep.resetPassword;
    _clearSecrets();
    maskedPhone = null;
    errorText = null;
    notifyListeners();
    await _requestCode('auth/password/request-otp');
  }

  Future<void> resendResetCode() => _requestCode('auth/password/request-otp');

  Future<void> resetPassword() async {
    if (!_validateCodeAndNewPassword()) return;
    final res = await _call('auth/password/reset', {
      'identifier': _canonical,
      'code': otpCtrl.text.trim(),
      'password': newPasswordCtrl.text,
    });
    if (res == null || errorText != null) return notifyListeners();
    if (!res.ok) {
      errorText = res.error ?? 'Код буруу байна.';
      return notifyListeners();
    }
    // Success: back to the password card, ready to sign in with the new one.
    step = LoginStep.password;
    lockedOut = false;
    _clearSecrets();
    _stopCooldown();
    messageComplete(
      res.data['message'] as String? ??
          'Нууц үг шинэчлэгдлээ. Шинэ нууц үгээрээ нэвтэрнэ үү.',
    );
    notifyListeners();
  }

  void cancelPasswordReset() {
    step = LoginStep.password;
    _clearSecrets();
    errorText = null;
    _stopCooldown();
    notifyListeners();
  }

  // ─── Common ────────────────────────────────────────────────────────────────

  Future<void> _requestCode(String path) async {
    if (resendIn > 0) return;
    final res = await _call(path, {'identifier': _canonical});
    if (res == null || errorText != null) return notifyListeners();
    if (!res.ok) {
      errorText = res.error ?? 'Код илгээхэд алдаа гарлаа.';
      return notifyListeners();
    }
    maskedPhone = res.data['maskedPhone'] as String? ?? maskedPhone;
    _startCooldown();
    notifyListeners();
  }

  bool _validateCodeAndNewPassword() {
    String? error;
    if (!RegExp(r'^\d{6}$').hasMatch(otpCtrl.text.trim())) {
      error = '6 оронтой кодоо оруулна уу.';
    } else if (newPasswordCtrl.text.length < 8) {
      error = 'Нууц үг хамгийн багадаа 8 тэмдэгт байна.';
    } else if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
      error = 'Нууц үг таарахгүй байна.';
    }
    errorText = error;
    notifyListeners();
    return error == null;
  }

  void _handleLoginResponse(Map<String, dynamic> data) {
    final u = data['user'] as Map<String, dynamic>;
    final r = u['role'] as Map<String, dynamic>?;
    final t = u['tenant'] as Map<String, dynamic>;
    final login = SavedLogin(
      identifier: identifierForDisplay,
      email: u['email'] as String?,
      phone: u['phone']?.toString(),
      firstName: u['firstName'] as String?,
      lastName: u['lastName'] as String?,
      tenantName: t['name'] as String?,
      lastLoginAt: DateTime.now(),
    );
    savedLogin = login;
    unawaited(_savedLogins.write(login));
    Authenticator.user = User(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      id: u['id'] as String,
      email: u['email'] as String,
      firstName: u['firstName'] as String,
      lastName: u['lastName'] as String,
      phone: u['phone'].toString(),
      isOwner: u['isOwner'] as bool,
      // Server may return null for unassigned/owner staff — do not force-cast.
      branchId: u['branchId'] as String?,
      role: r != null
          ? UserRole(
              r['id'] as String,
              r['name'] as String,
              List<String>.from(r['permissions'] as List),
            )
          : null,
      tenant: UserTenant(t['id'] as String, t['name'] as String),
    );
    _clearSecrets();
    _stopCooldown();
    lockedOut = false;
    errorText = null;
    authState = AuthState.authorized;
    notifyListeners();
    unawaited(_onSignedIn());
  }
}
