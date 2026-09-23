import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/profile/domain/account_session.dart';

/// `GET /api/v1/me/sessions` — the active/ended rows together, plus the
/// `otherActiveCount` badge and pagination for the `ended` (history) list
/// only, matching `lib/account/sessions.ts`'s `listAccountSessions`
/// contract: `active` is never paginated.
class AccountSessionsPage {
  final List<AccountSession> active;
  final List<AccountSession> ended;
  final int otherActiveCount;
  final PaginationMeta pagination;

  const AccountSessionsPage({
    required this.active,
    required this.ended,
    required this.otherActiveCount,
    required this.pagination,
  });
}

/// `DELETE /api/v1/me/sessions/[id]` — always `{ok: true}` on success
/// (idempotent: a row already ended still returns 200). [loggedOut] is not
/// carried by the server response — the route never reports whether the
/// revoked row was the caller's own device — so the caller passes the
/// `current` flag it already holds from the row it fetched via
/// [AccountRepository.getSessions] as `isCurrent`, and this result echoes it
/// back so the presentation layer has one place to check before logging the
/// device out locally.
class RevokeSessionResult {
  final bool loggedOut;
  const RevokeSessionResult({required this.loggedOut});
}

/// `POST /api/v1/me/sessions/revoke-others` — `{ok, webRevoked,
/// mobileRevoked}`. Never revokes the caller's own device (D-180
/// identification), so this never implies a logout.
class RevokeOtherSessionsResult {
  final int webRevoked;
  final int mobileRevoked;
  const RevokeOtherSessionsResult({
    required this.webRevoked,
    required this.mobileRevoked,
  });
}

/// `POST /api/v1/me/password` — `{ok: true}`.
///
/// D-179: on success the server revokes every other web session and mobile
/// refresh token, but keeps *this* device's token alive (identified via the
/// access JWT's `rtid` claim, D-180). The access JWT already issued stays
/// valid until it expires (at most 24h) regardless. So a successful
/// [AccountRepository.changePassword] call requires **no forced logout or
/// re-authentication on this device** — the caller may keep using the
/// current session normally. This result type exists only so a bare
/// `Result<void>` isn't needed; it carries no extra data.
class PasswordChangeResult {
  const PasswordChangeResult();
}

/// One frozen repository contract for the Account feature — P8-F1 (profile
/// update, password change, session list/revoke). Extends the existing
/// `profile` feature rather than replacing `MeRepository`, which callers
/// still use for the read-only `GET /api/v1/me` refresh.
///
/// Errors a caller must expect, surfaced as `Err(AppError)` with
/// `statusCode`/`code`/`fieldErrors` preserved by the shared
/// `mapDioException`:
/// * `401` — no code, auth required only.
/// * `404 NOT_FOUND` — [revokeSession] only, a foreign or never-existed id.
/// * `422 VALIDATION` — carries `fieldErrors` on [updateProfile] and
///   [changePassword]; [getSessions] can also 422 on an unknown/invalid
///   query param, without `fieldErrors` guaranteed per field.
/// * `429 RATE_LIMITED` — [changePassword] only (D-181): 5 failed
///   current-password attempts per 15 minutes. Distinguished from
///   `ErrorKind.unknown` 422s by `statusCode`/`code`, never collapsed into
///   the same case a caller would handle identically to a validation error.
abstract interface class AccountRepository {
  /// `PATCH /api/v1/me` — whole-record replace, all four fields required
  /// (matches `EmployeesRepository.updateEmployee`'s convention). On
  /// success, merges the returned `/me` payload into the stored Hive
  /// [User] exactly like `MeRepository.refresh()` does — preserving
  /// `accessToken`/`refreshToken`, which `/me` never returns — and persists
  /// it via `Authenticator.user =`. Returns the updated [User].
  Future<Result<User>> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  });

  /// `POST /api/v1/me/password`. Requires the current password on every
  /// call — this method has no way to bypass that, matching the route.
  /// See [PasswordChangeResult] for why a caller never needs to log out or
  /// re-authenticate this device on success.
  Future<Result<PasswordChangeResult>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  });

  /// `GET /api/v1/me/sessions?page&pageSize` — paginates only the `ended`
  /// history list; `active` always comes back in full.
  Future<Result<AccountSessionsPage>> getSessions({
    int page = 1,
    int pageSize = 20,
  });

  /// `DELETE /api/v1/me/sessions/{id}?source=web|mobile`. [source] is
  /// required by the route — there is no default, since either table could
  /// hold that id. [isCurrent] is not sent to the server; it is echoed back
  /// on [RevokeSessionResult.loggedOut] so the caller knows to log out
  /// locally after revoking its own device. A foreign or never-existed id
  /// is `404 NOT_FOUND`; a row that already ended still succeeds
  /// (idempotent).
  Future<Result<RevokeSessionResult>> revokeSession(
    String id, {
    required AccountSessionSource source,
    bool isCurrent = false,
  });

  /// `POST /api/v1/me/sessions/revoke-others`. No body. Never revokes the
  /// caller's own device.
  Future<Result<RevokeOtherSessionsResult>> revokeOtherSessions();
}
