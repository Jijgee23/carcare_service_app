import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/schedules/data/schedule_repository.dart';
import 'package:carcare_service/features/schedules/data/schedules_data_source.dart';
import 'package:carcare_service/features/schedules/domain/schedule.dart';
import 'package:carcare_service/features/schedules/domain/schedules_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('request shaping', () {
    test('getGrid defaults to view=week, no other params', () async {
      final ds = _RecordingDataSource(_gridPayload);
      await RemoteSchedulesRepository(dataSource: ds).getGrid();
      expect(ds.lastGridQuery, {'view': 'week'});
    });

    test('getGrid sends only non-empty optional params', () async {
      final ds = _RecordingDataSource(_gridPayload);
      await RemoteSchedulesRepository(dataSource: ds).getGrid(
        query: const ScheduleGridQuery(
          view: 'month',
          date: '2026-09-01',
          branchId: 'b-1',
          q: 'Бат',
        ),
      );
      expect(ds.lastGridQuery, {
        'view': 'month',
        'date': '2026-09-01',
        'branchId': 'b-1',
        'q': 'Бат',
      });
    });

    test(
      'upsert sends scope, one of date/weekday, isWorking, segments',
      () async {
        final ds = _RecordingDataSource({'scope': 'date'});
        await RemoteSchedulesRepository(dataSource: ds).upsert(
          'u-1',
          scope: ScheduleScope.date,
          date: '2026-09-21',
          isWorking: true,
          segments: const [
            ScheduleSegmentInput(
              branchId: 'b-1',
              startTime: '09:00',
              endTime: '18:00',
            ),
          ],
        );
        expect(ds.lastUpsertUserId, 'u-1');
        expect(ds.lastUpsertBody, {
          'scope': 'date',
          'date': '2026-09-21',
          'isWorking': true,
          'segments': [
            {'branchId': 'b-1', 'startTime': '09:00', 'endTime': '18:00'},
          ],
        });
      },
    );

    test('reset sends scope and weekday as query params', () async {
      final ds = _RecordingDataSource({'scope': 'weekday'});
      await RemoteSchedulesRepository(dataSource: ds)
          .reset('u-1', scope: ScheduleScope.weekday, weekday: Weekday.mon);
      expect(ds.lastResetQuery, {'scope': 'weekday', 'weekday': 'MON'});
    });

    test(
      'bulkUpsert sends targets with only the populated scope field',
      () async {
        final ds = _RecordingDataSource({'applied': 2});
        await RemoteSchedulesRepository(dataSource: ds).bulkUpsert(
          scope: ScheduleScope.weekday,
          isWorking: false,
          targets: const [
            ScheduleBulkTarget(userId: 'u-1', weekday: Weekday.tue),
            ScheduleBulkTarget(userId: 'u-2', weekday: Weekday.wed),
          ],
        );
        expect(ds.lastBulkBody!['targets'], [
          {'userId': 'u-1', 'weekday': 'TUE'},
          {'userId': 'u-2', 'weekday': 'WED'},
        ]);
      },
    );
  });

  group('response handling', () {
    test('getMySchedule unwraps the response', () async {
      final result = await RemoteSchedulesRepository(
        dataSource: _RecordingDataSource({
          'month': '2026-09',
          'dates': const [],
          'cells': const {},
          'branches': const [],
        }),
      ).getMySchedule(month: '2026-09');
      expect((result as Ok).value.month, '2026-09');
    });

    test('a parse failure becomes Err, never a thrown exception', () async {
      final result = await RemoteSchedulesRepository(
        dataSource: _RecordingDataSource('garbage'),
      ).getGrid();
      expect(result, isA<Err>());
    });

    test('a 403 FORBIDDEN write rejection passes through verbatim', () async {
      const mapped = AppError(
        ErrorKind.forbidden,
        'Хандах эрх байхгүй',
        statusCode: 403,
        code: 'FORBIDDEN',
      );
      final result = await RemoteSchedulesRepository(
        dataSource: _ThrowingDataSource(mapped),
      ).upsert('u-1', scope: ScheduleScope.date, isWorking: true);
      expect((result as Err).error.code, 'FORBIDDEN');
    });

    test(
      'a 404 NOT_FOUND target-not-in-tenant rejection passes through',
      () async {
        const mapped = AppError(
          ErrorKind.notFound,
          'Олдсонгүй',
          statusCode: 404,
          code: 'NOT_FOUND',
        );
        final result = await RemoteSchedulesRepository(
          dataSource: _ThrowingDataSource(mapped),
        ).reset('u-1', scope: ScheduleScope.date, date: '2026-09-21');
        expect((result as Err).error.code, 'NOT_FOUND');
      },
    );

    test('a 400 VALIDATION rejection keeps its fieldErrors', () async {
      const mapped = AppError(
        ErrorKind.unknown,
        'Хүсэлт буруу.',
        statusCode: 400,
        code: 'VALIDATION',
        fieldErrors: {'segments': 'Цаг буруу.'},
      );
      final result =
          await RemoteSchedulesRepository(
            dataSource: _ThrowingDataSource(mapped),
          ).bulkUpsert(
            scope: ScheduleScope.date,
            isWorking: true,
            targets: const [
              ScheduleBulkTarget(userId: 'u-1', date: '2026-09-21'),
            ],
          );
      expect((result as Err).error.fieldErrors!['segments'], isNotNull);
    });
  });
}

const _gridPayload = {
  'view': 'week',
  'dates': <String>[],
  'rows': <Object>[],
  'branches': <Object>[],
  'countByBranch': <String, int>{},
  'totalEmployees': 0,
  'canEdit': false,
};

class _RecordingDataSource implements SchedulesDataSource {
  _RecordingDataSource(this.payload);
  final Object? payload;
  Map<String, dynamic>? lastGridQuery;
  Map<String, dynamic>? lastMyQuery;
  String? lastUpsertUserId;
  Map<String, dynamic>? lastUpsertBody;
  Map<String, dynamic>? lastResetQuery;
  Map<String, dynamic>? lastBulkBody;

  @override
  Future<Object?> grid(Map<String, dynamic> query) async {
    lastGridQuery = query;
    return payload;
  }

  @override
  Future<Object?> mySchedule(Map<String, dynamic> query) async {
    lastMyQuery = query;
    return payload;
  }

  @override
  Future<Object?> upsert(String userId, Map<String, dynamic> body) async {
    lastUpsertUserId = userId;
    lastUpsertBody = body;
    return payload;
  }

  @override
  Future<Object?> reset(String userId, Map<String, dynamic> query) async {
    lastResetQuery = query;
    return payload;
  }

  @override
  Future<Object?> bulkUpsert(Map<String, dynamic> body) async {
    lastBulkBody = body;
    return payload;
  }
}

class _ThrowingDataSource implements SchedulesDataSource {
  _ThrowingDataSource(this.error);
  final AppError error;

  @override
  Future<Object?> grid(Map<String, dynamic> query) async => throw error;
  @override
  Future<Object?> mySchedule(Map<String, dynamic> query) async => throw error;
  @override
  Future<Object?> upsert(String userId, Map<String, dynamic> body) async =>
      throw error;
  @override
  Future<Object?> reset(String userId, Map<String, dynamic> query) async =>
      throw error;
  @override
  Future<Object?> bulkUpsert(Map<String, dynamic> body) async => throw error;
}
