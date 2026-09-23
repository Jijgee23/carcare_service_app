/// Permission catalogue model — P6-F1. Measured against
/// `app/api/v1/permissions/route.ts`, which serves the tenant-independent
/// `PERMISSIONS` catalogue (`lib/auth/permissions.ts`) grouped, plus a
/// standalone list. There is deliberately **no hardcoded permission code**
/// anywhere in this feature — every code, label, and grouping this client
/// knows about comes from this endpoint (`PermissionCatalogRepository`).
library;

class PermissionParseException implements Exception {
  const PermissionParseException(this.message);
  final String message;

  @override
  String toString() => 'PermissionParseException: $message';
}

/// One permission entry — `{code, label, description}` inside a group, or
/// `{code, label, description, group}` standalone.
class PermissionItem {
  final String code;
  final String? label;
  final String? description;
  final String? group;

  const PermissionItem({
    required this.code,
    this.label,
    this.description,
    this.group,
  });

  factory PermissionItem.fromJson(Map<String, dynamic> j) => PermissionItem(
    code: _reqString(j, 'code'),
    label: _optString(j['label']),
    description: _optString(j['description']),
    group: _optString(j['group']),
  );
}

/// One `groups[]` entry — `{group, items:[...]}`.
class PermissionGroup {
  final String? group;
  final List<PermissionItem> items;

  const PermissionGroup({this.group, this.items = const []});

  factory PermissionGroup.fromJson(Map<String, dynamic> j) {
    final items = j['items'];
    return PermissionGroup(
      group: _optString(j['group']),
      items: items is List
          ? items
                .whereType<Map>()
                .map(
                  (i) => PermissionItem.fromJson(Map<String, dynamic>.from(i)),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

/// The full `GET /api/v1/permissions` response — `{groups, standalone}`.
class PermissionCatalog {
  final List<PermissionGroup> groups;
  final List<PermissionItem> standalone;

  const PermissionCatalog({this.groups = const [], this.standalone = const []});

  /// Every known permission code, flattened across grouped and standalone
  /// entries — the closed set a role's `permissions` list may validly draw
  /// from, per this client's own knowledge (the server is still
  /// authoritative on `validateOrderScopes` and any other cross-field rule).
  List<PermissionItem> get all => [
    for (final g in groups) ...g.items,
    ...standalone,
  ];
}

String _reqString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw PermissionParseException('$key талбар буруу байна.');
  }
  return value.trim();
}

String? _optString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
