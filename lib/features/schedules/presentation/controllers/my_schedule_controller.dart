import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/schedules/data/schedule_repository.dart';
import 'package:carcare_service/features/schedules/domain/schedule.dart';
import 'package:carcare_service/features/schedules/domain/schedules_repository.dart';
import 'package:carcare_service/features/schedules/presentation/schedule_dates.dart';

/// Presentation state for the caller's own read-only month calendar —
/// `GET /api/v1/me/schedule` — P6-F4. No permission is required (every
/// authenticated user may see their own schedule) and there is no edit path
/// here at all — writes only ever go through the grid (`employees.schedule`).
class MyScheduleController extends ChangeNotifier {
  MyScheduleController({SchedulesRepository? repo})
    : _repo = repo ?? RemoteSchedulesRepository();

  final SchedulesRepository _repo;
  int _generation = 0;
  bool _disposed = false;

  AsyncValue<MySchedule> state = const AsyncLoading();
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  Future<void> load() async {
    final requestGeneration = ++_generation;
    state = const AsyncLoading();
    notifyListeners();
    final result = await _repo.getMySchedule(month: yearMonth(month));
    if (_disposed || requestGeneration != _generation) return;
    switch (result) {
      case Ok(:final value):
        state = AsyncData(value);
      case Err(:final error):
        state = AsyncError(error);
    }
    notifyListeners();
  }

  Future<void> refresh() => load();

  void nextMonth() {
    month = addMonths(month, 1);
    load();
  }

  void prevMonth() {
    month = addMonths(month, -1);
    load();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
