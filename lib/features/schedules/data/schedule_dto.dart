/// Envelope parsing for Schedules — P6-F1. Field-level tolerance lives on
/// the domain models (`schedule.dart`); this file only unwraps the
/// top-level response envelopes, which for this feature carry no wrapper
/// key at all — each route's `jsonOk({...})` call IS the model.
library;

import 'package:carcare_service/features/schedules/domain/schedule.dart';

typedef JsonMap = Map<String, dynamic>;

JsonMap _map(Object? value, String label) {
  if (value is! Map) throw ScheduleParseException('$label буруу байна.');
  return Map<String, dynamic>.from(value);
}

/// `GET /api/v1/employee-schedules` — the grid IS the envelope.
class ScheduleGridDto {
  const ScheduleGridDto(this.value);
  final ScheduleGrid value;

  factory ScheduleGridDto.fromJson(Object? raw) => ScheduleGridDto(
    ScheduleGrid.fromJson(_map(raw, 'schedule grid response')),
  );
}

/// `GET /api/v1/me/schedule`.
class MyScheduleDto {
  const MyScheduleDto(this.value);
  final MySchedule value;

  factory MyScheduleDto.fromJson(Object? raw) =>
      MyScheduleDto(MySchedule.fromJson(_map(raw, 'my schedule response')));
}

/// `PUT /api/v1/employee-schedules/[userId]`.
class ScheduleUpsertResultDto {
  const ScheduleUpsertResultDto(this.value);
  final ScheduleUpsertResult value;

  factory ScheduleUpsertResultDto.fromJson(Object? raw) =>
      ScheduleUpsertResultDto(
        ScheduleUpsertResult.fromJson(_map(raw, 'schedule upsert response')),
      );
}

/// `DELETE /api/v1/employee-schedules/[userId]`.
class ScheduleResetResultDto {
  const ScheduleResetResultDto(this.value);
  final ScheduleResetResult value;

  factory ScheduleResetResultDto.fromJson(Object? raw) =>
      ScheduleResetResultDto(
        ScheduleResetResult.fromJson(_map(raw, 'schedule reset response')),
      );
}

/// `POST /api/v1/employee-schedules/bulk`.
class ScheduleBulkResultDto {
  const ScheduleBulkResultDto(this.value);
  final ScheduleBulkResult value;

  factory ScheduleBulkResultDto.fromJson(Object? raw) => ScheduleBulkResultDto(
    ScheduleBulkResult.fromJson(_map(raw, 'schedule bulk response')),
  );
}
