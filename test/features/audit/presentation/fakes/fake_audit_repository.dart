import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/audit/domain/audit_log.dart';
import 'package:carcare_service/features/audit/domain/audit_repository.dart';

/// Hand-written fake for [AuditRepository] — P7-F3 presentation tests.
/// Mirrors `AuditListQuery`'s filter contract (`q`, `action`, `entity`,
/// `userId`, `from`, `to`) server-side, fixed page size 50, and always
/// returns `meta` alongside the page like the real `GET /api/v1/audit`.
class FakeAuditRepository implements AuditRepository {
  FakeAuditRepository({
    List<AuditLogEntry>? seed,
    this.pageSize = 50,
    this.failWith,
    this.failFromPage,
  }) : _entries = [...(seed ?? [seedEntry()])];

  final List<AuditLogEntry> _entries;
  final int pageSize;
  final AppError? failWith;

  /// When set, `getAuditLog` fails only once `query.page >= failFromPage` —
  /// lets a test exercise `loadMore`'s error path without also failing the
  /// initial load.
  final int? failFromPage;

  int listCalls = 0;

  static AuditLogEntry seedEntry({
    String id = 'a-1',
    String? entity = 'ServiceOrder',
    String? entityId = 'o-1',
    String? action = 'CREATE',
    String? summary = 'Захиалга үүсгэсэн',
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
    DateTime? createdAt,
    AuditActor? user,
    String? branchId,
  }) => AuditLogEntry(
    id: id,
    entity: entity,
    entityId: entityId,
    action: action,
    summary: summary,
    before: before,
    after: after ?? const {'status': 'NEW'},
    createdAt: createdAt ?? DateTime(2026, 1, 1, 9, 30),
    user: user ?? const AuditActor(id: 'u-1', firstName: 'Бат', lastName: 'Дорж'),
    branchId: branchId,
  );

  bool _matches(AuditLogEntry e, String q) {
    final lower = q.toLowerCase();
    bool ci(String? v) => v != null && v.toLowerCase().contains(lower);
    return ci(e.summary) || ci(e.entityId);
  }

  @override
  Future<Result<AuditPage>> getAuditLog({AuditListQuery? query}) async {
    listCalls++;
    final q = query ?? const AuditListQuery();
    if (failWith != null && (failFromPage == null || q.page >= failFromPage!)) {
      return Err(failWith!);
    }
    var rows = _entries.toList();
    if (q.q != null && q.q!.isNotEmpty) {
      rows = rows.where((e) => _matches(e, q.q!)).toList();
    }
    if (q.action != null) {
      rows = rows.where((e) => e.action == q.action).toList();
    }
    if (q.entity != null) {
      rows = rows.where((e) => e.entity == q.entity).toList();
    }
    if (q.userId != null) {
      rows = rows.where((e) => e.user?.id == q.userId).toList();
    }
    if (q.from != null) {
      final from = DateTime.parse(q.from!);
      rows = rows.where((e) => e.createdAt != null && !e.createdAt!.isBefore(from)).toList();
    }
    if (q.to != null) {
      final to = DateTime.parse(q.to!).add(const Duration(days: 1));
      rows = rows.where((e) => e.createdAt != null && e.createdAt!.isBefore(to)).toList();
    }

    final total = rows.length;
    final totalPages = (total / pageSize).ceil().clamp(1, 1 << 30);
    final page = q.page.clamp(1, totalPages);
    final skip = (page - 1) * pageSize;
    final items = rows.skip(skip).take(pageSize).toList(growable: false);

    return Ok(
      AuditPage(
        items: items,
        pagination: PaginationMeta(
          page: page,
          pageSize: pageSize,
          total: total,
          totalPages: totalPages,
          hasPrev: page > 1,
          hasNext: page < totalPages,
        ),
        meta: AuditListMeta(
          actions: _entries.map((e) => e.action).whereType<String>().toSet().toList(),
          entities: _entries.map((e) => e.entity).whereType<String>().toSet().toList(),
          users: _entries
              .map((e) => e.user)
              .whereType<AuditActor>()
              .map((u) => AuditUserOption(id: u.id, firstName: u.firstName, lastName: u.lastName))
              .toSet()
              .toList(),
        ),
      ),
    );
  }
}
