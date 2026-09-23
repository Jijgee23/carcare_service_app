/// Audit domain model — P7-F1.
///
/// Measured against `carcare.mn` after `P7-B1`:
/// * `app/api/v1/audit/route.ts` (`GET /api/v1/audit`),
/// * `lib/audit-query.ts` (`buildAuditWhere`, `AUDIT_PAGE_SIZE` = 50),
/// * `lib/audit.ts` (`ACTION_TYPES`, `ENTITY_TYPES`),
/// * `lib/audit-redact.ts` (`redactAuditJson` — applied server-side; this
///   client never re-derives redaction, it only ever sees the already-safe
///   payload).
///
/// `before`/`after` are nullable, arbitrary JSON maps (redacted server-side)
/// — modeled as `Map<String, dynamic>?`, never a typed shape, since the
/// audited entity varies per row.
library;

import 'package:carcare_service/core/domain/pagination.dart';

class AuditParseException implements Exception {
  const AuditParseException(this.message);
  final String message;

  @override
  String toString() => 'AuditParseException: $message';
}

/// `items[].user` — `null` when the actor row no longer exists or the log
/// was system-generated.
class AuditActor {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? email;

  const AuditActor({required this.id, this.firstName, this.lastName, this.email});

  factory AuditActor.fromJson(Map<String, dynamic> j) => AuditActor(
    id: _reqString(j, 'id'),
    firstName: _optString(j['firstName']),
    lastName: _optString(j['lastName']),
    email: _optString(j['email']),
  );

  String get displayName {
    final hasFirst = firstName != null && firstName!.isNotEmpty;
    final hasLast = lastName != null && lastName!.isNotEmpty;
    if (hasLast && hasFirst) return '$lastName $firstName';
    if (hasFirst) return firstName!;
    if (hasLast) return lastName!;
    return email ?? 'Тодорхойгүй';
  }
}

/// `meta.users[]` — `{id, firstName, lastName}` only, for the actor filter
/// picker. Distinct from [AuditActor] (no `email`).
class AuditUserOption {
  final String id;
  final String? firstName;
  final String? lastName;

  const AuditUserOption({required this.id, this.firstName, this.lastName});

  factory AuditUserOption.fromJson(Map<String, dynamic> j) => AuditUserOption(
    id: _reqString(j, 'id'),
    firstName: _optString(j['firstName']),
    lastName: _optString(j['lastName']),
  );
}

/// One `AuditLog` row.
class AuditLogEntry {
  final String id;
  final String? entity;
  final String? entityId;
  final String? action;
  final String? summary;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final DateTime? createdAt;
  final AuditActor? user;
  final String? branchId;

  const AuditLogEntry({
    required this.id,
    this.entity,
    this.entityId,
    this.action,
    this.summary,
    this.before,
    this.after,
    this.createdAt,
    this.user,
    this.branchId,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> j) => AuditLogEntry(
    id: _reqString(j, 'id'),
    entity: _optString(j['entity']),
    entityId: _optString(j['entityId']),
    action: _optString(j['action']),
    summary: _optString(j['summary']),
    before: _optJsonMap(j['before']),
    after: _optJsonMap(j['after']),
    createdAt: _optDate(j['createdAt']),
    user: j['user'] is Map
        ? AuditActor.fromJson(Map<String, dynamic>.from(j['user'] as Map))
        : null,
    branchId: _optString(j['branchId']),
  );
}

/// `meta` block — vocab lists for filter chips, plus the tenant's users for
/// the actor filter. Missing/malformed degrades to an empty list — the
/// filter row just renders nothing extra rather than throwing.
class AuditListMeta {
  final List<String> actions;
  final List<String> entities;
  final List<AuditUserOption> users;

  const AuditListMeta({
    this.actions = const [],
    this.entities = const [],
    this.users = const [],
  });

  factory AuditListMeta.fromJson(Object? raw) {
    if (raw is! Map) return const AuditListMeta();
    final j = Map<String, dynamic>.from(raw);
    final actions = j['actions'];
    final entities = j['entities'];
    final users = j['users'];
    return AuditListMeta(
      actions: actions is List
          ? actions.whereType<String>().toList(growable: false)
          : const [],
      entities: entities is List
          ? entities.whereType<String>().toList(growable: false)
          : const [],
      users: users is List
          ? users
              .whereType<Map>()
              .map((u) => AuditUserOption.fromJson(Map<String, dynamic>.from(u)))
              .toList(growable: false)
          : const [],
    );
  }
}

/// The full `GET /api/v1/audit` response.
class AuditPage {
  final List<AuditLogEntry> items;
  final PaginationMeta pagination;
  final AuditListMeta meta;

  const AuditPage({
    this.items = const [],
    required this.pagination,
    this.meta = const AuditListMeta(),
  });
}

// ─── Parse helpers ─────────────────────────────────────────────────────────

String _reqString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw AuditParseException('$key талбар буруу байна.');
  }
  return value.trim();
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

Map<String, dynamic>? _optJsonMap(Object? value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
}
