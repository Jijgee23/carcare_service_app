/// Roles domain model — P6-F1.
///
/// Measured against `app/api/v1/roles/route.ts` (GET/POST) and
/// `app/api/v1/roles/[id]/route.ts` (GET/PATCH/DELETE) after `P6-B0`/
/// `P6-B2`, and `lib/roles/dto.ts`'s `toRoleDto`.
///
/// **Role management is owner-only** (D-171): only `auth.user.isOwner` may
/// POST/PATCH/DELETE. `GET` is open to any of `employees.view`/`.create`/
/// `.edit`, matching the employee create/edit form's role picker — see that
/// route's doc comment. There are no `roles.*` permission codes.
library;

class RoleParseException implements Exception {
  const RoleParseException(this.message);
  final String message;

  @override
  String toString() => 'RoleParseException: $message';
}

/// One tenant role row — `{id, name, description, permissions, isActive}`,
/// plus `userCount` from `_count.users` when the server includes it (not
/// selected by every route today; `null` when absent).
class Role {
  final String id;
  final String? name;
  final String? description;
  final List<String> permissions;
  final bool isActive;
  final int? userCount;

  const Role({
    required this.id,
    this.name,
    this.description,
    this.permissions = const [],
    this.isActive = true,
    this.userCount,
  });

  factory Role.fromJson(Map<String, dynamic> j) => Role(
    id: _reqString(j, 'id'),
    name: _optString(j['name']),
    description: _optString(j['description']),
    permissions: _stringList(j['permissions']),
    isActive: _optBool(j['isActive']) ?? true,
    userCount: _optInt(j['userCount']),
  );
}

/// `DELETE /api/v1/roles/[id]` — `{id}`.
class RoleIdResult {
  final String id;
  const RoleIdResult({required this.id});

  factory RoleIdResult.fromJson(Map<String, dynamic> j) =>
      RoleIdResult(id: _reqString(j, 'id'));
}

String _reqString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw RoleParseException('$key талбар буруу байна.');
  }
  return value.trim();
}

String? _optString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool? _optBool(Object? value) => value is bool ? value : null;

int? _optInt(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value.trim());
  return null;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}
