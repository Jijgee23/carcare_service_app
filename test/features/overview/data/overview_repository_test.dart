import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/overview/data/overview_data_source.dart';
import 'package:carcare_service/features/overview/data/overview_repository.dart';
import 'package:carcare_service/features/overview/domain/overview_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _payload = {
  'overview': {
    'counts': {'branches': 1},
  },
};

void main() {
  group('request shaping', () {
    test('an empty query sends no params', () async {
      final ds = _RecordingDataSource(_payload);
      await RemoteOverviewRepository(dataSource: ds).getOverview();
      expect(ds.lastQuery, isEmpty);
    });

    test('non-empty range/from/to are sent', () async {
      final ds = _RecordingDataSource(_payload);
      await RemoteOverviewRepository(dataSource: ds).getOverview(
        query: const OverviewRangeQuery(
          range: 'custom',
          from: '2026-09-01',
          to: '2026-09-23',
        ),
      );
      expect(ds.lastQuery, {
        'range': 'custom',
        'from': '2026-09-01',
        'to': '2026-09-23',
      });
    });
  });

  group('response handling', () {
    test('getOverview unwraps the envelope', () async {
      final result = await RemoteOverviewRepository(
        dataSource: _RecordingDataSource(_payload),
      ).getOverview();
      expect((result as Ok).value.counts.branches, 1);
    });

    test('a parse failure becomes Err, never a thrown exception', () async {
      final result = await RemoteOverviewRepository(
        dataSource: _RecordingDataSource({'wrong': 'envelope'}),
      ).getOverview();
      expect(result, isA<Err>());
      expect((result as Err).error.kind, ErrorKind.unknown);
    });

    test('an AppError from the shared mapper passes through verbatim', () async {
      const mapped = AppError(ErrorKind.unauthorized, 'Нэвтрэх шаардлагатай', statusCode: 401);
      final result = await RemoteOverviewRepository(
        dataSource: _ThrowingDataSource(mapped),
      ).getOverview();
      expect((result as Err).error, same(mapped));
    });
  });
}

class _RecordingDataSource implements OverviewDataSource {
  _RecordingDataSource(this.payload);
  final Object? payload;
  Map<String, dynamic>? lastQuery;

  @override
  Future<Object?> get(Map<String, dynamic> query) async {
    lastQuery = query;
    return payload;
  }
}

class _ThrowingDataSource implements OverviewDataSource {
  _ThrowingDataSource(this.error);
  final AppError error;

  @override
  Future<Object?> get(Map<String, dynamic> query) async => throw error;
}
