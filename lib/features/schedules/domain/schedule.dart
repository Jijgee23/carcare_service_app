/// Schedules domain model — P6-F1.
///
/// Measured against `carcare.mn` after `P6-B1`/`P6-B3`:
/// * `app/api/v1/employee-schedules/route.ts` (GET grid),
/// * `app/api/v1/employee-schedules/[userId]/route.ts` (PUT upsert, DELETE
///   reset),
/// * `app/api/v1/employee-schedules/bulk/route.ts` (POST bulk),
/// * `app/api/v1/me/schedule/route.ts` (GET, caller's own month),
/// * `lib/employee-schedule-read.ts` (`EmployeeScheduleRowView`,
///   `ScheduleCellView`, `ScheduleSegmentView`, `ScheduleBranchView`),
/// * `lib/branches.ts`'s `Weekday` — `"SUN"|"MON"|"TUE"|"WED"|"THU"|"FRI"|
///   "SAT"`.
///
/// Each resolved day cell carries its own `source` — the client never
/// re-derives whether a cell came from a date override, a weekly rule, or
/// the branch default (Phase 6 invariant).
library;

class ScheduleParseException implements Exception {
  const ScheduleParseException(this.message);
  final String message;

  @override
  String toString() => 'ScheduleParseException: $message';
}

/// `lib/branches.ts`'s `Weekday` — modelled with a non-throwing [fromWire]
/// (D-156 idiom, same as `ServiceKind`): [unknown] is the tolerant fallback
/// for a value this build does not recognise, never silently aliased to a
/// real day.
enum Weekday {
  sun,
  mon,
  tue,
  wed,
  thu,
  fri,
  sat,
  unknown;

  static Weekday fromWire(Object? value) {
    if (value is! String) return unknown;
    return switch (value) {
      'SUN' => sun,
      'MON' => mon,
      'TUE' => tue,
      'WED' => wed,
      'THU' => thu,
      'FRI' => fri,
      'SAT' => sat,
      _ => unknown,
    };
  }

  String get wire => switch (this) {
    sun => 'SUN',
    mon => 'MON',
    tue => 'TUE',
    wed => 'WED',
    thu => 'THU',
    fri => 'FRI',
    sat => 'SAT',
    unknown => '',
  };

  String get label => switch (this) {
    sun => 'Ням',
    mon => 'Дав',
    tue => 'Мяг',
    wed => 'Лха',
    thu => 'Пүр',
    fri => 'Баа',
    sat => 'Бям',
    unknown => '?',
  };
}

/// Which rule resolved a [ScheduleCell] — a date-specific exception beats a
/// weekly rule, which beats the branch's own default hours. [unknown] is the
/// tolerant fallback; a cell whose source cannot be identified is still
/// rendered, just without a source badge.
enum ScheduleSource {
  exception,
  weekly,
  scheduleDefault,
  unknown;

  static ScheduleSource fromWire(Object? value) => switch (value) {
    'exception' => exception,
    'weekly' => weekly,
    'default' => scheduleDefault,
    _ => unknown,
  };
}

/// The scope a schedule write applies to — `PUT`/`DELETE`/bulk's `scope`
/// field. There is no [unknown] case here: this is a value *this client
/// sends*, not one it must tolerate receiving, so [wire] is total.
enum ScheduleScope {
  date,
  weekday;

  String get wire => this == date ? 'date' : 'weekday';
}

/// One segment within a day cell — `{branchId, branchName, startTime,
/// endTime, customTime}`.
class ScheduleSegment {
  final String? branchId;
  final String? branchName;
  final String? startTime;
  final String? endTime;
  final bool customTime;

  const ScheduleSegment({
    this.branchId,
    this.branchName,
    this.startTime,
    this.endTime,
    this.customTime = false,
  });

  factory ScheduleSegment.fromJson(Map<String, dynamic> j) => ScheduleSegment(
    branchId: _optString(j['branchId']),
    branchName: _optString(j['branchName']),
    startTime: _optString(j['startTime']),
    endTime: _optString(j['endTime']),
    customTime: _optBool(j['customTime']) ?? false,
  );
}

/// One employee×day cell — `{weekday, working, segments, source}`.
class ScheduleCell {
  final Weekday weekday;
  final bool working;
  final List<ScheduleSegment> segments;
  final ScheduleSource source;

  const ScheduleCell({
    this.weekday = Weekday.unknown,
    this.working = false,
    this.segments = const [],
    this.source = ScheduleSource.unknown,
  });

