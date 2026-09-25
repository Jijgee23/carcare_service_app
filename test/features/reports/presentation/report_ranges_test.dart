import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/features/reports/presentation/report_ranges.dart';

void main() {
  group('reportQuickBounds', () {
    final now = DateTime(2026, 9, 23, 14, 30);

    test('thisMonth: first of month through now', () {
      final b = reportQuickBounds(ReportQuickRange.thisMonth, now);
      expect(b.from, DateTime(2026, 9, 1));
      expect(b.to, now);
    });

    test('lastMonth: full previous calendar month', () {
      final b = reportQuickBounds(ReportQuickRange.lastMonth, now);
      expect(b.from, DateTime(2026, 8, 1));
      expect(b.to, DateTime(2026, 8, 31, 23, 59, 59));
    });

    test('lastMonth handles the January year rollover', () {
      final jan = DateTime(2026, 1, 15);
      final b = reportQuickBounds(ReportQuickRange.lastMonth, jan);
      expect(b.from, DateTime(2025, 12, 1));
      expect(b.to, DateTime(2025, 12, 31, 23, 59, 59));
    });

    test('last30: 30 days back through now', () {
      final b = reportQuickBounds(ReportQuickRange.last30, now);
      expect(b.from, now.subtract(const Duration(days: 30)));
      expect(b.to, now);
    });

    test('thisYear: Jan 1 through now', () {
      final b = reportQuickBounds(ReportQuickRange.thisYear, now);
      expect(b.from, DateTime(2026, 1, 1));
      expect(b.to, now);
    });

    test(
      'custom falls back to this-month bounds (caller supplies real ones)',
      () {
        final b = reportQuickBounds(ReportQuickRange.custom, now);
        expect(b.from, DateTime(2026, 9, 1));
        expect(b.to, now);
      },
    );
  });

  group('reportYmd', () {
    test('pads month and day', () {
      expect(reportYmd(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });
}
