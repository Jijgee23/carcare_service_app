/// Envelope parsing for Audit — P7-F1. Field-level tolerance lives on the
/// domain models (`audit_log.dart`); this file only unwraps the top-level
/// response envelope and enforces the handful of structurally required
/// pieces, mirroring `EmployeePageDto`.
library;

import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/features/audit/domain/audit_log.dart';

typedef JsonMap = Map<String, dynamic>;

JsonMap _map(Object? value, String label) {
  if (value is! Map) throw AuditParseException('$label буруу байна.');
  return Map<String, dynamic>.from(value);
}

int _requiredInt(JsonMap json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw AuditParseException('$key буруу байна.');
}

bool _requiredBool(JsonMap json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw AuditParseException('$key буруу байна.');
}

PaginationMeta _pagination(Object? raw) {
  final json = _map(raw, 'pagination');
  final page = _requiredInt(json, 'page');
  final pageSize = _requiredInt(json, 'pageSize');
  final total = _requiredInt(json, 'total');
  final totalPages = _requiredInt(json, 'totalPages');
  if (page < 1 || pageSize < 1 || total < 0 || totalPages < 0) {
    throw const AuditParseException('Хуудаслалтын мэдээлэл буруу байна.');
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

/// `GET /api/v1/audit` — `{items:[...], pagination, meta}`.
///
/// A non-map entry in `items` is skipped rather than throwing; a row whose
/// `id` is missing still throws — an audit row with no id cannot be keyed
/// in a list, and silently dropping it would hide a real server defect.
class AuditPageDto {
  const AuditPageDto(this.value);
  final AuditPage value;

  factory AuditPageDto.fromJson(Object? raw) {
    final json = _map(raw, 'аудит хариу');
    final list = json['items'];
    if (list is! List) {
      throw const AuditParseException('Аудит жагсаалт буруу байна.');
    }
    final items = list
        .whereType<Map>()
        .map((item) => AuditLogEntry.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    return AuditPageDto(
      AuditPage(
        items: items,
        pagination: _pagination(json['pagination']),
        meta: AuditListMeta.fromJson(json['meta']),
      ),
    );
  }
}