  factory ScheduleCell.fromJson(Map<String, dynamic> j) {
    final segments = j['segments'];
    return ScheduleCell(
      weekday: Weekday.fromWire(j['weekday']),
      working: _optBool(j['working']) ?? false,
      segments: segments is List
          ? segments
                .whereType<Map>()
                .map(
                  (s) => ScheduleSegment.fromJson(Map<String, dynamic>.from(s)),
                )
                .toList(growable: false)
          : const [],
      source: ScheduleSource.fromWire(j['source']),
    );
  }
}

/// One employee row of the grid — `{id, name, roleName, homeBranchId,
/// homeBranchName, cells}`. `id` is structurally required — a row with no id
/// cannot be targeted by a write.
class ScheduleRow {
  final String id;
  final String? name;
  final String? roleName;
  final String? homeBranchId;
  final String? homeBranchName;

  /// Keyed by `YYYY-MM-DD`.
  final Map<String, ScheduleCell> cells;

  const ScheduleRow({
    required this.id,
    this.name,
    this.roleName,
    this.homeBranchId,
    this.homeBranchName,
    this.cells = const {},
  });

  factory ScheduleRow.fromJson(Map<String, dynamic> j) => ScheduleRow(
    id: _reqString(j, 'id'),
    name: _optString(j['name']),
    roleName: _optString(j['roleName']),
    homeBranchId: _optString(j['homeBranchId']),
    homeBranchName: _optString(j['homeBranchName']),
    cells: _cellMap(j['cells']),
  );
}

/// A branch's own week template — `{id, name, openTime, closeTime,
/// schedules:[{weekday, isOpen, openTime, closeTime}]}`.
class ScheduleBranchDaySchedule {
  final Weekday weekday;
  final bool isOpen;
  final String? openTime;
  final String? closeTime;

  const ScheduleBranchDaySchedule({
    this.weekday = Weekday.unknown,
    this.isOpen = false,
    this.openTime,
    this.closeTime,
  });

  factory ScheduleBranchDaySchedule.fromJson(Map<String, dynamic> j) =>
      ScheduleBranchDaySchedule(
        weekday: Weekday.fromWire(j['weekday']),
        isOpen: _optBool(j['isOpen']) ?? false,
        openTime: _optString(j['openTime']),
        closeTime: _optString(j['closeTime']),
      );
}

class ScheduleBranch {
  final String id;
  final String? name;
  final String? openTime;
  final String? closeTime;
  final List<ScheduleBranchDaySchedule> schedules;

  const ScheduleBranch({
    required this.id,
    this.name,
    this.openTime,
    this.closeTime,
    this.schedules = const [],
  });

