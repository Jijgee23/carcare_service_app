import 'package:carcare_service/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_overview_repository.dart';

void main() {
  test('getOverview returns the seeded overview and counts calls', () async {
    final repo = FakeOverviewRepository();
    final result = await repo.getOverview();
    expect((result as Ok).value.counts.employees, 2);
    expect(repo.getCalls, 1);
  });
}
