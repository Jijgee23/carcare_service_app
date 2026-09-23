/// Account-session domain models — P8-F1.
///
/// Measured against `carcare.mn` after `P8-B1`:
/// * `app/api/v1/me/sessions/route.ts` (`GET /api/v1/me/sessions`),
/// * `app/api/v1/me/sessions/[id]/route.ts`
///   (`DELETE /api/v1/me/sessions/[id]`),
/// * `app/api/v1/me/sessions/revoke-others/route.ts`
///   (`POST /api/v1/me/sessions/revoke-others`),
/// * `lib/account/sessions.ts` (`AccountSessionDto`).
///
/// D-178: one unified list across `UserSession` (web) and `RefreshToken`
/// (mobile, rotation-chain tip only), tagged by [AccountSessionSource].
library;

class AccountSessionParseException implements Exception {
  const AccountSessionParseException(this.message);
  final String message;

  @override
  String toString() => 'AccountSessionParseException: $message';
}

/// `AccountSessionDto.source` — `web`/`mobile`.
enum AccountSessionSource { web, mobile }

AccountSessionSource? _source(Object? value) => switch (value) {
  'web' => AccountSessionSource.web,
  'mobile' => AccountSessionSource.mobile,
  _ => null,
};

/// `AccountSessionDto.status` — `active`/`revoked`/`expired`
/// (`lib/auth/user-session.ts`'s `SessionStatus`). An unrecognised value
/// degrades to [unknown] rather than failing the whole row.
enum AccountSessionStatus { active, revoked, expired, unknown }

AccountSessionStatus _status(Object? value) => switch (value) {
  'active' => AccountSessionStatus.active,
  'revoked' => AccountSessionStatus.revoked,
  'expired' => AccountSessionStatus.expired,
  _ => AccountSessionStatus.unknown,
};

/// One row of `GET /api/v1/me/sessions` — a `UserSession` (web) or
/// `RefreshToken` (mobile) entry. Never carries `tokenHash` or any secret;
/// the server contract guarantees that, this model has no field for it.
///
/// Only `id` and `source` are structurally required — a row that fails to
/// parse either throws (see `account_dto.dart`); everything else degrades.
class AccountSession {
  final String id;
  final AccountSessionSource source;
  final String deviceLabel;
  final String? ip;
  final DateTime? createdAt;
  final DateTime? lastActivityAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final AccountSessionStatus status;

  /// `true` for exactly the row identifying the caller's own device: its
  /// web session (via cookie `sid`, never applicable to a bearer-only
  /// mobile caller) or its own mobile token (via `auth.user.refreshTokenId`,
  /// D-180 — absent for a pre-D-180 token, so no row is marked current in
  /// that case).
  final bool current;

  const AccountSession({
    required this.id,
    required this.source,
    this.deviceLabel = '',
    this.ip,
    this.createdAt,
    this.lastActivityAt,
    this.expiresAt,
    this.revokedAt,
    this.status = AccountSessionStatus.unknown,
    this.current = false,
  });

  factory AccountSession.fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final source = _source(j['source']);
    if (id is! String || id.trim().isEmpty) {
      throw const AccountSessionParseException('id талбар буруу байна.');
    }
    if (source == null) {
      throw const AccountSessionParseException('source талбар буруу байна.');
    }
    return AccountSession(
      id: id.trim(),
      source: source,
      deviceLabel: _optString(j['deviceLabel']) ?? '',
      ip: _optString(j['ip']),
      createdAt: _optDate(j['createdAt']),
      lastActivityAt: _optDate(j['lastActivityAt']),
      expiresAt: _optDate(j['expiresAt']),
      revokedAt: _optDate(j['revokedAt']),
      status: _status(j['status']),
      current: j['current'] == true,
    );
  }
}

String? _optString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _optDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toLocal();
}
