import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/features/schedules/domain/schedule.dart';
import 'package:carcare_service/features/schedules/presentation/schedule_dates.dart';

void main() {
  test('ymd formats with zero-padding', () {
    expect(ymd(DateTime(2026, 1, 5)), '2026-01-05');
  });

  test('yearMonth formats with zero-padding', () {
    expect(yearMonth(DateTime(2026, 9, 21)), '2026-09');
  });

  test('weekdayOf maps DateTime.weekday to the wire enum', () {
    expect(weekdayOf(DateTime(2026, 9, 21)), Weekday.mon); // Monday
    expect(weekdayOf(DateTime(2026, 9, 27)), Weekday.sun); // Sunday
  });

  test('startOfWeek anchors to Monday', () {
    expect(startOfWeek(DateTime(2026, 9, 24)), DateTime(2026, 9, 21));
    expect(startOfWeek(DateTime(2026, 9, 27)), DateTime(2026, 9, 21));
  });

  test('weekDates returns 7 consecutive Monday-anchored days', () {
    final dates = weekDates(DateTime(2026, 9, 24));
    expect(dates, hasLength(7));
    expect(dates.first, DateTime(2026, 9, 21));
    expect(dates.last, DateTime(2026, 9, 27));
  });

  test('addMonths rolls over year boundaries both directions', () {
    expect(addMonths(DateTime(2026, 12, 1), 1), DateTime(2027, 1, 1));
    expect(addMonths(DateTime(2026, 1, 1), -1), DateTime(2025, 12, 1));
  });

  test('monthGrid includes leading and trailing days for full weeks', () {
    // 2026-09-01 is a Tuesday, so the grid must lead with Monday 2026-08-31.
    final cells = monthGrid(DateTime(2026, 9, 1));
    expect(cells.first.date, DateTime(2026, 8, 31));
    expect(cells.first.inMonth, isFalse);
    final septemberCells = cells.where((c) => c.inMonth).toList();
    expect(septemberCells.first.date, DateTime(2026, 9, 1));
    expect(septemberCells.last.date, DateTime(2026, 9, 30));
    // Every row is a full week.
    expect(cells.length % 7, 0);
  });
}
