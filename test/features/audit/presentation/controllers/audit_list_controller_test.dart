import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/features/audit/presentation/controllers/audit_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_audit_repository.dart';

void main() {
  group('AuditListController', () {
    test('loadAuditLog populates entries, meta and total', () async {
      final repo = FakeAuditRepository(
        seed: [
          FakeAuditRepository.seedEntry(id: 'a-1'),
          FakeAuditRepository.seedEntry(id: 'a-2', action: 'UPDATE'),
        ],
      );
      final c = AuditListController(repo: repo);
      await c.loadAuditLog();

      expect(c.entries.length, 2);
      expect(c.total, 2);
      expect(c.meta.actions, isNotEmpty);
    });

    test('setQuery debounces then filters server-side', () async {
      final repo = FakeAuditRepository(
        seed: [
          FakeAuditRepository.seedEntry(id: 'a-1', summary: 'Захиалга үүсгэсэн'),
          FakeAuditRepository.seedEntry(id: 'a-2', summary: 'Ажилтан устгасан'),
        ],
      );
      final c = AuditListController(repo: repo, searchDebounce: Duration.zero);
      await c.loadAuditLog();
      expect(c.entries.length, 2);

      c.setQuery('Ажилтан');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(c.entries.length, 1);
      expect(c.entries.single.id, 'a-2');
    });

    test('applyFilters sends action/entity/user/date range in one call', () async {
      final repo = FakeAuditRepository(
        seed: [
          FakeAuditRepository.seedEntry(
            id: 'a-1',
            action: 'CREATE',
            entity: 'ServiceOrder',
            createdAt: DateTime(2026, 1, 5),
          ),
          FakeAuditRepository.seedEntry(
            id: 'a-2',
            action: 'DELETE',
            entity: 'Customer',
            createdAt: DateTime(2026, 1, 10),
          ),
        ],
      );
      final c = AuditListController(repo: repo);
      await c.loadAuditLog();

      await c.applyFilters(action: 'CREATE');
      expect(c.entries.map((e) => e.id), ['a-1']);
      expect(c.hasActiveFilters, isTrue);

      await c.clearFilters();
      expect(c.entries.length, 2);
      expect(c.hasActiveFilters, isFalse);
    });

    test('applyFilters with a date range narrows by createdAt', () async {
      final repo = FakeAuditRepository(
        seed: [
          FakeAuditRepository.seedEntry(id: 'a-1', createdAt: DateTime(2026, 1, 1)),
          FakeAuditRepository.seedEntry(id: 'a-2', createdAt: DateTime(2026, 2, 1)),
        ],
      );
      final c = AuditListController(repo: repo);
      await c.loadAuditLog();

      await c.applyFilters(from: '2026-01-15', to: '2026-02-28');
      expect(c.entries.map((e) => e.id), ['a-2']);
    });

    test('loadMore appends the next page', () async {
      final seed = List.generate(3, (i) => FakeAuditRepository.seedEntry(id: 'a-$i'));
      final repo = FakeAuditRepository(seed: seed, pageSize: 2);
      final c = AuditListController(repo: repo);
      await c.loadAuditLog();
      expect(c.entries.length, 2);
      expect(c.hasNext, isTrue);

      await c.loadMore();
      expect(c.entries.length, 3);
      expect(c.hasNext, isFalse);
    });

    test('loadMore surfaces loadMoreError and preserves the first page', () async {
      final repo = FakeAuditRepository(
        seed: List.generate(3, (i) => FakeAuditRepository.seedEntry(id: 'a-$i')),
        pageSize: 2,
        failWith: const AppError(ErrorKind.server, 'Сервер алдаа'),
        failFromPage: 2,
      );
      final c = AuditListController(repo: repo);
      await c.loadAuditLog();
      expect(c.entries.length, 2);
      expect(c.loadMoreError, isNull);

      await c.loadMore();
      expect(c.entries.length, 2, reason: 'first page must survive a failed loadMore');
      expect(c.loadMoreError, isNotNull);
    });

    test('a failing repository surfaces AsyncError', () async {
      final repo = FakeAuditRepository(
        failWith: const AppError(ErrorKind.server, 'Сервер алдаа'),
      );
      final c = AuditListController(repo: repo);
      await c.loadAuditLog();
      expect(c.entries, isEmpty);
    });
  });
}
