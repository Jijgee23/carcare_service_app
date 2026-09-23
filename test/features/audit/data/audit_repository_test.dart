import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/audit/data/audit_data_source.dart';
import 'package:carcare_service/features/audit/data/audit_repository.dart';
import 'package:carcare_service/features/audit/domain/audit_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _payload = {
  'items': <Object>[],
  'pagination': {
    'page': 1,
    'pageSize': 50,
    'total': 0,
    'totalPages': 0,
    'hasPrev': false,
    'hasNext': false,
  },
  'meta': {'actions': <Object>[], 'entities': <Object>[], 'users': <Object>[]},
};

void main() {
  group('request shaping', () {
    test('the default query sends only page', () async {
      final ds = _RecordingDataSource(_payload);
      await RemoteAuditRepository(dataSource: ds).getAuditLog();
      expect(ds.lastQuery, {'page': 1});
    });

    test('non-empty filters are sent, empty ones omitted', () async {
      final ds = _RecordingDataSource(_payload);
      await RemoteAuditRepository(dataSource: ds).getAuditLog(
        query: const AuditListQuery(
          q: '  захиалга  ',
          action: 'CREATE',
          entity: '',
          userId: 'u-1',
          from: '2026-09-01',
          page: 2,
        ),
      );
      expect(ds.lastQuery, {
        'page': 2,
        'q': 'захиалга',
        'action': 'CREATE',
        'userId': 'u-1',
        'from': '2026-09-01',
      });
    });
  });

  group('response handling', () {
    test('getAuditLog unwraps the page', () async {
      final result = await RemoteAuditRepository(
        dataSource: _RecordingDataSource(_payload),
      ).getAuditLog();
      expect((result as Ok).value.items, isEmpty);
    });

    test('a parse failure becomes Err, never a thrown exception', () async {
      final result = await RemoteAuditRepository(
        dataSource: _RecordingDataSource({'wrong': 'envelope'}),
      ).getAuditLog();
      expect(result, isA<Err>());
      expect((result as Err).error.kind, ErrorKind.unknown);
    });

    test('a 403 missing audit.view passes through', () async {
      const mapped = AppError(
        ErrorKind.forbidden,
        'Хандах эрх байхгүй',
        statusCode: 403,
      );
      final result = await RemoteAuditRepository(
        dataSource: _ThrowingDataSource(mapped),
      ).getAuditLog();
      expect((result as Err).error.statusCode, 403);
    });
  });
}

class _RecordingDataSource implements AuditDataSource {
  _RecordingDataSource(this.payload);
  final Object? payload;
  Map<String, dynamic>? lastQuery;

  @override
  Future<Object?> list(Map<String, dynamic> query) async {
    lastQuery = query;
    return payload;
  }
}

class _ThrowingDataSource implements AuditDataSource {
  _ThrowingDataSource(this.error);
  final AppError error;

  @override
  Future<Object?> list(Map<String, dynamic> query) async => throw error;
}
