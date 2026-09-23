import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/schedules/data/schedule_repository.dart';
import 'package:carcare_service/features/schedules/domain/schedule.dart';
import 'package:carcare_service/features/schedules/domain/schedules_repository.dart';

/// One segment being edited in the cell/bulk edit sheet — a mutable mirror
/// of [ScheduleSegmentInput] with its own validity check so the sheet can
/// show a "start < end" hint per-row without waiting on the server.
class EditableSegment {
  String? branchId;
  String startTime;
  String endTime;

  EditableSegment({
    this.branchId,
    this.startTime = '09:00',
    this.endTime = '18:00',
  });

  /// `true` when both times parse as `HH:MM` and start is strictly before
  /// end. The server remains authoritative; this only drives an inline hint.
  bool get isRangeValid {
    final s = _minutes(startTime);
    final e = _minutes(endTime);
    return s != null && e != null && s < e;
  }

  static int? _minutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  ScheduleSegmentInput toInput() => ScheduleSegmentInput(
    branchId: branchId ?? '',
    startTime: startTime,
    endTime: endTime,
  );
}

/// Drives both the single-cell edit sheet and the rectangular bulk-edit
/// sheet — P6-F4. The two share every field (scope, working toggle,
/// segments) and every server call shape; only the submit target differs
/// (one `userId` vs a list of [ScheduleBulkTarget]s), so one controller
/// covers both rather than duplicating the form.
class ScheduleEditController extends ChangeNotifier {
  ScheduleEditController({
    SchedulesRepository? repo,
    this.scope = ScheduleScope.date,
    this.working = true,
    List<EditableSegment>? segments,
  }) : _repo = repo ?? RemoteSchedulesRepository(),
       segments = segments ?? [EditableSegment()];

  final SchedulesRepository _repo;

  ScheduleScope scope;
  bool working;
  List<EditableSegment> segments;

  bool submitting = false;
  AppError? error;

  SchedulesRepository get repository => _repo;

  void setScope(ScheduleScope value) {
    scope = value;
    notifyListeners();
  }

  void setWorking(bool value) {
    working = value;
    notifyListeners();
  }

  void addSegment() {
    segments = [...segments, EditableSegment()];
    notifyListeners();
  }

  void removeSegment(int index) {
    if (segments.length <= 1) return;
    segments = [...segments]..removeAt(index);
    notifyListeners();
  }

  void updateSegment(
    int index,
    EditableSegment Function(EditableSegment) update,
  ) {
    segments = [
      for (var i = 0; i < segments.length; i++)
        i == index ? update(segments[i]) : segments[i],
    ];
    notifyListeners();
  }

  bool get segmentsValid =>
      !working ||
      segments.every(
        (s) => s.isRangeValid && (s.branchId?.isNotEmpty ?? false),
      );

  List<ScheduleSegmentInput> get _segmentInputs => working
      ? segments.map((s) => s.toInput()).toList(growable: false)
      : const [];

  /// Single-cell submit — `PUT /employee-schedules/[userId]`.
  Future<bool> submitCell({
    required String userId,
    String? date,
    Weekday? weekday,
  }) async {
    submitting = true;
    error = null;
    notifyListeners();
    final result = await _repo.upsert(
      userId,
      scope: scope,
      date: date,
      weekday: weekday,
      isWorking: working,
      segments: _segmentInputs,
    );
    submitting = false;
    switch (result) {
      case Ok():
        notifyListeners();
        return true;
      case Err(:final error):
        this.error = error;
        notifyListeners();
        return false;
    }
  }

  /// Single-cell reset-to-default — `DELETE /employee-schedules/[userId]`.
  Future<bool> resetCell({
    required String userId,
    String? date,
    Weekday? weekday,
  }) async {
    submitting = true;
    error = null;
    notifyListeners();
    final result = await _repo.reset(
      userId,
      scope: scope,
      date: date,
      weekday: weekday,
    );
    submitting = false;
    switch (result) {
      case Ok():
        notifyListeners();
        return true;
      case Err(:final error):
        this.error = error;
        notifyListeners();
        return false;
    }
  }

  /// Rectangular bulk submit — `POST /employee-schedules/bulk`. Returns the
  /// server's `applied` count on success, `null` on failure (with [error]
  /// set for display).
  Future<int?> submitBulk(List<ScheduleBulkTarget> targets) async {
    submitting = true;
    error = null;
    notifyListeners();
    final result = await _repo.bulkUpsert(
      scope: scope,
      isWorking: working,
      segments: _segmentInputs,
      targets: targets,
    );
    submitting = false;
    switch (result) {
      case Ok(:final value):
        notifyListeners();
        return value.applied;
      case Err(:final error):
        this.error = error;
        notifyListeners();
        return null;
    }
  }
}
