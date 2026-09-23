import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/audit/domain/audit_log.dart';

/// Server-side filters supported by `GET /api/v1/audit`, measured against
/// `app/api/v1/audit/route.ts`'s `ALLOWED_PARAMS`: `q`, `action`, `entity`,
/// `userId`, `from`, `to`, `page`. Page size is fixed server-side at 50
/// (`AUDIT_PAGE_SIZE`) — this class has no `pageSize`.
class AuditListQuery {
  final String? q;
  final String? action;
  final String? entity;
  final String? userId;

  /// Inclusive, local calendar date (`YYYY-MM-DD`).
  final String? from;

  /// Inclusive, local calendar date (`YYYY-MM-DD`).
  final String? to;
  final int page;

  const AuditListQuery({
    this.q,
    this.action,
    this.entity,
    this.userId,
    this.from,
    this.to,
    this.page = 1,
  });
}

/// One frozen repository contract for the Audit feature — P7-F1.
///
/// Errors a caller must expect:
/// * `401` — no code.
/// * `403` — missing `audit.view`.
/// * `422 VALIDATION` — bad range params or an unknown query key, carries
///   `fieldErrors`.
abstract interface class AuditRepository {
  /// `GET /api/v1/audit`.
  Future<Result<AuditPage>> getAuditLog({AuditListQuery? query});
}
