import 'package:carcare_service/core/utils/business_time.dart';
import 'package:carcare_service/features/appointments/domain/appointment.dart';
import 'package:flutter_test/flutter_test.dart';

/// All inputs are explicit UTC instants, so these hold on any machine/device
/// zone — the bug this guards against only showed on non-UTC+8 phones.
void main() {
  test('UTC instant → Ulaanbaatar wall clock (+8)', () {
    final t = toBusinessTime(DateTime.utc(2026, 9, 25, 2, 30));
    expect(t.isUtc, isFalse);
    expect([t.year, t.month, t.day, t.hour, t.minute], [2026, 9, 25, 10, 30]);
  });

  test('crosses midnight into the next business day', () {
    final t = toBusinessTime(DateTime.utc(2026, 9, 25, 17, 0));
    expect([t.day, t.hour], [26, 1]);
  });

  test('parses server ISO strings with Z or an explicit offset', () {
    expect(parseBusinessTime('2026-09-25T02:00:00.000Z')?.hour, 10);
    expect(parseBusinessTime('2026-09-25T10:00:00+08:00')?.hour, 10);
    expect(parseBusinessTime('2026-09-25T09:00:00+07:00')?.hour, 10);
    expect(parseBusinessTime(null), isNull);
    expect(parseBusinessTime('garbage'), isNull);
  });

  test('appointment requestedAt shows business time whatever the device zone', () {
    final appt = AppointmentSummary.fromJson({
      'id': 'a1',
      'requestedAt': '2026-09-25T02:00:00.000Z',
    });
    expect(appt.requestedAt?.hour, 10);
    expect(appt.requestedAt?.minute, 0);
  });
}
