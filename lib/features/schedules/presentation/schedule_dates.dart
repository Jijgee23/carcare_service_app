/// Date helpers shared by the Schedules presentation layer — P6-F4. Kept
/// small and dependency-light (no `intl` `DateFormat` — `yyyy-MM-dd` is
/// simple enough to build by hand and this avoids locale surprises for a
/// wire format, not a display string).
library;

import 'package:carcare_service/features/schedules/domain/schedule.dart';

/// `YYYY-MM-DD`, matching every date this feature's wire contract uses.
String ymd(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// `YYYY-MM`.
String yearMonth(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// [Weekday] of a plain [DateTime] — `DateTime.weekday` is Monday=1..Sunday=7.
Weekday weekdayOf(DateTime date) => switch (date.weekday) {
  DateTime.monday => Weekday.mon,
  DateTime.tuesday => Weekday.tue,
  DateTime.wednesday => Weekday.wed,
  DateTime.thursday => Weekday.thu,
  DateTime.friday => Weekday.fri,
  DateTime.saturday => Weekday.sat,
  DateTime.sunday => Weekday.sun,
  _ => Weekday.unknown,
};

/// Monday-anchored start of the week containing [date].
DateTime startOfWeek(DateTime date) {
  final d = dateOnly(date);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

/// The seven dates of the Monday-anchored week containing [date].
List<DateTime> weekDates(DateTime date) {
  final start = startOfWeek(date);
  return List.generate(7, (i) => start.add(Duration(days: i)));
}

DateTime addMonths(DateTime date, int months) {
  final total = date.year * 12 + (date.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  return DateTime(year, month, 1);
}

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// A full calendar-grid month for [anchor]'s month: leading days from the
/// previous month and trailing days from the next, so every row is a full
/// Monday-Sunday week. `inMonth` flags which entries belong to the target
/// month (leading/trailing days are still real, tappable dates — this
/// mirrors `month-calendar.tsx`'s parity behaviour).
List<MonthCell> monthGrid(DateTime anchor) {
  final firstOfMonth = DateTime(anchor.year, anchor.month, 1);
  final gridStart = startOfWeek(firstOfMonth);
  final daysThisMonth = daysInMonth(anchor.year, anchor.month);
  final lastOfMonth = DateTime(anchor.year, anchor.month, daysThisMonth);
  final gridEnd = startOfWeek(lastOfMonth).add(const Duration(days: 6));
  final totalDays = gridEnd.difference(gridStart).inDays + 1;
  return List.generate(totalDays, (i) {
    final date = gridStart.add(Duration(days: i));
    return MonthCell(date: date, inMonth: date.month == anchor.month);
  });
}

class MonthCell {
  final DateTime date;
  final bool inMonth;
  const MonthCell({required this.date, required this.inMonth});
}
