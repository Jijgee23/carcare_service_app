import 'package:carcare_service/app/api/api_client.dart';
import 'package:carcare_service/app/app.dart';
import 'package:carcare_service/app/widgets/message.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum AuthState { firstInstall, policyNotAgreed, noLogged, authorized, finding }

class AuthProvider extends ChangeNotifier {
  bool loading = false;
  void setload(bool val) {
    loading = val;
    notifyListeners();
  }

  AuthState authState = AuthState.finding;
  void setAuthState(AuthState val) {
    authState = val;
    notifyListeners();
  }

  Future<void> loadUser() async {
    Authenticator.onUnauthorized = logout;
    final user = Authenticator.user;
    if (user != null) {
      setAuthState(AuthState.authorized);
      return;
    }
    setAuthState(AuthState.noLogged);
  }

  TextEditingController emailControler = TextEditingController(text: "act@a.mn");
  String get email => emailControler.text;
  TextEditingController passwordControler = TextEditingController(text: "pasS0011");
  String get password => passwordControler.text;

  Future<void> logout() async {
    await Authenticator.clear();
    setAuthState(AuthState.noLogged);
  }

  Future<void> login() async {
    setload(true);
    try {
      final res = await api(Api.post, 'auth/login', body: {"email": email, "password": password});
      if (res != null && res.data != null) {
        final data = res.data as Map<String, dynamic>;
        final u = data['user'] as Map<String, dynamic>;
        final r = u['role'] as Map<String, dynamic>;
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
          branchId: u['branchId'] as String,
          role: UserRole(
            r['id'] as String,
            r['name'] as String,
            List<String>.from(r['permissions'] as List),
          ),
          tenant: UserTenant(t['id'] as String, t['name'] as String),
        );
        messageComplete('Амжилттай нэвтэрлээ');
        setAuthState(AuthState.authorized);
      }
    } catch (e) {
      messageError('Нэвтрэх үед алдаа гарлаа');
      throw Exception(e);
    } finally {
      setload(false);
    }
  }
}

class Authenticator {
  static const _box = 'auth';
  static const _key = 'user';

  static Future<void> init() async {
    Hive.registerAdapter(UserAdapter());
    try {
      await Hive.openBox<User>(_box);
    } catch (_) {
      await Hive.deleteBoxFromDisk(_box);
      await Hive.openBox<User>(_box);
    }
  }

  static User? get user => Hive.box<User>(_box).get(_key);

  static set user(User? u) {
    final box = Hive.box<User>(_box);
    if (u == null) {
      box.delete(_key);
    } else {
      box.put(_key, u);
    }
  }

  static Future<void> clear() async {
    await Hive.box<User>(_box).delete(_key);
  }

  static void Function()? onUnauthorized;
}
