import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/audit/data/audit_data_source.dart';
import 'package:carcare_service/features/audit/data/audit_dto.dart';
import 'package:carcare_service/features/audit/domain/audit_log.dart';
import 'package:carcare_service/features/audit/domain/audit_repository.dart';

/// Remote adapter for [AuditRepository] — P7-F1.
class RemoteAuditRepository implements AuditRepository {
  RemoteAuditRepository({AuditDataSource? dataSource})
    : _dataSource = dataSource ?? RemoteAuditDataSource();

  final AuditDataSource _dataSource;

  @override
  Future<Result<AuditPage>> getAuditLog({AuditListQuery? query}) async {
    final effective = query ?? const AuditListQuery();
    try {
      return Ok(
        AuditPageDto.fromJson(await _dataSource.list(_query(effective))).value,
      );
    } catch (error) {
      return Err(_error(error, 'Аудит бүртгэл ачаалж чадсангүй'));
    }
  }
}

Map<String, dynamic> _query(AuditListQuery query) => {
  'page': query.page,
  if (query.q != null && query.q!.trim().isNotEmpty) 'q': query.q!.trim(),
  if (query.action != null && query.action!.isNotEmpty) 'action': query.action,
  if (query.entity != null && query.entity!.isNotEmpty) 'entity': query.entity,
  if (query.userId != null && query.userId!.isNotEmpty) 'userId': query.userId,
  if (query.from != null && query.from!.isNotEmpty) 'from': query.from,
  if (query.to != null && query.to!.isNotEmpty) 'to': query.to,
};

AppError _error(Object error, String fallback) => switch (error) {
  AppError value => value,
  AuditParseException value => AppError(ErrorKind.unknown, value.message),
  _ => AppError(ErrorKind.unknown, fallback),
};
