import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/reports/data/report_repository.dart';
import 'package:carcare_service/features/reports/domain/report.dart';
import 'package:carcare_service/features/reports/domain/reports_repository.dart';
import 'package:carcare_service/features/reports/presentation/controllers/report_controller.dart';
import 'package:carcare_service/features/reports/presentation/report_ranges.dart';

import '../../data/fake_reports_repository.dart';

/// Records the last query/export call so range-change and export-range
/// tests can assert on exactly what the controller sent, without editing
/// the shared `FakeReportsRepository` (owned by P7-F1).
class _RecordingReportsRepository extends FakeReportsRepository {
  ReportRangeQuery? lastQuery;
  String? lastExportFrom;
  String? lastExportTo;
  ReportRange? resultRange;

  @override
  Future<Result<ReportResult>> getReport({ReportRangeQuery? query}) async {
    lastQuery = query;
    getCalls++;
    return Ok(
      ReportResult(
        range:
            resultRange ??
            const ReportRange(label: 'Энэ сар', key: 'this-month'),
        data: data,
      ),
    );
  }

  @override
  Future<Result<ReportExportFile>> exportReport({
    required String from,
    required String to,
  }) async {
    lastExportFrom = from;
    lastExportTo = to;
    return super.exportReport(from: from, to: to);
  }
}

void main() {
  group('ReportController', () {
    late _RecordingReportsRepository repo;
    late ReportController controller;
    final now = DateTime(2026, 9, 23);

    setUp(() {
      repo = _RecordingReportsRepository();
      controller = ReportController(repo: repo, now: now);
    });

    tearDown(() => controller.dispose());

    test('starts on this-month bounds', () {
      expect(controller.quickKey, ReportQuickRange.thisMonth);
      expect(controller.from, DateTime(2026, 9, 1));
      expect(controller.to, now);
    });

    test('load populates state and sends the resolved from/to', () async {
      expect(controller.state, isA<AsyncLoading>());
      await controller.load();
      expect(controller.state, isA<AsyncData<ReportResult>>());
      expect(repo.getCalls, 1);
      expect(repo.lastQuery?.from, '2026-09-01');
      expect(repo.lastQuery?.to, '2026-09-23');
    });

    test('setQuickRange switches bounds and reloads', () async {
      await controller.setQuickRange(ReportQuickRange.lastMonth);
      expect(controller.quickKey, ReportQuickRange.lastMonth);
      expect(repo.lastQuery?.from, '2026-08-01');
      expect(repo.lastQuery?.to, '2026-08-31');
    });

    test('setQuickRange ignores custom (no local bounds to compute)', () async {
      await controller.setQuickRange(ReportQuickRange.custom);
      expect(controller.quickKey, ReportQuickRange.thisMonth);
      expect(repo.getCalls, 0);
    });

    test(
      'setCustomRange marks custom and reloads with the given bounds',
      () async {
        await controller.setCustomRange(
          DateTime(2026, 1, 1),
          DateTime(2026, 3, 15),
        );
        expect(controller.quickKey, ReportQuickRange.custom);
        expect(repo.lastQuery?.from, '2026-01-01');
        expect(repo.lastQuery?.to, '2026-03-15');
      },
    );

    test(
      'export prefers the server-resolved range over local bounds',
      () async {
        repo.resultRange = const ReportRange(label: 'Custom', key: 'custom');
        // The server range has null from/to here (edge case) — falls back to
        // the locally-tracked bounds rather than throwing.
        await controller.load();
        final result = await controller.export();
        expect(result, isA<Ok<ReportExportFile>>());
        expect(repo.lastExportFrom, '2026-09-01');
        expect(repo.lastExportTo, '2026-09-23');
        expect(controller.exporting, false);
      },
    );

    test('export uses the resolved range dates when present', () async {
      repo.resultRange = ReportRange(
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 8, 31),
        label: 'Өнгөрсөн сар',
        key: 'last-month',
      );
      await controller.load();
      await controller.export();
      expect(repo.lastExportFrom, '2026-08-01');
      expect(repo.lastExportTo, '2026-08-31');
    });

    test('export happy path returns bytes and filename', () async {
      await controller.load();
      final result = await controller.export();
      switch (result) {
        case Ok(:final value):
          expect(value.bytes, isNotEmpty);
          expect(value.filename, endsWith('.xlsx'));
        case Err():
          fail('expected Ok');
      }
    });

    test('export failure surfaces the error and clears exporting', () async {
      repo.failExport = true;
      await controller.load();
      final result = await controller.export();
      expect(result, isA<Err<ReportExportFile>>());
      expect((result as Err).error, isA<AppError>());
      expect(controller.exporting, false);
    });

    test('load surfaces repository errors as AsyncError', () async {
      final failing = _FailingReportsRepository();
      final failingController = ReportController(repo: failing, now: now);
      await failingController.load();
      expect(failingController.state, isA<AsyncError<ReportResult>>());
      failingController.dispose();
    });
  });
}

class _FailingReportsRepository implements ReportsRepository {
  @override
  Future<Result<ReportResult>> getReport({ReportRangeQuery? query}) async =>
      const Err(AppError(ErrorKind.unknown, 'Тайлан ачаалж чадсангүй'));

  @override
  Future<Result<ReportExportFile>> exportReport({
    required String from,
    required String to,
  }) async => const Err(AppError(ErrorKind.unknown, 'Экспортлож чадсангүй'));
}
