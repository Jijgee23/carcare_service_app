import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/schedules/domain/schedule.dart';

/// `GET /api/v1/employee-schedules` query — `view`, `date`, `branchId`, `q`.
class ScheduleGridQuery {
  final String view; // "week" | "month"
  final String? date; // YYYY-MM-DD anchor; default today (server-side)
  final String? branchId;
  final String? q;

  const ScheduleGridQuery({
    this.view = 'week',
    this.date,
    this.branchId,
    this.q,
  });
}

/// One segment argument for a schedule write —
/// `{branchId, startTime, endTime}`.
class ScheduleSegmentInput {
  final String branchId;
  final String? startTime;
  final String? endTime;

  const ScheduleSegmentInput({
    required this.branchId,
    this.startTime,
    this.endTime,
  });
}

/// One frozen repository contract for the Schedules feature — P6-F1.
///
/// Reads (`getGrid`, `getMySchedule`) require only `employees.view`
/// (`getGrid`) or plain auth (`getMySchedule` — always the caller's own
/// data, the `userId` never comes from the client). **Writes** (`upsert`,
/// `reset`, `bulkUpsert`) require `employees.schedule` — a distinct
/// permission from `employees.view`, per the Phase 6 invariants.
/// [ScheduleGrid.canEdit] tells a caller whether it holds that permission
/// without special-casing the code itself.
///
/// A schedule write changes which branch an employee is locked to *today*
/// (`lib/employee-branch-lock.ts`) — this repository only calls the shared
/// server-side write path; there is no client-side branch-lock logic here.
///
/// Errors:
/// * `403 FORBIDDEN` — missing `employees.view`/`.schedule`.
/// * `404 NOT_FOUND` — write target not in this tenant.
/// * `400/422 VALIDATION` — bad scope/date/weekday/segments, carrying
///   `fieldErrors` where the route supplies them.
abstract interface class SchedulesRepository {
  /// `GET /api/v1/employee-schedules`.
  Future<Result<ScheduleGrid>> getGrid({ScheduleGridQuery? query});

  /// `GET /api/v1/me/schedule?month=YYYY-MM`. [month] defaults to the
  /// current month server-side when omitted.
  Future<Result<MySchedule>> getMySchedule({String? month});

  /// `PUT /api/v1/employee-schedules/[userId]` — upsert one employee's one
  /// day (date-scoped exception) or one weekday (weekly rule). Exactly one
  /// of [date]/[weekday] is meaningful, selected by [scope]; the other is
  /// ignored by the server.
  Future<Result<ScheduleUpsertResult>> upsert(
    String userId, {
    required ScheduleScope scope,
    String? date,
    Weekday? weekday,
    required bool isWorking,
    List<ScheduleSegmentInput> segments = const [],
  });

  /// `DELETE /api/v1/employee-schedules/[userId]?scope=&date=|weekday=` —
  /// clears the override for that scope, reverting the cell to whichever
  /// rule resolves next (weekly, then branch default).
  Future<Result<ScheduleResetResult>> reset(
    String userId, {
    required ScheduleScope scope,
    String? date,
    Weekday? weekday,
  });

  /// `POST /api/v1/employee-schedules/bulk` — a rectangular
  /// `userIds × (dates|weekdays)` write, one `isWorking`/[segments] pair
  /// applied to every [targets] entry. The core tenant-filters every target
  /// itself; there is no per-target existence check before the request like
  /// [upsert]/[reset] get from `authorizeScheduleTarget`.
  Future<Result<ScheduleBulkResult>> bulkUpsert({
    required ScheduleScope scope,
    required bool isWorking,
    List<ScheduleSegmentInput> segments = const [],
    required List<ScheduleBulkTarget> targets,
  });
}
