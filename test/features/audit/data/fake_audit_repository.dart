import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/audit/domain/audit_log.dart';
import 'package:carcare_service/features/audit/domain/audit_repository.dart';

/// Hand-written fake for [AuditRepository] — P7-F1, for later widget tests
/// (`P7-F3`).
class FakeAuditRepository implements AuditRepository {
  FakeAuditRepository({List<AuditLogEntry>? seed})
    : _entries = [...(seed ?? [_seedEntry()])];

  final List<AuditLogEntry> _entries;
  int getCalls = 0;

  static AuditLogEntry _seedEntry({String id = 'a-1'}) => AuditLogEntry(
    id: id,
    entity: 'ServiceOrder',
    entityId: 'o-1',
    action: 'STATUS_CHANGE',
    summary: 'Төлөв өөрчлөгдсөн',
    before: const {'status': 'SCHEDULED'},
    after: const {'status': 'IN_PROGRESS'},
    createdAt: DateTime(2026, 9, 20),
  );

  @override
  Future<Result<AuditPage>> getAuditLog({AuditListQuery? query}) async {
    getCalls++;
    final q = query ?? const AuditListQuery();
    var rows = _entries.toList();
    if (q.action != null && q.action!.isNotEmpty) {
      rows = rows.where((e) => e.action == q.action).toList();
    }
    if (q.entity != null && q.entity!.isNotEmpty) {
      rows = rows.where((e) => e.entity == q.entity).toList();
    }
    final total = rows.length;
    return Ok(
      AuditPage(
        items: rows,
        pagination: PaginationMeta(
          page: q.page,
          pageSize: 50,
          total: total,
          totalPages: (total / 50).ceil().clamp(1, 1 << 30),
          hasPrev: q.page > 1,
          hasNext: false,
        ),
        meta: const AuditListMeta(
          actions: ['CREATE', 'STATUS_CHANGE'],
          entities: ['ServiceOrder'],
        ),
      ),
    );
  }
}
