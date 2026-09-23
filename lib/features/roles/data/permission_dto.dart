/// Envelope parsing for the permission catalogue — P6-F1.
library;

import 'package:carcare_service/features/roles/domain/permission.dart';

typedef JsonMap = Map<String, dynamic>;

JsonMap _map(Object? value, String label) {
  if (value is! Map) throw PermissionParseException('$label буруу байна.');
  return Map<String, dynamic>.from(value);
}

/// `GET /api/v1/permissions` — `{groups:[...], standalone:[...]}`.
class PermissionCatalogDto {
  const PermissionCatalogDto(this.value);
  final PermissionCatalog value;

  factory PermissionCatalogDto.fromJson(Object? raw) {
    final json = _map(raw, 'permissions response');
    final groups = json['groups'];
    final standalone = json['standalone'];
    return PermissionCatalogDto(
      PermissionCatalog(
        groups: groups is List
            ? groups
                  .whereType<Map>()
                  .map(
                    (g) =>
                        PermissionGroup.fromJson(Map<String, dynamic>.from(g)),
                  )
                  .toList(growable: false)
            : const [],
        standalone: standalone is List
            ? standalone
                  .whereType<Map>()
                  .map(
                    (i) =>
                        PermissionItem.fromJson(Map<String, dynamic>.from(i)),
                  )
                  .toList(growable: false)
            : const [],
      ),
    );
  }
}
