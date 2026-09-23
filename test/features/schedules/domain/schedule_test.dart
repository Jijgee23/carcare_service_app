import 'package:carcare_service/features/schedules/domain/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Weekday', () {
    test('fromWire round-trips every known value', () {
      for (final w in [
        Weekday.sun,
        Weekday.mon,
        Weekday.tue,
        Weekday.wed,
        Weekday.thu,
        Weekday.fri,
        Weekday.sat,
      ]) {
        expect(Weekday.fromWire(w.wire), w);
      }
    });

    test('an unrecognised value is unknown, never aliased to a real day', () {
      expect(Weekday.fromWire('NOPE'), Weekday.unknown);
      expect(Weekday.fromWire(null), Weekday.unknown);
    });
  });

  group('ScheduleSource', () {
    test('fromWire maps the three server values plus unknown', () {
      expect(ScheduleSource.fromWire('exception'), ScheduleSource.exception);
      expect(ScheduleSource.fromWire('weekly'), ScheduleSource.weekly);
      expect(
        ScheduleSource.fromWire('default'),
        ScheduleSource.scheduleDefault,
      );
      expect(ScheduleSource.fromWire('garbage'), ScheduleSource.unknown);
    });
  });

  group('ScheduleRow', () {
    test('parses cells keyed by date', () {
      final row = ScheduleRow.fromJson({
        'id': 'u-1',
        'name': 'Дорж Бат',
        'cells': {
          '2026-09-21': {
            'weekday': 'MON',
            'working': true,
            'source': 'weekly',
            'segments': [
              {
                'branchId': 'b-1',
                'branchName': 'Салбар 1',
                'startTime': '09:00',
                'endTime': '18:00',
                'customTime': false,
              },
            ],
          },
        },
      });
      expect(row.id, 'u-1');
      final cell = row.cells['2026-09-21']!;
      expect(cell.working, isTrue);
      expect(cell.source, ScheduleSource.weekly);
      expect(cell.segments.single.branchId, 'b-1');
    });

    test('a missing id throws', () {
      expect(
        () => ScheduleRow.fromJson({'name': 'x'}),
        throwsA(isA<ScheduleParseException>()),
      );
    });

    test('a malformed cells map degrades to empty, never throws', () {
      final row = ScheduleRow.fromJson({'id': 'u-1', 'cells': 'garbage'});
      expect(row.cells, isEmpty);
    });
  });

  group('ScheduleGrid', () {
    test('parses the measured grid response', () {
      final grid = ScheduleGrid.fromJson({
        'view': 'week',
        'dates': ['2026-09-21', '2026-09-22'],
        'rows': [
          {'id': 'u-1', 'cells': const {}},
        ],
        'branches': [
          {
            'id': 'b-1',
            'name': 'Салбар 1',
            'schedules': [
              {
                'weekday': 'MON',
                'isOpen': true,
                'openTime': '09:00',
                'closeTime': '18:00',
              },
            ],
          },
        ],
        'countByBranch': {'b-1': 2, '': 1},
        'totalEmployees': 3,
        'canEdit': true,
      });
      expect(grid.dates, ['2026-09-21', '2026-09-22']);
      expect(grid.rows.single.id, 'u-1');
      expect(grid.countByBranch['b-1'], 2);
      expect(grid.canEdit, isTrue);
    });
  });

  group('MySchedule', () {
    test('row may be null while cells stays fully populated', () {
      final my = MySchedule.fromJson({
        'month': '2026-09',
        'dates': ['2026-09-01'],
        'row': null,
        'cells': {
          '2026-09-01': {
            'weekday': 'TUE',
            'working': false,
            'source': 'default',
          },
        },
        'branches': const [],
      });
      expect(my.row, isNull);
      expect(my.cells['2026-09-01']!.working, isFalse);
    });
  });

  group('write results', () {
    test('ScheduleUpsertResult parses scope/date/weekday', () {
      final r = ScheduleUpsertResult.fromJson({
        'message': 'Хадгалагдлаа.',
        'scope': 'date',
        'date': '2026-09-21',
      });
      expect(r.scope, ScheduleScope.date);
      expect(r.date, '2026-09-21');
    });

    test('ScheduleResetResult parses scope', () {
      final r = ScheduleResetResult.fromJson({'scope': 'weekday'});
      expect(r.scope, ScheduleScope.weekday);
    });

    test('ScheduleBulkResult parses applied', () {
      final r = ScheduleBulkResult.fromJson({'message': 'x', 'applied': 5});
      expect(r.applied, 5);
    });
  });
}
