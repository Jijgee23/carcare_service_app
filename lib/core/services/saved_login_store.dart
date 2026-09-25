import 'package:hive_flutter/hive_flutter.dart';

/// Who last signed in on this device — kept after logout so the login page
/// can prefill the identifier. Deliberately separate from [Authenticator]:
/// that box holds the live session (tokens) and is wiped on logout; this one
/// holds no secrets at all (never the password or a token) and survives.
class SavedLogin {
  const SavedLogin({
    required this.identifier,
    this.email,
    this.phone,
    this.firstName,
    this.lastName,
    this.tenantName,
    required this.lastLoginAt,
  });

  /// What the user typed to sign in (email or phone), shown back as-is.
  final String identifier;
  final String? email;
  final String? phone;
  final String? firstName;
  final String? lastName;
  final String? tenantName;
  final DateTime lastLoginAt;

  String get displayName =>
      [lastName, firstName].where((s) => s != null && s.isNotEmpty).join(' ');

  Map<String, dynamic> toMap() => {
    'identifier': identifier,
    'email': email,
    'phone': phone,
    'firstName': firstName,
    'lastName': lastName,
    'tenantName': tenantName,
    'lastLoginAt': lastLoginAt.toIso8601String(),
  };

  /// Null for anything unreadable, so a corrupt entry just means "no prefill".
  static SavedLogin? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final identifier = raw['identifier'];
    if (identifier is! String || identifier.trim().isEmpty) return null;
    String? str(String k) => raw[k] is String ? raw[k] as String : null;
    return SavedLogin(
      identifier: identifier.trim(),
      email: str('email'),
      phone: str('phone'),
      firstName: str('firstName'),
      lastName: str('lastName'),
      tenantName: str('tenantName'),
      lastLoginAt:
          DateTime.tryParse(str('lastLoginAt') ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

abstract class SavedLoginStore {
  Future<SavedLogin?> read();
  Future<void> write(SavedLogin login);
  Future<void> clear();
}

/// Hive-backed [SavedLoginStore] in its own `saved_login` box. Best-effort
/// like the working-branch store: a storage failure never blocks sign-in or
/// sign-out, it only costs the prefill.
class HiveSavedLoginStore implements SavedLoginStore {
  HiveSavedLoginStore._();
  static final instance = HiveSavedLoginStore._();

  static const boxName = 'saved_login';
  static const _key = 'last';

  /// Pre-`saved_login` versions kept only the identifier in the `device` box.
  static const _legacyBox = 'device';
  static const _legacyKeys = ['last_login_identifier', 'last_email'];

  static Future<void> init() async {
    try {
      await Hive.openBox<dynamic>(boxName);
    } catch (_) {
      await Hive.deleteBoxFromDisk(boxName);
      await Hive.openBox<dynamic>(boxName);
    }
  }

  @override
  Future<SavedLogin?> read() async {
    try {
      final saved = SavedLogin.fromMap(Hive.box<dynamic>(boxName).get(_key));
      if (saved != null) return saved;
      // One-time fallback for users upgrading from the identifier-only key.
      if (Hive.isBoxOpen(_legacyBox)) {
        final legacy = Hive.box<dynamic>(_legacyBox);
        for (final k in _legacyKeys) {
          final v = legacy.get(k);
          if (v is String && v.trim().isNotEmpty) {
            return SavedLogin(
              identifier: v.trim(),
              lastLoginAt: DateTime.fromMillisecondsSinceEpoch(0),
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> write(SavedLogin login) async {
    try {
      await Hive.box<dynamic>(boxName).put(_key, login.toMap());
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      await Hive.box<dynamic>(boxName).delete(_key);
    } catch (_) {}
  }
}

/// In-memory store for tests and previews.
class MemorySavedLoginStore implements SavedLoginStore {
  MemorySavedLoginStore([this._value]);
  SavedLogin? _value;

  @override
  Future<SavedLogin?> read() async => _value;

  @override
  Future<void> write(SavedLogin login) async => _value = login;

  @override
  Future<void> clear() async => _value = null;
}
