/// Quick-range definitions for the Reports screen — P7-F2.
///
/// Mirrors `carcare.mn/app/dashboard/reports/page.tsx`'s `QUICK_RANGES` and
/// `quickBounds` exactly (local-date semantics, no timezone conversion —
/// the web's `fmt`/`parseRange` are local-date already per
/// `TENANT_MOBILE_SLICES.md` "Phase 7 entry state"). Kept dependency-light
/// (no `intl`), same spirit as `schedules/presentation/schedule_dates.dart`.
library;

enum ReportQuickRange { thisMonth, lastMonth, last30, thisYear, custom }

/// Display order + labels for the quick-range chip row. `custom` never
/// renders as a chip (it can only be entered via the date-range picker) —
/// callers should iterate [chipOrder], not `ReportQuickRange.values`.
const List<ReportQuickRange> reportQuickRangeChipOrder = [
  ReportQuickRange.thisMonth,
  ReportQuickRange.lastMonth,
  ReportQuickRange.last30,
  ReportQuickRange.thisYear,
];

const Map<ReportQuickRange, String> reportQuickRangeLabels = {
  ReportQuickRange.thisMonth: 'Энэ сар',
  ReportQuickRange.lastMonth: 'Өнгөрсөн сар',
  ReportQuickRange.last30: 'Сүүлийн 30 хоног',
  ReportQuickRange.thisYear: 'Энэ жил',
  ReportQuickRange.custom: 'Хугацаа сонгох',
};

class ReportDateBounds {
  final DateTime from;
  final DateTime to;
  const ReportDateBounds(this.from, this.to);
}

/// `quickBounds()` on the web, ported 1:1. `custom` has no bounds of its
/// own (the caller supplies them via the date-range picker) and falls back
/// to the "this month" bounds here only so this function stays total.
ReportDateBounds reportQuickBounds(ReportQuickRange key, DateTime now) {
  switch (key) {
    case ReportQuickRange.lastMonth:
      final from = DateTime(now.year, now.month - 1, 1);
      final to = DateTime(now.year, now.month, 0, 23, 59, 59);
      return ReportDateBounds(from, to);
    case ReportQuickRange.last30:
      return ReportDateBounds(now.subtract(const Duration(days: 30)), now);
    case ReportQuickRange.thisYear:
      return ReportDateBounds(DateTime(now.year, 1, 1), now);
    case ReportQuickRange.thisMonth:
    case ReportQuickRange.custom:
      return ReportDateBounds(DateTime(now.year, now.month, 1), now);
  }
}

/// `YYYY-MM-DD`, matching the wire format every report endpoint expects
/// (`lib/reports.ts`'s `fmt`).
String reportYmd(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime reportDateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);
