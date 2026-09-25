/// Business wall-clock time for CarCare: Asia/Ulaanbaatar, a fixed UTC+8
/// (Mongolia has not observed DST since 2017).
///
/// The server stores instants in UTC and reads booking times without a zone
/// as +08:00 (`lib/booking-time.ts`). Converting with the *device* zone
/// (`toLocal()`) broke on phones set to another zone — including Mongolia's
/// own UTC+7 west (Khovd, Uvs, Bayan-Ölgii) — shifting bookings by an hour.
///
/// The returned values are "naive" (non-UTC) [DateTime]s holding Ulaanbaatar
/// wall-clock fields, so they display and format as business time on any
/// device.
library;

const businessUtcOffset = Duration(hours: 8);

/// The Ulaanbaatar wall-clock time of [instant] (UTC or device-local).
DateTime toBusinessTime(DateTime instant) {
  final t = instant.toUtc().add(businessUtcOffset);
  return DateTime(
    t.year,
    t.month,
    t.day,
    t.hour,
    t.minute,
    t.second,
    t.millisecond,
  );
}

/// Parses a server ISO instant (`…Z` / with offset) into business time.
/// Null for a missing or malformed value.
DateTime? parseBusinessTime(Object? iso) {
  if (iso is! String) return null;
  final parsed = DateTime.tryParse(iso.trim());
  return parsed == null ? null : toBusinessTime(parsed);
}

/// "Now" on the business clock — compare business times against this, not
/// [DateTime.now], which is device-zone wall time.
DateTime businessNow() => toBusinessTime(DateTime.now());
