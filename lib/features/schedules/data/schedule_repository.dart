import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/schedules/data/schedule_dto.dart';
import 'package:carcare_service/features/schedules/data/schedules_data_source.dart';
import 'package:carcare_service/features/schedules/domain/schedule.dart';
import 'package:carcare_service/features/schedules/domain/schedules_repository.dart';

/// Remote adapter for [SchedulesRepository] — P6-F1.
class RemoteSchedulesRepository implements SchedulesRepository {
  RemoteSchedulesRepository({SchedulesDataSource? dataSource})
    : _dataSource = dataSource ?? RemoteSchedulesDataSource();

  final SchedulesDataSource _dataSource;

  @override
  Future<Result<ScheduleGrid>> getGrid({ScheduleGridQuery? query}) async {
    final effective = query ?? const ScheduleGridQuery();
    try {
      return Ok(
        ScheduleGridDto.fromJson(
          await _dataSource.grid({
            'view': effective.view,
            if (effective.date != null) 'date': effective.date,
            if (effective.branchId != null && effective.branchId!.isNotEmpty)
              'branchId': effective.branchId,
            if (effective.q != null && effective.q!.trim().isNotEmpty)
              'q': effective.q!.trim(),
          }),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Ажлын хувиар ачаалж чадсангүй'));
    }
  }

  @override
  Future<Result<MySchedule>> getMySchedule({String? month}) async {
    try {
      return Ok(
        MyScheduleDto.fromJson(
          await _dataSource.mySchedule({if (month != null) 'month': month}),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Миний ажлын хувиар ачаалж чадсангүй'));
    }
  }

  @override
  Future<Result<ScheduleUpsertResult>> upsert(
    String userId, {
    required ScheduleScope scope,
    String? date,
    Weekday? weekday,
    required bool isWorking,
    List<ScheduleSegmentInput> segments = const [],
  }) async {
    try {
      return Ok(
        ScheduleUpsertResultDto.fromJson(
          await _dataSource.upsert(userId, {
            'scope': scope.wire,
            if (date != null) 'date': date,
            if (weekday != null) 'weekday': weekday.wire,
            'isWorking': isWorking,
            'segments': _segments(segments),
          }),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Ажлын хувиар хадгалж чадсангүй'));
    }
  }

  @override
  Future<Result<ScheduleResetResult>> reset(
    String userId, {
    required ScheduleScope scope,
    String? date,
    Weekday? weekday,
  }) async {
    try {
      return Ok(
        ScheduleResetResultDto.fromJson(
          await _dataSource.reset(userId, {
            'scope': scope.wire,
            if (date != null) 'date': date,
            if (weekday != null) 'weekday': weekday.wire,
          }),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Ажлын хувиарыг арилгаж чадсангүй'));
    }
  }

  @override
  Future<Result<ScheduleBulkResult>> bulkUpsert({
    required ScheduleScope scope,
    required bool isWorking,
    List<ScheduleSegmentInput> segments = const [],
    required List<ScheduleBulkTarget> targets,
  }) async {
    try {
      return Ok(
        ScheduleBulkResultDto.fromJson(
          await _dataSource.bulkUpsert({
            'scope': scope.wire,
            'isWorking': isWorking,
            'segments': _segments(segments),
            'targets': targets
                .map(
                  (t) => {
                    'userId': t.userId,
                    if (t.date != null) 'date': t.date,
                    if (t.weekday != null) 'weekday': t.weekday!.wire,
                  },
                )
                .toList(growable: false),
          }),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Багцаар хадгалж чадсангүй'));
    }
  }
}

List<Map<String, dynamic>> _segments(List<ScheduleSegmentInput> segments) =>
    segments
        .map(
          (s) => {
            'branchId': s.branchId,
            'startTime': s.startTime,
            'endTime': s.endTime,
          },
        )
        .toList(growable: false);

AppError _error(Object error, String fallback) => switch (error) {
  AppError value => value,
  ScheduleParseException value => AppError(ErrorKind.unknown, value.message),
  _ => AppError(ErrorKind.unknown, fallback),
};
