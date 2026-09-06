import 'package:carcare_service/core/api/api_client.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/services/device_service.dart';
import 'package:carcare_service/core/services/subscription_service.dart';
import 'package:carcare_service/features/models/user.dart';
import 'package:carcare_service/shared/widgets/dialogs/message.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum AuthState { firstInstall, policyNotAgreed, noLogged, authorized, finding }

enum LoginStep { email, password, activate, notRegistered }

class AuthController extends ChangeNotifier {
  bool loading = false;
  AuthState authState = AuthState.finding;
  LoginStep step = LoginStep.email;

  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  final newPasswordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  String? maskedPhone;

  @override
  void dispose() {
    emailCtrl.dispose();
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

  void resetToEmail() {
    step = LoginStep.email;
    passwordCtrl.clear();
    otpCtrl.clear();
    newPasswordCtrl.clear();
    confirmPasswordCtrl.clear();
    maskedPhone = null;
    notifyListeners();
  }

  // ─── App start ─────────────────────────────────────────────────────────────

  Future<void> loadUser() async {
    Authenticator.onUnauthorized = logout;
    final user = Authenticator.user;
    if (user != null) {
      setAuthState(AuthState.authorized);
      return;
    }
    final saved = Hive.box('device').get('last_email') as String?;
    if (saved != null && saved.isNotEmpty) emailCtrl.text = saved;
    setAuthState(AuthState.noLogged);
  }

  Future<void> logout() async {
    // Revoke the refresh token server-side before clearing local state.
    // Best-effort: a failure here must never block local sign-out. When the
    // session was already cleared (forced 401 logout) there is no token to send.
    final refreshToken = Authenticator.user?.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await api(Api.post, 'auth/logout', body: {'refreshToken': refreshToken});
      } catch (_) {}
    }
    await DeviceService.instance.unregister();
    SubscriptionService.instance.invalidate();
    await Authenticator.clear();
    step = LoginStep.email;
    emailCtrl.clear();
    passwordCtrl.clear();
    setAuthState(AuthState.noLogged);
  }

  // ─── Step 1: имэйл шалгах ─────────────────────────────────────────────────

  Future<void> checkEmail() async {
    final email = emailCtrl.text.trim();
    if (email.isEmpty) return;
    _setLoading(true);
    try {
      final res = await api(Api.post, 'auth/check-email', body: {'email': email});
      if (res?.data == null) return;
      final data = res!.data as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      switch (status) {
        case 'password':
          step = LoginStep.password;
        case 'activate':
          step = LoginStep.activate;
          maskedPhone = data['maskedPhone'] as String?;
        default:
          step = LoginStep.notRegistered;
      }
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // ─── Step 2a: нууц үгээр нэвтрэх ─────────────────────────────────────────

  Future<void> login() async {
    _setLoading(true);
    try {
      final res = await api(Api.post, 'auth/login', body: {
        'email': emailCtrl.text.trim(),
        'password': passwordCtrl.text,
      });
      if (res?.data != null) _handleLoginResponse(res!.data as Map<String, dynamic>);
    } finally {
      _setLoading(false);
    }
  }

  // ─── Step 2b: анхны нэвтрэлт (OTP + шинэ нууц үг) ──────────────────────

  Future<void> activate() async {
    if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
      messageError('Нууц үг таарахгүй байна');
      return;
    }
    if (newPasswordCtrl.text.length < 8) {
      messageError('Нууц үг хамгийн багадаа 8 тэмдэгт байна');
      return;
    }
    _setLoading(true);
    try {
      final res = await api(Api.post, 'auth/activate', body: {
        'email': emailCtrl.text.trim(),
        'code': otpCtrl.text.trim(),
        'password': newPasswordCtrl.text,
      });
      if (res?.data != null) _handleLoginResponse(res!.data as Map<String, dynamic>);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> requestOtp() async {
    _setLoading(true);
    try {
      await api(Api.post, 'auth/activate/request-otp', body: {'email': emailCtrl.text.trim()});
      messageComplete('OTP дахин илгээлээ');
    } finally {
      _setLoading(false);
    }
  }

  // ─── Common ────────────────────────────────────────────────────────────────

  void _handleLoginResponse(Map<String, dynamic> data) {
    Hive.box('device').put('last_email', emailCtrl.text.trim());
    final u = data['user'] as Map<String, dynamic>;
    final r = u['role'] as Map<String, dynamic>?;
    final t = u['tenant'] as Map<String, dynamic>;
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
          ? UserRole(r['id'] as String, r['name'] as String,
              List<String>.from(r['permissions'] as List))
          : null,
      tenant: UserTenant(t['id'] as String, t['name'] as String),
    );
    messageComplete('Амжилттай нэвтэрлээ');
    authState = AuthState.authorized;
    notifyListeners();
    DeviceService.instance.registerAfterLogin();
  }
}
