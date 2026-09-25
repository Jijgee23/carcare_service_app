import 'package:carcare_service/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_reports_repository.dart';

void main() {
  test('getReport returns the seeded data and counts calls', () async {
    final repo = FakeReportsRepository();
    final result = await repo.getReport();
    expect((result as Ok).value.data.totalRevenue, 100);
    expect(repo.getCalls, 1);
  });

  test('exportReport builds the fallback filename from from/to', () async {
    final repo = FakeReportsRepository();
    final result = await repo.exportReport(
      from: '2026-09-01',
      to: '2026-09-23',
    );
    expect((result as Ok).value.filename, 'tailan_2026-09-01_2026-09-23.xlsx');
    expect(repo.exportCalls, 1);
  });

  test('exportReport can be made to fail', () async {
    final repo = FakeReportsRepository()..failExport = true;
    final result = await repo.exportReport(
      from: '2026-09-01',
      to: '2026-09-23',
    );
    expect(result, isA<Err>());
  });
}
