// prefer_initializing_formals is unsatisfiable in this file: the fields are
// private while the constructor parameters are public, and `this._repo` would
// make the named parameter private, which Dart forbids. Suppressed here rather
// than renaming the constructor API to please a lint.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/appointments/domain/appointment.dart';
import 'package:carcare_service/features/appointments/domain/appointments_repository.dart';

/// Presentation controller for the calendar day surface — P2-F3.
///
/// Consumes [AppointmentsRepository.getCalendarDay], the P2-B4 shared
/// day-grid TRUTH model, and derives **no** schedule truth locally: status
/// colour, block title, issue derivation, open-ended/day-boundary handling,
/// capacity overflow and the legend all arrive precomputed on
/// [CalendarDayModel]. This controller only owns branch/date selection,
/// request-generation guarding (matching `OrderListController` /
/// `P0-F7`'s `_loadRequestId` pattern) and mapping repository failures onto
/// [AsyncValue] — the same shape every other feature controller in this
/// programme already uses.
class CalendarController extends ChangeNotifier {
  CalendarController({
    required AppointmentsRepository repo,
    String? branchId,
    DateTime? date,
  }) : _repo = repo,
       _branchId = branchId,
       _date = _dateOnly(date ?? DateTime.now());

  final AppointmentsRepository _repo;
  int _generation = 0;
  bool _disposed = false;

  String? _branchId;
  DateTime _date;

  AsyncValue<CalendarDayModel> state = const AsyncLoading();

  // ─── Month dot-counts (P2-F1b) ────────────────────────────────────────
  //
  // Decoration over the authoritative day model, not a second source of
  // schedule truth: [monthCounts] is only ever read for its dot on the
  // date-nav label. It is fetched from `getMonthCounts` on every *month*
  // change (not every day change within the same month, and not every
  // branch-less state) and guarded by its own generation counter — separate
  // from [_generation], which guards the day-model load — because the two
  // fetches are independent and must not stomp on each other when a day
  // change and a month change race. A failed fetch is swallowed: it must
  // never surface as an error state over the calendar, so on error the
  // previously-known counts (possibly empty) are simply left in place.
  Map<DateTime, int> monthCounts = const {};
  DateTime? _countsMonth;
  String? _countsBranch;
  int _monthGeneration = 0;

  /// Appointment count for [day] per the last successfully loaded month's
  /// counts, or 0 when [day] is absent from the map (never re-derived — the
  /// map already omits zero-count days per the repository contract).
  int countFor(DateTime day) => monthCounts[_dateOnly(day)] ?? 0;

  String? get branchId => _branchId;
  DateTime get date => _date;

  /// Distinguishes "no branch selected" (an "ALL branches" working-branch
  /// selection, or no selection yet) from a real network/server failure so
  /// the screen can render a dedicated prompt rather than an error/retry
  /// view. `GET /appointments/calendar` requires a concrete `branchId` —
  /// unlike the list endpoint, the day grid has no tenant-wide mode.
  static const noBranchError = AppError(
    ErrorKind.unknown,
    'Хуанли харахын тулд ажлын салбар сонгоно уу.',
    code: 'NO_BRANCH_SELECTED',
  );

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Reloads for a different branch (or `null` for "no concrete branch
  /// selected", e.g. the working-branch switcher is set to ALL).
  Future<void> setBranch(String? branchId) {
    _branchId = branchId;
    return load();
  }

  Future<void> setDate(DateTime date) {
    _date = _dateOnly(date);
    return load();
  }

  Future<void> goToPreviousDay() =>
      setDate(_date.subtract(const Duration(days: 1)));

  Future<void> goToNextDay() => setDate(_date.add(const Duration(days: 1)));

  Future<void> goToToday() => setDate(DateTime.now());

  Future<void> load() async {
    final requestGeneration = ++_generation;
    final branchId = _branchId;
    if (branchId == null) {
      state = const AsyncError(noBranchError);
      notifyListeners();
      unawaited(_loadMonthCountsIfNeeded());
      return;
    }
    state = const AsyncLoading();
    notifyListeners();
    // Fired alongside the day-model fetch, not chained after it: the two
    // are independent reads and a slow month-counts fetch must never delay
    // the authoritative day render.
    unawaited(_loadMonthCountsIfNeeded());
    final result = await _repo.getCalendarDay(branchId: branchId, date: _date);
    if (_disposed || requestGeneration != _generation) return;
    state = switch (result) {
      Ok(:final value) => AsyncData(value),
      Err(:final error) => AsyncError(error),
    };
    notifyListeners();
  }

  Future<void> refresh() => load();

  /// Fetches `getMonthCounts` only when the selected month or branch
  /// actually changed since the last fetch — paging within the same month
  /// (day-to-day nav) must not re-fetch on every keystroke of
  /// [goToNextDay]/[goToPreviousDay]. Deliberately fire-and-forget from
  /// [load]: the day model is the authoritative render, dots are decoration,
  /// so this must never gate or block the day load.
  Future<void> _loadMonthCountsIfNeeded() async {
    final branchId = _branchId;
    final monthKey = DateTime(_date.year, _date.month);
    if (branchId == _countsBranch && monthKey == _countsMonth) return;
    _countsBranch = branchId;
    _countsMonth = monthKey;
    final requestGeneration = ++_monthGeneration;

    if (branchId == null) {
      if (_disposed || requestGeneration != _monthGeneration) return;
      monthCounts = const {};
      notifyListeners();
      return;
    }

    final result = await _repo.getMonthCounts(
      branchId: branchId,
      month: monthKey,
    );
    if (_disposed || requestGeneration != _monthGeneration) return;
    switch (result) {
      case Ok(:final value):
        monthCounts = value;
        notifyListeners();
      case Err():
        // Degrade silently — dots are decoration over the calendar's
        // authoritative day model, never a reason to disturb it. Leave
        // whatever counts (possibly none) were already known.
        break;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _monthGeneration++;
    super.dispose();
  }
}