  factory ScheduleBranch.fromJson(Map<String, dynamic> j) {
    final schedules = j['schedules'];
    return ScheduleBranch(
      id: _reqString(j, 'id'),
      name: _optString(j['name']),
      openTime: _optString(j['openTime']),
      closeTime: _optString(j['closeTime']),
      schedules: schedules is List
          ? schedules
                .whereType<Map>()
                .map(
                  (s) => ScheduleBranchDaySchedule.fromJson(
                    Map<String, dynamic>.from(s),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

/// `GET /api/v1/employee-schedules` — the full grid response.
class ScheduleGrid {
  final String view;
  final List<String> dates;
  final List<ScheduleRow> rows;
  final List<ScheduleBranch> branches;

  /// Keyed by branch id (`""` for unassigned).
  final Map<String, int> countByBranch;
  final int totalEmployees;

  /// `hasPermission(auth.user, "employees.schedule")` — whether this caller
  /// may call the write endpoints. The UI only hides what it cannot do; the
  /// server enforces the guard regardless.
  final bool canEdit;

  const ScheduleGrid({
    this.view = 'week',
    this.dates = const [],
    this.rows = const [],
    this.branches = const [],
    this.countByBranch = const {},
    this.totalEmployees = 0,
    this.canEdit = false,
  });

  factory ScheduleGrid.fromJson(Map<String, dynamic> j) {
    final dates = j['dates'];
    final rows = j['rows'];
    final branches = j['branches'];
    final countByBranch = j['countByBranch'];
    return ScheduleGrid(
      view: _optString(j['view']) ?? 'week',
      dates: dates is List
          ? dates.whereType<String>().toList(growable: false)
          : const [],
      rows: rows is List
          ? rows
                .whereType<Map>()
                .map((r) => ScheduleRow.fromJson(Map<String, dynamic>.from(r)))
                .toList(growable: false)
          : const [],
      branches: branches is List
          ? branches
                .whereType<Map>()
                .map(
                  (b) => ScheduleBranch.fromJson(Map<String, dynamic>.from(b)),
                )
                .toList(growable: false)
          : const [],
      countByBranch: countByBranch is Map
          ? countByBranch.map((k, v) => MapEntry(k.toString(), _optInt(v) ?? 0))
          : const {},
      totalEmployees: _optInt(j['totalEmployees']) ?? 0,
      canEdit: _optBool(j['canEdit']) ?? false,
    );
  }
}

/// `GET /api/v1/me/schedule` — the caller's own resolved month.
class MySchedule {
  final String? month;
  final List<String> dates;

  /// `null` when the caller could not be resolved (should not happen for an
  /// authenticated request, but the route models it as nullable).
  final ScheduleRow? row;

  /// Keyed by `YYYY-MM-DD` — always fully populated across [dates], even
  /// when [row] is `null`.
  final Map<String, ScheduleCell> cells;
  final List<ScheduleBranch> branches;

  const MySchedule({
    this.month,
    this.dates = const [],
    this.row,
    this.cells = const {},
    this.branches = const [],
  });

  factory MySchedule.fromJson(Map<String, dynamic> j) {
    final dates = j['dates'];
    final branches = j['branches'];
    final rowJson = j['row'];
    return MySchedule(
      month: _optString(j['month']),
      dates: dates is List
          ? dates.whereType<String>().toList(growable: false)
          : const [],
      row: rowJson is Map
          ? ScheduleRow.fromJson(Map<String, dynamic>.from(rowJson))
          : null,
      cells: _cellMap(j['cells']),
      branches: branches is List
          ? branches
                .whereType<Map>()
                .map(
                  (b) => ScheduleBranch.fromJson(Map<String, dynamic>.from(b)),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

/// `PUT /api/v1/employee-schedules/[userId]` response — `{message, scope,
/// date?, weekday?}`.
class ScheduleUpsertResult {
  final String? message;
  final ScheduleScope scope;
  final String? date;
  final Weekday? weekday;

  const ScheduleUpsertResult({
    this.message,
    this.scope = ScheduleScope.date,
    this.date,
    this.weekday,
  });

  factory ScheduleUpsertResult.fromJson(Map<String, dynamic> j) =>
      ScheduleUpsertResult(
        message: _optString(j['message']),
        scope: j['scope'] == 'weekday'
            ? ScheduleScope.weekday
            : ScheduleScope.date,
        date: _optString(j['date']),
        weekday: j['weekday'] == null ? null : Weekday.fromWire(j['weekday']),
      );
}

/// `DELETE /api/v1/employee-schedules/[userId]` response — `{scope}`.
class ScheduleResetResult {
  final ScheduleScope scope;
  const ScheduleResetResult({this.scope = ScheduleScope.date});

  factory ScheduleResetResult.fromJson(Map<String, dynamic> j) =>
      ScheduleResetResult(
        scope: j['scope'] == 'weekday'
            ? ScheduleScope.weekday
            : ScheduleScope.date,
      );
}

/// `POST /api/v1/employee-schedules/bulk` response — `{message, applied}`.
class ScheduleBulkResult {
  final String? message;
  final int applied;
  const ScheduleBulkResult({this.message, this.applied = 0});

  factory ScheduleBulkResult.fromJson(Map<String, dynamic> j) =>
      ScheduleBulkResult(
        message: _optString(j['message']),
        applied: _optInt(j['applied']) ?? 0,
      );
}

/// One `userId × (date|weekday)` target for a bulk write — mirrors the
/// route's `targets:[{userId, date?, weekday?}]`, one field populated
/// depending on [ScheduleBulkWrite.scope].
class ScheduleBulkTarget {
  final String userId;
  final String? date;
  final Weekday? weekday;

  const ScheduleBulkTarget({required this.userId, this.date, this.weekday});
}

// ─── Parse helpers ─────────────────────────────────────────────────────────

String _reqString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw ScheduleParseException('$key талбар буруу байна.');
  }
  return value.trim();
}

String? _optString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool? _optBool(Object? value) => value is bool ? value : null;

int? _optInt(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value.trim());
  return null;
}

Map<String, ScheduleCell> _cellMap(Object? value) {
  if (value is! Map) return const {};
  final out = <String, ScheduleCell>{};
  for (final entry in value.entries) {
    if (entry.value is Map) {
      out[entry.key.toString()] = ScheduleCell.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
  }
  return out;
}
