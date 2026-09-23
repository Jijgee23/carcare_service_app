import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/audit/domain/audit_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_audit_repository.dart';

void main() {
  test('getAuditLog returns the seeded entry', () async {
    final repo = FakeAuditRepository();
    final result = await repo.getAuditLog();
    final page = (result as Ok).value;
    expect(page.items.single.id, 'a-1');
    expect(repo.getCalls, 1);
  });

  test('filtering by action narrows the result', () async {
    final repo = FakeAuditRepository();
    final result = await repo.getAuditLog(
      query: const AuditListQuery(action: 'CREATE'),
    );
    expect((result as Ok).value.items, isEmpty);
  });
}
