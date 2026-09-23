/// Envelope parsing for the Account feature — P8-F1. Field-level tolerance
/// for session rows lives on the domain model (`account_session.dart`);
/// this file only unwraps top-level response envelopes and, for `/me`,
/// extracts the raw fields the repository merges into the stored [User]
/// (mirrors `MeRepository.refresh()`'s inline parsing).
library;

import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/features/profile/domain/account_repository.dart';
import 'package:carcare_service/features/profile/domain/account_session.dart';

class AccountParseException implements Exception {
  const AccountParseException(this.message);
  final String message;

  @override
  String toString() => 'AccountParseException: $message';
}

typedef JsonMap = Map<String, dynamic>;

JsonMap _map(Object? value, String label) {
  if (value is! Map) throw AccountParseException('$label буруу байна.');
  return Map<String, dynamic>.from(value);
}

int _requiredInt(JsonMap json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw AccountParseException('$key буруу байна.');
}

bool _requiredBool(JsonMap json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw AccountParseException('$key буруу байна.');
}

PaginationMeta _pagination(Object? raw) {
  final json = _map(raw, 'pagination');
  final page = _requiredInt(json, 'page');
  final pageSize = _requiredInt(json, 'pageSize');
  final total = _requiredInt(json, 'total');
  final totalPages = _requiredInt(json, 'totalPages');
  if (page < 1 || pageSize < 1 || total < 0 || totalPages < 0) {
    throw const AccountParseException('Хуудаслалтын мэдээлэл буруу байна.');
  }
  return PaginationMeta(
    page: page,
    pageSize: pageSize,
    total: total,
    totalPages: totalPages,
    hasPrev: _requiredBool(json, 'hasPrev'),
    hasNext: _requiredBool(json, 'hasNext'),
  );
}

/// `PATCH /api/v1/me` — same flat shape as `GET /me`:
/// `{id,email,firstName,lastName,phone,isOwner,role,tenant,branch}`. Every
/// field is optional here — a caller merges each present field over the
/// currently-stored [User] and keeps the rest, exactly like
/// `MeRepository.refresh()`.
class MeProfileDto {
  final String? id;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final bool? isOwner;
  final String? branchId;
  final ({String id, String name, List<String> permissions})? role;
  final ({String id, String name})? tenant;

  const MeProfileDto({
    this.id,
    this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.isOwner,
    this.branchId,
    this.role,
    this.tenant,
  });

  factory MeProfileDto.fromJson(Object? raw) {
    final j = _map(raw, 'профайл хариу');
    final r = j['role'] as Map<String, dynamic>?;
    final t = j['tenant'] as Map<String, dynamic>?;
    final b = j['branch'] as Map<String, dynamic>?;
    return MeProfileDto(
      id: j['id'] as String?,
      email: j['email'] as String?,
      firstName: j['firstName'] as String?,
      lastName: j['lastName'] as String?,
      phone: j['phone']?.toString(),
      isOwner: j['isOwner'] as bool?,
      branchId: b?['id'] as String?,
      role: r != null
          ? (
              id: r['id'] as String,
              name: r['name'] as String,
              permissions: List<String>.from((r['permissions'] as List?) ?? const []),
            )
          : null,
      tenant: t != null ? (id: t['id'] as String, name: t['name'] as String) : null,
    );
  }
}

/// `POST /api/v1/me/password` — `{ok: true}`.
class PasswordChangeResultDto {
  const PasswordChangeResultDto(this.value);
  final PasswordChangeResult value;

  factory PasswordChangeResultDto.fromJson(Object? raw) {
    _map(raw, 'нууц үг солих хариу');
    return const PasswordChangeResultDto(PasswordChangeResult());
  }
}

/// `GET /api/v1/me/sessions` — `{active, ended, otherActiveCount,
/// pagination}`.
class AccountSessionsPageDto {
  const AccountSessionsPageDto(this.value);
  final AccountSessionsPage value;

  factory AccountSessionsPageDto.fromJson(Object? raw) {
    final json = _map(raw, 'session жагсаалтын хариу');
    final active = json['active'];
    final ended = json['ended'];
    if (active is! List || ended is! List) {
      throw const AccountParseException('Session жагсаалт буруу байна.');
    }
    final otherActiveCount = json['otherActiveCount'];
    return AccountSessionsPageDto(
      AccountSessionsPage(
        active: active
            .whereType<Map>()
            .map((row) => AccountSession.fromJson(Map<String, dynamic>.from(row)))
            .toList(growable: false),
        ended: ended
            .whereType<Map>()
            .map((row) => AccountSession.fromJson(Map<String, dynamic>.from(row)))
            .toList(growable: false),
        otherActiveCount: otherActiveCount is int ? otherActiveCount : 0,
        pagination: _pagination(json['pagination']),
      ),
    );
  }
}

/// `DELETE /api/v1/me/sessions/[id]` — `{ok: true}`. `isCurrent` is not on
/// the wire; the repository stitches it in from the caller-supplied flag.
class RevokeSessionAckDto {
  const RevokeSessionAckDto();

  factory RevokeSessionAckDto.fromJson(Object? raw) {
    _map(raw, 'session цуцлах хариу');
    return const RevokeSessionAckDto();
  }
}

/// `POST /api/v1/me/sessions/revoke-others` — `{ok, webRevoked,
/// mobileRevoked}`.
class RevokeOtherSessionsResultDto {
  const RevokeOtherSessionsResultDto(this.value);
  final RevokeOtherSessionsResult value;

  factory RevokeOtherSessionsResultDto.fromJson(Object? raw) {
    final json = _map(raw, 'бусад session цуцлах хариу');
    final web = json['webRevoked'];
    final mobile = json['mobileRevoked'];
    return RevokeOtherSessionsResultDto(
      RevokeOtherSessionsResult(
        webRevoked: web is int ? web : 0,
        mobileRevoked: mobile is int ? mobile : 0,
      ),
    );
  }
}
