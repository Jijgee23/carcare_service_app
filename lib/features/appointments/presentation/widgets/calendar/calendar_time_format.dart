import 'package:intl/intl.dart';

import 'package:carcare_service/features/appointments/domain/appointment.dart';

final _hm = DateFormat('HH:mm');

/// Formats a block's time range for display. This only *formats* the three
/// fields the server already computed (`startAt`, `finishKnown`,
/// `endsAtDayBoundary`) — it never infers any of them. Mirrors
/// `calendar-day-model.ts`'s `buildAccessibleLabel` end-time rule exactly:
/// - unknown finish → "тодорхойгүй" ("unknown"), visually distinct from a
///   known time so open-ended work never reads as a precise finish;
/// - a finish that lands exactly on the day boundary → "24:00", never the
///   raw (following-midnight) timestamp, so it never reads as an in-day
///   finish either.
String calendarBlockTimeLabel(CalendarBlock block) {
  final start = block.startAt;
  final startLabel = start != null ? _hm.format(start) : '--:--';
  final String endLabel;
  if (!block.finishKnown) {
    endLabel = 'тодорхойгүй';
  } else if (block.endsAtDayBoundary) {
    endLabel = '24:00';
  } else {
    final end = block.endAt;
    endLabel = end != null ? _hm.format(end) : 'тодорхойгүй';
  }
  return '$startLabel–$endLabel';
}
