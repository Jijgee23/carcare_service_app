import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/schedules/domain/schedule.dart';
import 'package:carcare_service/features/schedules/domain/schedules_repository.dart';

/// Hand-written fake for [SchedulesRepository] — P6-F1, for later widget
/// tests (`P6-F4`). Mirrors the server split: reads require nothing beyond
/// [canEdit] being informational only; writes are blocked with `FORBIDDEN`
/// when [callerCanEdit] is false, and with `NOT_FOUND` for a userId this
/// fake does not know about — mirroring `authorizeScheduleTarget`.
class FakeScheduleRepository implements SchedulesRepository {
  FakeScheduleRepository({
    List<ScheduleRow>? seed,
    this.callerCanEdit = true,
    this.currentUserId = 'u-self',
  }) : _rows = [
         ...(seed ?? [seedRow()]),
       ];

  final List<ScheduleRow> _rows;
  final bool callerCanEdit;
  final String currentUserId;

  static ScheduleRow seedRow({
    String id = 'u-1',
    String name = 'Дорж Бат',
    Map<String, ScheduleCell> cells = const {},
  }) => ScheduleRow(id: id, name: name, cells: cells);

  AppError _forbidden() => const AppError(
    ErrorKind.forbidden,
    'Хандах эрх байхгүй',
    statusCode: 403,
    code: 'FORBIDDEN',
  );

  AppError _notFound() => const AppError(
    ErrorKind.notFound,
    'Ажилтан олдсонгүй.',
    statusCode: 404,
    code: 'NOT_FOUND',
  );

  int _indexOf(String userId) => _rows.indexWhere((r) => r.id == userId);

  @override
  Future<Result<ScheduleGrid>> getGrid({ScheduleGridQuery? query}) async => Ok(
    ScheduleGrid(
      view: (query ?? const ScheduleGridQuery()).view,
      dates: const ['2026-09-21'],
      rows: List.unmodifiable(_rows),
      branches: const [],
      countByBranch: const {},
      totalEmployees: _rows.length,
      canEdit: callerCanEdit,
    ),
  );

  @override
  Future<Result<MySchedule>> getMySchedule({String? month}) async {
    final index = _indexOf(currentUserId);
    return Ok(
      MySchedule(
        month: month ?? '2026-09',
        dates: const ['2026-09-21'],
        row: index >= 0 ? _rows[index] : null,
        cells: index >= 0 ? _rows[index].cells : const {},
        branches: const [],
      ),
    );
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
    if (!callerCanEdit) return Err(_forbidden());
    final index = _indexOf(userId);
    if (index < 0) return Err(_notFound());

    final key = scope == ScheduleScope.date
        ? (date ?? '')
        : (weekday?.wire ?? '');
    if (key.isEmpty) {
      return Err(
        const AppError(
          ErrorKind.unknown,
          'Огноо эсвэл гараг буруу байна.',
          statusCode: 400,
          code: 'VALIDATION',
        ),
      );
    }
    final current = _rows[index];
    final nextCells = Map<String, ScheduleCell>.from(current.cells);
    nextCells[scope == ScheduleScope.date
        ? date!
        : '#${weekday!.wire}'] = ScheduleCell(
      weekday: weekday ?? Weekday.unknown,
      working: isWorking,
      source: scope == ScheduleScope.date
          ? ScheduleSource.exception
          : ScheduleSource.weekly,
      segments: segments
          .map(
            (s) => ScheduleSegment(
              branchId: s.branchId,
              startTime: s.startTime,
              endTime: s.endTime,
            ),
          )
          .toList(growable: false),
    );
    _rows[index] = ScheduleRow(
      id: current.id,
      name: current.name,
      roleName: current.roleName,
      homeBranchId: current.homeBranchId,
      homeBranchName: current.homeBranchName,
      cells: nextCells,
    );
    return Ok(
      ScheduleUpsertResult(
        message: 'Хадгалагдлаа.',
        scope: scope,
        date: scope == ScheduleScope.date ? date : null,
        weekday: scope == ScheduleScope.weekday ? weekday : null,
      ),
    );
  }

  @override
  Future<Result<ScheduleResetResult>> reset(
    String userId, {
    required ScheduleScope scope,
    String? date,
    Weekday? weekday,
  }) async {
    if (!callerCanEdit) return Err(_forbidden());
    final index = _indexOf(userId);
    if (index < 0) return Err(_notFound());
    final current = _rows[index];
    final nextCells = Map<String, ScheduleCell>.from(current.cells);
    nextCells.remove(scope == ScheduleScope.date ? date : '#${weekday?.wire}');
    _rows[index] = ScheduleRow(
      id: current.id,
      name: current.name,
      roleName: current.roleName,
      homeBranchId: current.homeBranchId,
      homeBranchName: current.homeBranchName,
      cells: nextCells,
    );
    return Ok(ScheduleResetResult(scope: scope));
  }

  @override
  Future<Result<ScheduleBulkResult>> bulkUpsert({
    required ScheduleScope scope,
    required bool isWorking,
    List<ScheduleSegmentInput> segments = const [],
    required List<ScheduleBulkTarget> targets,
  }) async {
    if (!callerCanEdit) return Err(_forbidden());
    var applied = 0;
    for (final target in targets) {
      final result = await upsert(
        target.userId,
        scope: scope,
        date: target.date,
        weekday: target.weekday,
        isWorking: isWorking,
        segments: segments,
      );
      if (result is Ok) applied++;
    }
    return Ok(
      ScheduleBulkResult(message: '$applied шинэчлэгдлээ.', applied: applied),
    );
  }
}
