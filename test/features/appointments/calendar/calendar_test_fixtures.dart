import 'package:carcare_service/features/appointments/domain/appointment.dart';

/// Shared fixtures for the P2-F3 calendar test suite. Every block here
/// mirrors a field combination `calendar-day-model.ts` actually produces —
/// these tests exist to prove the Flutter renderer reads those fields
/// faithfully, never to invent new server semantics.
DateTime day(int hour, [int minute = 0]) => DateTime(2026, 9, 22, hour, minute);

CalendarBlock knownFinishBlock({
  String key = 'appointment-appt-1',
  String appointmentId = 'appt-1',
  int laneIndex = 0,
  DateTime? startAt,
  DateTime? endAt,
  bool capacityOverflow = false,
  CalendarBlockIssue? issue,
  AppointmentStatus status = AppointmentStatus.CONFIRMED,
}) => CalendarBlock(
  key: key,
  appointmentId: appointmentId,
  laneIndex: laneIndex,
  startAt: startAt ?? day(9),
  endAt: endAt ?? day(10),
  finishKnown: true,
  endsAtDayBoundary: false,
  status: status,
  statusLabel: status.label,
  name: 'Бат 99001122',
  paymentStatus: null,
  paymentStatusLabel: null,
  issue: issue,
  capacityOverflow: capacityOverflow,
  accessibleLabel:
      '09:00–10:00 · Бат 99001122 · ${status.label}'
      '${issue != null ? ' · Анхаарах: ${issue.label}' : ''}'
      '${capacityOverflow ? ' · Салбарын багтаамжаас хэтэрсэн' : ''}',
);

CalendarBlock openEndedBlock({
  String key = 'appointment-appt-2',
  String appointmentId = 'appt-2',
  int laneIndex = 0,
  DateTime? startAt,
  DateTime? endAt,
}) => CalendarBlock(
  key: key,
  appointmentId: appointmentId,
  laneIndex: laneIndex,
  startAt: startAt ?? day(11),
  endAt: endAt ?? day(24), // clipped to the day boundary, uncertain finish
  finishKnown: false,
  endsAtDayBoundary: false,
  status: AppointmentStatus.CONFIRMED,
  statusLabel: AppointmentStatus.CONFIRMED.label,
  name: 'Сараа 99112233',
  paymentStatus: null,
  paymentStatusLabel: null,
  issue: null,
  capacityOverflow: false,
  accessibleLabel: '11:00–тодорхойгүй · Сараа 99112233 · Баталгаажсан',
);

CalendarBlock dayBoundaryBlock({
  String key = 'appointment-appt-3',
  String appointmentId = 'appt-3',
  int laneIndex = 0,
  DateTime? startAt,
  DateTime? endAt,
}) => CalendarBlock(
  key: key,
  appointmentId: appointmentId,
  laneIndex: laneIndex,
  startAt: startAt ?? day(22),
  endAt: endAt ?? DateTime(2026, 9, 23), // exactly midnight
  finishKnown: true,
  endsAtDayBoundary: true,
  status: AppointmentStatus.CONFIRMED,
  statusLabel: AppointmentStatus.CONFIRMED.label,
  name: 'Түмэн 99223344',
  paymentStatus: null,
  paymentStatusLabel: null,
  issue: null,
  capacityOverflow: false,
  accessibleLabel: '22:00–24:00 · Түмэн 99223344 · Баталгаажсан',
);

CalendarDayModel dayModel({
  List<CalendarBlock> blocks = const [],
  List<CalendarLegendEntry> legend = const [],
  int slotCapacity = 1,
  int? laneCount,
  bool? hasCapacityOverflow,
  DateTime? rangeStart,
  DateTime? rangeEnd,
  String dateKey = '2026-09-22',
  String branchId = 'branch-1',
}) {
  final effectiveLaneCount =
      laneCount ??
      (blocks.isEmpty
          ? slotCapacity
          : [
              slotCapacity,
              ...blocks.map((b) => b.laneIndex + 1),
            ].reduce((a, b) => a > b ? a : b));
  return CalendarDayModel(
    branchId: branchId,
    branchName: 'Толгойт салбар',
    dateKey: dateKey,
    rangeStart: rangeStart ?? day(9),
    rangeEnd: rangeEnd ?? day(21),
    slotCapacity: slotCapacity,
    laneCount: effectiveLaneCount,
    hasCapacityOverflow:
        hasCapacityOverflow ?? (effectiveLaneCount > slotCapacity),
    blocks: blocks,
    legend: legend,
  );
}
