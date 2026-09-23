import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/features/schedules/domain/schedule.dart';
import 'package:carcare_service/features/schedules/presentation/controllers/schedule_edit_controller.dart';

import '../../data/fake_schedule_repository.dart';

void main() {
  group('EditableSegment', () {
    test('isRangeValid requires start strictly before end', () {
      final seg = EditableSegment(startTime: '09:00', endTime: '18:00');
      expect(seg.isRangeValid, isTrue);
      seg.endTime = '09:00';
      expect(seg.isRangeValid, isFalse);
      seg.endTime = '08:00';
      expect(seg.isRangeValid, isFalse);
      seg.endTime = 'nope';
      expect(seg.isRangeValid, isFalse);
    });
  });

  group('ScheduleEditController', () {
    late FakeScheduleRepository repo;

    setUp(() {
      repo = FakeScheduleRepository(
        seed: [FakeScheduleRepository.seedRow(id: 'u-1', name: 'Бат')],
      );
    });

    test('segmentsValid is true when not working, regardless of segments', () {
      final controller = ScheduleEditController(repo: repo, working: false);
      expect(controller.segmentsValid, isTrue);
    });

    test('segmentsValid requires a branch and a valid range when working', () {
      final controller = ScheduleEditController(repo: repo, working: true);
      expect(controller.segmentsValid, isFalse); // no branch picked yet
      controller.updateSegment(0, (s) => s..branchId = 'b-1');
      expect(controller.segmentsValid, isTrue);
    });

    test(
      'submitCell with scope=date calls upsert and reports success',
      () async {
        final controller = ScheduleEditController(repo: repo, working: false);
        final ok = await controller.submitCell(
          userId: 'u-1',
          date: '2026-09-21',
        );
        expect(ok, isTrue);
        expect(controller.error, isNull);
      },
    );

    test('submitCell surfaces a server error (forbidden)', () async {
      final forbiddenRepo = FakeScheduleRepository(
        seed: [FakeScheduleRepository.seedRow(id: 'u-1')],
        callerCanEdit: false,
      );
      final controller = ScheduleEditController(repo: forbiddenRepo);
      final ok = await controller.submitCell(userId: 'u-1', date: '2026-09-21');
      expect(ok, isFalse);
      expect(controller.error, isNotNull);
    });

    test('resetCell clears the cell for the chosen scope', () async {
      final controller = ScheduleEditController(repo: repo, working: true);
      controller.updateSegment(0, (s) => s..branchId = 'b-1');
      await controller.submitCell(userId: 'u-1', date: '2026-09-21');

      final resetController = ScheduleEditController(repo: repo);
      final ok = await resetController.resetCell(
        userId: 'u-1',
        date: '2026-09-21',
      );
      expect(ok, isTrue);
    });

    test(
      'submitBulk applies to every target and returns the applied count',
      () async {
        final multiRepo = FakeScheduleRepository(
          seed: [
            FakeScheduleRepository.seedRow(id: 'u-1'),
            FakeScheduleRepository.seedRow(id: 'u-2'),
          ],
        );
        final controller = ScheduleEditController(
          repo: multiRepo,
          working: false,
        );
        final applied = await controller.submitBulk([
          const ScheduleBulkTarget(userId: 'u-1', date: '2026-09-21'),
          const ScheduleBulkTarget(userId: 'u-2', date: '2026-09-21'),
        ]);
        expect(applied, 2);
      },
    );

    test('submitBulk surfaces failure without a caller who can edit', () async {
      final forbiddenRepo = FakeScheduleRepository(
        seed: [FakeScheduleRepository.seedRow(id: 'u-1')],
        callerCanEdit: false,
      );
      final controller = ScheduleEditController(repo: forbiddenRepo);
      final applied = await controller.submitBulk([
        const ScheduleBulkTarget(userId: 'u-1', date: '2026-09-21'),
      ]);
      expect(applied, isNull);
      expect(controller.error, isNotNull);
    });

    test('addSegment/removeSegment keep at least one row', () {
      final controller = ScheduleEditController(repo: repo);
      expect(controller.segments, hasLength(1));
      controller.removeSegment(0);
      expect(controller.segments, hasLength(1)); // cannot go below one
      controller.addSegment();
      expect(controller.segments, hasLength(2));
      controller.removeSegment(0);
      expect(controller.segments, hasLength(1));
    });
  });
}
