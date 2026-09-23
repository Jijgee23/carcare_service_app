import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/profile/domain/account_repository.dart';
import 'package:carcare_service/features/profile/domain/account_session.dart';

/// Hand-written fake for [AccountRepository] — P8-F1, for later screen
/// tests (`P8-F2`/`P8-F3`). Holds its own in-memory [User] rather than
/// touching `Authenticator`/Hive, matching `FakeMeRepository`'s approach
/// (see `test/fakes/fake_me_repository.dart`) — a fake constructed by a
/// widget test must not require `Hive.init`.
class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({User? user, List<AccountSession>? sessions})
    : user = user ?? _defaultUser(),
      _sessions = [...(sessions ?? _defaultSessions())];

  User user;
  final List<AccountSession> _sessions;

  /// Set to force the next matching call to fail, e.g.
  /// `failNext = AppError(ErrorKind.unknown, '...', statusCode: 429, code: 'RATE_LIMITED')`.
  AppError? failNext;

  static User _defaultUser() => User(
    accessToken: 'access-1',
    refreshToken: 'refresh-1',
    id: 'u-1',
    email: 'staff@example.mn',
    firstName: 'Бат',
    lastName: 'Болд',
    phone: '99001122',
    isOwner: false,
    tenant: UserTenant('t-1', 'Карком'),
  );

  static List<AccountSession> _defaultSessions() => [
    AccountSession(
      id: 's-1',
      source: AccountSessionSource.mobile,
      deviceLabel: 'Энэ төхөөрөмж',
      status: AccountSessionStatus.active,
      current: true,
      createdAt: DateTime(2026, 9, 1),
      lastActivityAt: DateTime(2026, 9, 20),
    ),
  ];

  @override
  Future<Result<User>> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) async {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      return Err(failure);
    }
    if (firstName.trim().isEmpty || lastName.trim().isEmpty) {
      return const Err(
        AppError(
          ErrorKind.unknown,
          'Талбарын алдаа.',
          statusCode: 422,
          code: 'VALIDATION',
          fieldErrors: {'firstName': 'Нэрээ оруулна уу.'},
        ),
      );
    }
    user = User(
      accessToken: user.accessToken,
      refreshToken: user.refreshToken,
      id: user.id,
      email: email,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      isOwner: user.isOwner,
      branchId: user.branchId,
      role: user.role,
      tenant: user.tenant,
    );
    return Ok(user);
  }

  @override
  Future<Result<PasswordChangeResult>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      return Err(failure);
    }
    if (currentPassword != 'correct-password') {
      return const Err(
        AppError(
          ErrorKind.unknown,
          'Талбарын алдаа.',
          statusCode: 422,
          code: 'VALIDATION',
          fieldErrors: {'currentPassword': 'Одоогийн нууц үг буруу.'},
        ),
      );
    }
    if (newPassword.length < 8 || newPassword != confirmPassword) {
      return const Err(
        AppError(
          ErrorKind.unknown,
          'Талбарын алдаа.',
          statusCode: 422,
          code: 'VALIDATION',
          fieldErrors: {'newPassword': 'Шинэ нууц үг 8+ тэмдэгт байна.'},
        ),
      );
    }
    return const Ok(PasswordChangeResult());
  }

  @override
  Future<Result<AccountSessionsPage>> getSessions({
    int page = 1,
    int pageSize = 20,
  }) async {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      return Err(failure);
    }
    final active = _sessions
        .where((s) => s.status == AccountSessionStatus.active)
        .toList(growable: false);
    final ended = _sessions
        .where((s) => s.status != AccountSessionStatus.active)
        .toList(growable: false);
    return Ok(
      AccountSessionsPage(
        active: active,
        ended: ended,
        otherActiveCount: active.where((s) => !s.current).length,
        pagination: PaginationMeta(
          page: page,
          pageSize: pageSize,
          total: ended.length,
          totalPages: (ended.length / pageSize).ceil().clamp(1, 1 << 30),
          hasPrev: page > 1,
          hasNext: false,
        ),
      ),
    );
  }

  @override
  Future<Result<RevokeSessionResult>> revokeSession(
    String id, {
    required AccountSessionSource source,
    bool isCurrent = false,
  }) async {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      return Err(failure);
    }
    final index = _sessions.indexWhere((s) => s.id == id && s.source == source);
    if (index < 0) {
      return const Err(
        AppError(ErrorKind.notFound, 'Олдсонгүй', statusCode: 404, code: 'NOT_FOUND'),
      );
    }
    final current = _sessions[index];
    _sessions[index] = AccountSession(
      id: current.id,
      source: current.source,
      deviceLabel: current.deviceLabel,
      ip: current.ip,
      createdAt: current.createdAt,
      lastActivityAt: current.lastActivityAt,
      expiresAt: current.expiresAt,
      revokedAt: DateTime.now(),
      status: AccountSessionStatus.revoked,
      current: current.current,
    );
    return Ok(RevokeSessionResult(loggedOut: isCurrent));
  }

  @override
  Future<Result<RevokeOtherSessionsResult>> revokeOtherSessions() async {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      return Err(failure);
    }
    var web = 0;
    var mobile = 0;
    for (var i = 0; i < _sessions.length; i++) {
      final s = _sessions[i];
      if (s.current || s.status != AccountSessionStatus.active) continue;
      if (s.source == AccountSessionSource.web) {
        web++;
      } else {
        mobile++;
      }
      _sessions[i] = AccountSession(
        id: s.id,
        source: s.source,
        deviceLabel: s.deviceLabel,
        ip: s.ip,
        createdAt: s.createdAt,
        lastActivityAt: s.lastActivityAt,
        expiresAt: s.expiresAt,
        revokedAt: DateTime.now(),
        status: AccountSessionStatus.revoked,
        current: s.current,
      );
    }
    return Ok(RevokeOtherSessionsResult(webRevoked: web, mobileRevoked: mobile));
  }
}
