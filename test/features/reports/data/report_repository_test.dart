import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/reports/data/report_repository.dart';
import 'package:carcare_service/features/reports/data/reports_data_source.dart';
import 'package:carcare_service/features/reports/domain/reports_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _payload = {
  'range': {'label': 'Энэ сар', 'key': 'this-month'},
  'data': {'totalRevenue': 100},
};

void main() {
  group('request shaping', () {
    test('getReport omits empty from/to', () async {
      final ds = _RecordingDataSource(_payload);
      await RemoteReportsRepository(dataSource: ds).getReport();
      expect(ds.lastQuery, isEmpty);
    });

    test('getReport sends non-empty from/to', () async {
      final ds = _RecordingDataSource(_payload);
      await RemoteReportsRepository(dataSource: ds).getReport(
        query: const ReportRangeQuery(from: '2026-09-01', to: '2026-09-23'),
      );
      expect(ds.lastQuery, {'from': '2026-09-01', 'to': '2026-09-23'});
    });

    test('exportReport always sends both bounds', () async {
      final ds = _RecordingDataSource(_payload);
      await RemoteReportsRepository(dataSource: ds)
          .exportReport(from: '2026-09-01', to: '2026-09-23');
      expect(ds.lastExportQuery, {'from': '2026-09-01', 'to': '2026-09-23'});
    });
  });

  group('response handling', () {
    test('getReport unwraps range and data', () async {
      final result = await RemoteReportsRepository(
        dataSource: _RecordingDataSource(_payload),
      ).getReport();
      final value = (result as Ok).value;
      expect(value.range.label, 'Энэ сар');
      expect(value.data.totalRevenue, 100);
    });

    test('a parse failure becomes Err, never a thrown exception', () async {
      final result = await RemoteReportsRepository(
        dataSource: _RecordingDataSource({'wrong': 'envelope'}),
      ).getReport();
      expect(result, isA<Err>());
      expect((result as Err).error.kind, ErrorKind.unknown);
    });

    test('a 422 VALIDATION error passes through with fieldErrors', () async {
      const mapped = AppError(
        ErrorKind.unknown,
        'Хугацаа буруу байна.',
        statusCode: 422,
        code: 'VALIDATION',
        fieldErrors: {'to': 'to нь from-оос хойш байх ёстой.'},
      );
      final result = await RemoteReportsRepository(
        dataSource: _ThrowingDataSource(mapped),
      ).getReport();
      final error = (result as Err).error;
      expect(error.code, 'VALIDATION');
      expect(error.fieldErrors!['to'], isNotNull);
    });

    test('export resolves the filename from Content-Disposition', () async {
      final ds = _RecordingDataSource(
        _payload,
        exportContentDisposition:
            'attachment; filename="tailan_2026-09-01_2026-09-23.xlsx"',
      );
      final result = await RemoteReportsRepository(dataSource: ds)
          .exportReport(from: '2026-09-01', to: '2026-09-23');
      final file = (result as Ok).value;
      expect(file.filename, 'tailan_2026-09-01_2026-09-23.xlsx');
      expect(file.bytes, isNotEmpty);
    });

    test(
      'export falls back to tailan_<from>_<to>.xlsx with no header',
      () async {
        final ds = _RecordingDataSource(
          _payload,
          exportContentDisposition: null,
        );
        final result = await RemoteReportsRepository(dataSource: ds)
            .exportReport(from: '2026-09-01', to: '2026-09-23');
        final file = (result as Ok).value;
        expect(file.filename, 'tailan_2026-09-01_2026-09-23.xlsx');
      },
    );

    test('export falls back when Content-Disposition is unparsable', () async {
      final ds = _RecordingDataSource(
        _payload,
        exportContentDisposition: 'garbage',
      );
      final result = await RemoteReportsRepository(dataSource: ds)
          .exportReport(from: '2026-09-01', to: '2026-09-23');
      final file = (result as Ok).value;
      expect(file.filename, 'tailan_2026-09-01_2026-09-23.xlsx');
    });

    test(
      'an AppError from the shared mapper passes through verbatim on export',
      () async {
        const mapped = AppError(
          ErrorKind.unauthorized,
          'Нэвтрэх шаардлагатай',
          statusCode: 401,
        );
        final result = await RemoteReportsRepository(
          dataSource: _ThrowingDataSource(mapped),
        ).exportReport(from: '2026-09-01', to: '2026-09-23');
        expect((result as Err).error, same(mapped));
      },
    );
  });
}

class _RecordingDataSource implements ReportsDataSource {
  _RecordingDataSource(this.payload, {this.exportContentDisposition});

  final Object? payload;
  final String? exportContentDisposition;
  Map<String, dynamic>? lastQuery;
  Map<String, dynamic>? lastExportQuery;

  @override
  Future<Object?> get(Map<String, dynamic> query) async {
    lastQuery = query;
    return payload;
  }

  @override
  Future<ReportExportRaw> export(Map<String, dynamic> query) async {
    lastExportQuery = query;
    return ReportExportRaw(
      bytes: const [1, 2, 3],
      contentDisposition: exportContentDisposition,
    );
  }
}

class _ThrowingDataSource implements ReportsDataSource {
  _ThrowingDataSource(this.error);
  final AppError error;

  @override
  Future<Object?> get(Map<String, dynamic> query) async => throw error;

  @override
  Future<ReportExportRaw> export(Map<String, dynamic> query) async =>
      throw error;
}
