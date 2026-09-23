import 'package:carcare_service/features/schedules/data/schedule_dto.dart';
import 'package:carcare_service/features/schedules/domain/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScheduleGridDto', () {
    test('parses the un-wrapped grid response', () {
      final grid = ScheduleGridDto.fromJson({
        'view': 'week',
        'dates': const ['2026-09-21'],
        'rows': const [],
        'branches': const [],
        'countByBranch': const {},
        'totalEmployees': 0,
        'canEdit': false,
      }).value;
      expect(grid.view, 'week');
    });

    test('a non-map response throws', () {
      expect(
        () => ScheduleGridDto.fromJson('nope'),
        throwsA(isA<ScheduleParseException>()),
      );
    });
  });

  group('MyScheduleDto', () {
    test('parses the un-wrapped my-schedule response', () {
      final my = MyScheduleDto.fromJson({
        'month': '2026-09',
        'dates': const [],
        'row': null,
        'cells': const {},
        'branches': const [],
      }).value;
      expect(my.month, '2026-09');
    });
  });

  group(
    'ScheduleUpsertResultDto / ScheduleResetResultDto / ScheduleBulkResultDto',
    () {
      test('parse their bare envelopes', () {
        expect(
          ScheduleUpsertResultDto.fromJson({'scope': 'date'}).value.scope,
          ScheduleScope.date,
        );
        expect(
          ScheduleResetResultDto.fromJson({'scope': 'weekday'}).value.scope,
          ScheduleScope.weekday,
        );
        expect(ScheduleBulkResultDto.fromJson({'applied': 4}).value.applied, 4);
      });
    },
  );
}
