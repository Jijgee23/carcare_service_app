import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/schedules/domain/schedule.dart';
import 'package:carcare_service/features/schedules/domain/schedules_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_schedule_repository.dart';

void main() {
  test('a caller without employees.schedule cannot write', () async {
    final repo = FakeScheduleRepository(callerCanEdit: false);
    final result = await repo.upsert(
      'u-1',
      scope: ScheduleScope.date,
      date: '2026-09-21',
      isWorking: true,
    );
    expect((result as Err).error.code, 'FORBIDDEN');
  });

  test('a target not in this fake is NOT_FOUND', () async {
    final repo = FakeScheduleRepository();
    final result = await repo.upsert(
      'not-a-user',
      scope: ScheduleScope.date,
      date: '2026-09-21',
      isWorking: true,
    );
    expect((result as Err).error.code, 'NOT_FOUND');
  });

  test(
    'a date-scope upsert then shows in the grid with source exception',
    () async {
      final repo = FakeScheduleRepository();
      await repo.upsert(
        'u-1',
        scope: ScheduleScope.date,
        date: '2026-09-21',
        isWorking: true,
        segments: const [ScheduleSegmentInput(branchId: 'b-1')],
      );
      final grid = (await repo.getGrid() as Ok).value;
      final cell = grid.rows.single.cells['2026-09-21']!;
      expect(cell.working, isTrue);
      expect(cell.source, ScheduleSource.exception);
    },
  );

  test(
    'bulkUpsert applies to every resolvable target and skips the rest',
    () async {
      final repo = FakeScheduleRepository(
        seed: [
          FakeScheduleRepository.seedRow(id: 'u-1'),
          FakeScheduleRepository.seedRow(id: 'u-2'),
        ],
      );
      final result = await repo.bulkUpsert(
        scope: ScheduleScope.date,
        isWorking: false,
        targets: const [
          ScheduleBulkTarget(userId: 'u-1', date: '2026-09-21'),
          ScheduleBulkTarget(userId: 'u-2', date: '2026-09-21'),
          ScheduleBulkTarget(userId: 'missing', date: '2026-09-21'),
        ],
      );
      expect((result as Ok).value.applied, 2);
    },
  );

  test('getMySchedule returns only the caller — never another user', () async {
    final repo = FakeScheduleRepository(currentUserId: 'u-1');
    final my = (await repo.getMySchedule() as Ok).value;
    expect(my.row?.id, 'u-1');
  });
}
