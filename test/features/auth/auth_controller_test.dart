import 'package:carcare_service/features/auth/presentation/controllers/auth_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scripted server: each path answers with the next queued reply, and every
/// request is recorded so tests can assert exactly what the app sent.
class _FakeServer {
  final _replies = <String, List<AuthResponse>>{};
  final calls = <(String, Map<String, dynamic>)>[];

  void on(String path, int status, Map<String, dynamic> data) =>
      (_replies[path] ??= []).add(AuthResponse(status, data));

  Future<AuthResponse> call(String path, Map<String, dynamic> body) async {
    calls.add((path, body));
    final queue = _replies[path];
    if (queue == null || queue.isEmpty) {
      throw StateError('No scripted reply for $path');
    }
    return queue.removeAt(0);
  }

  Map<String, dynamic> lastBody(String path) => calls.lastWhere((c) => c.$1 == path).$2;
}

void main() {
  late _FakeServer server;
  late AuthController auth;

  setUp(() {
    server = _FakeServer();
    auth = AuthController(transport: server.call);
  });

  tearDown(() => auth.dispose());

  Future<void> toPasswordStep({String typed = '9911-2233'}) async {
    server.on('auth/check-email', 200, {'status': 'password', 'identifier': '99112233'});
    auth.identifierCtrl.text = typed;
    await auth.checkIdentifier();
  }

  group('identifier step', () {
    test('sends identifier (not email) and keeps the canonical value', () async {
      await toPasswordStep();
      expect(server.lastBody('auth/check-email'), {'identifier': '9911-2233'});
      expect(auth.step, LoginStep.password);
      expect(auth.isPhoneIdentifier, isTrue);

      server.on('auth/login', 401, {'error': 'Нэвтрэх нэр эсвэл нууц үг буруу.'});
      auth.passwordCtrl.text = 'wrong-pass';
      await auth.login();
      // Canonical 8-digit phone from check-email, not the typed "9911-2233".
      expect(server.lastBody('auth/login')['identifier'], '99112233');
    });

    test('empty input never hits the server', () async {
      await auth.checkIdentifier();
      expect(server.calls, isEmpty);
      expect(auth.errorText, isNotNull);
    });

    test('email routes to activate and remembers the masked phone', () async {
      server.on('auth/check-email', 200, {
        'status': 'activate',
        'identifier': 'a@b.mn',
        'maskedPhone': '99***33',
        'otpSent': true,
      });
      auth.identifierCtrl.text = 'A@B.mn';
      await auth.checkIdentifier();
      expect(auth.step, LoginStep.activate);
      expect(auth.maskedPhone, '99***33');
      expect(auth.resendIn, AuthController.resendCooldownSeconds);
      expect(auth.isPhoneIdentifier, isFalse);
    });

    test('activate with otpSent=false stays resendable and explains why', () async {
      server.on('auth/check-email', 200, {
        'status': 'activate',
        'identifier': 'a@b.mn',
        'maskedPhone': '99***33',
        'otpSent': false,
        'message': 'Хэт олон код хүслээ.',
      });
      auth.identifierCtrl.text = 'a@b.mn';
      await auth.checkIdentifier();
      expect(auth.step, LoginStep.activate);
      expect(auth.errorText, 'Хэт олон код хүслээ.');
      expect(auth.resendIn, 0);
    });

    test('not_registered and 400 are handled', () async {
      server.on('auth/check-email', 200, {'status': 'not_registered', 'identifier': 'x@y.mn'});
      auth.identifierCtrl.text = 'x@y.mn';
      await auth.checkIdentifier();
      expect(auth.step, LoginStep.notRegistered);

      auth.resetToIdentifier();
      server.on('auth/check-email', 400, {'error': 'Имэйл эсвэл утасны дугаар буруу.'});
      auth.identifierCtrl.text = 'abc';
      await auth.checkIdentifier();
      expect(auth.step, LoginStep.identifier);
      expect(auth.errorText, 'Имэйл эсвэл утасны дугаар буруу.');
    });

    test('network failure becomes a friendly error, not a crash', () async {
      final failing = AuthController(
        transport: (_, _) async => throw DioException(
          requestOptions: RequestOptions(path: 'auth/check-email'),
          type: DioExceptionType.connectionError,
        ),
      );
      addTearDown(failing.dispose);
      failing.identifierCtrl.text = 'a@b.mn';
      await failing.checkIdentifier();
      expect(failing.loading, isFalse);
      expect(failing.errorText, contains('Интернэт'));
    });
  });

  group('password step', () {
    test('wrong password stays on the step with the server message', () async {
      await toPasswordStep();
      server.on('auth/login', 401, {'error': 'Нэвтрэх нэр эсвэл нууц үг буруу.'});
      auth.passwordCtrl.text = 'wrong-pass';
      await auth.login();
      expect(auth.step, LoginStep.password);
      expect(auth.errorText, 'Нэвтрэх нэр эсвэл нууц үг буруу.');
      expect(auth.identifierCtrl.text, '9911-2233'); // not wiped
      expect(auth.passwordCtrl.text, isEmpty);
      expect(auth.lockedOut, isFalse);
    });

    test('423 marks the account locked so a reset is offered', () async {
      await toPasswordStep();
      server.on('auth/login', 423, {'error': 'Аккаунт түгжигдсэн.'});
      auth.passwordCtrl.text = 'wrong-pass';
      await auth.login();
      expect(auth.lockedOut, isTrue);
      expect(auth.errorText, 'Аккаунт түгжигдсэн.');
    });

    test('empty password is rejected locally', () async {
      await toPasswordStep();
      await auth.login();
      expect(server.calls.where((c) => c.$1 == 'auth/login'), isEmpty);
      expect(auth.errorText, isNotNull);
    });
  });

  group('forgot password', () {
    Future<void> openReset() async {
      await toPasswordStep();
      server.on('auth/password/request-otp', 200, {'sent': true, 'maskedPhone': '99***33'});
      await auth.startPasswordReset();
    }

    void fill({String code = '123456', String pw = 'newpass12', String? confirm}) {
      auth.otpCtrl.text = code;
      auth.newPasswordCtrl.text = pw;
      auth.confirmPasswordCtrl.text = confirm ?? pw;
    }

    test('requests a code for the canonical identifier and starts cooldown', () async {
      await openReset();
      expect(auth.step, LoginStep.resetPassword);
      expect(server.lastBody('auth/password/request-otp'), {'identifier': '99112233'});
      expect(auth.maskedPhone, '99***33');
      expect(auth.resendIn, AuthController.resendCooldownSeconds);

      // Resend is blocked during the cooldown — no second request.
      await auth.resendResetCode();
      expect(server.calls.where((c) => c.$1 == 'auth/password/request-otp').length, 1);
    });

    test('validates code, length and match before calling the server', () async {
      await openReset();
      fill(code: '12');
      await auth.resetPassword();
      expect(auth.errorText, contains('6 оронтой'));
      fill(pw: 'short');
      await auth.resetPassword();
      expect(auth.errorText, contains('8 тэмдэгт'));
      fill(pw: 'newpass12', confirm: 'newpass13');
      await auth.resetPassword();
      expect(auth.errorText, contains('таарахгүй'));
      expect(server.calls.where((c) => c.$1 == 'auth/password/reset'), isEmpty);
    });

    test('wrong code keeps the reset card with the server message', () async {
      await openReset();
      server.on('auth/password/reset', 401, {'error': 'Код буруу байна.'});
      fill();
      await auth.resetPassword();
      expect(auth.step, LoginStep.resetPassword);
      expect(auth.errorText, 'Код буруу байна.');
    });

    test('success returns to the password step, unlocked and cleared', () async {
      await toPasswordStep();
      server.on('auth/login', 423, {'error': 'Аккаунт түгжигдсэн.'});
      auth.passwordCtrl.text = 'wrong-pass';
      await auth.login();
      expect(auth.lockedOut, isTrue);

      server.on('auth/password/request-otp', 200, {'sent': true, 'maskedPhone': '99***33'});
      await auth.startPasswordReset();
      server.on('auth/password/reset', 200, {'ok': true, 'message': 'OK'});
      fill();
      await auth.resetPassword();

      expect(server.lastBody('auth/password/reset'), {
        'identifier': '99112233',
        'code': '123456',
        'password': 'newpass12',
      });
      expect(auth.step, LoginStep.password);
      expect(auth.lockedOut, isFalse);
      expect(auth.errorText, isNull);
      expect(auth.otpCtrl.text, isEmpty);
      expect(auth.newPasswordCtrl.text, isEmpty);
      expect(auth.resendIn, 0);
    });

    test('throttled code request shows the reason', () async {
      await toPasswordStep();
      server.on('auth/password/request-otp', 429, {
        'error': 'Хэт олон код хүслээ. 10 минутын дараа дахин оролдоно уу.',
      });
      await auth.startPasswordReset();
      expect(auth.step, LoginStep.resetPassword);
      expect(auth.errorText, contains('Хэт олон код'));
      expect(auth.resendIn, 0);
    });

    test('cancel goes back to the password step', () async {
      await openReset();
      auth.cancelPasswordReset();
      expect(auth.step, LoginStep.password);
      expect(auth.resendIn, 0);
    });
  });

  test('activate 409 (already active) moves to the password step', () async {
    server.on('auth/check-email', 200, {
      'status': 'activate',
      'identifier': 'a@b.mn',
      'otpSent': true,
    });
    auth.identifierCtrl.text = 'a@b.mn';
    await auth.checkIdentifier();
    server.on('auth/activate', 409, {'error': 'Аккаунт аль хэдийн идэвхжсэн байна.'});
    auth.otpCtrl.text = '123456';
    auth.newPasswordCtrl.text = 'newpass12';
    auth.confirmPasswordCtrl.text = 'newpass12';
    await auth.activate();
    expect(auth.step, LoginStep.password);
    expect(auth.errorText, contains('идэвхжсэн'));
  });
}
