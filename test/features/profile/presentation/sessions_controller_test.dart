import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/features/profile/domain/account_session.dart';
import 'package:carcare_service/features/profile/presentation/controllers/sessions_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_account_repository.dart';

/// P8-F3 controller tests. Uses the P8-F1 [FakeAccountRepository]
/// (`test/features/profile/data/fake_account_repository.dart`) rather than
/// a second hand-written fake, matching its own doc comment ("for later
/// screen tests").
void main() {
  AccountSession session({
    required String id,
    AccountSessionSource source = AccountSessionSource.mobile,
    bool current = false,
    AccountSessionStatus status = AccountSessionStatus.active,
    String deviceLabel = 'iPhone 15',
  }) => AccountSession(
    id: id,
    source: source,
    deviceLabel: deviceLabel,
    status: status,
    current: current,
    ip: '10.0.0.1',
    createdAt: DateTime(2026, 9, 1),
    lastActivityAt: DateTime(2026, 9, 20),
  );

  group('SessionsController.load', () {
    test('splits active/ended and reports otherActiveCount', () async {
      final repo = FakeAccountRepository(
        sessions: [
          session(id: 's-cur', current: true),
          session(id: 's-other-1'),
          session(id: 's-other-2'),
          session(id: 's-ended', status: AccountSessionStatus.revoked),
        ],
      );
      final c = SessionsController(repo: repo);
      await c.load();

      expect(c.active.map((s) => s.id), containsAll(['s-cur', 's-other-1', 's-other-2']));
      expect(c.ended.map((s) => s.id), ['s-ended']);
      expect(c.otherActiveCount, 2);
    });

    test('a repository error surfaces as AsyncError, not an exception', () async {
      final repo = FakeAccountRepository(sessions: [session(id: 's-1', current: true)]);
      repo.failNext = const AppError(ErrorKind.server, 'Серверийн алдаа');
      final c = SessionsController(repo: repo);
      await c.load();

      expect(c.activeState, isA<AsyncError<List<AccountSession>>>());
      expect(c.active, isEmpty);
    });
  });

  group('SessionsController.revoke', () {
    test('revoking another device removes it and does not log out', () async {
      final repo = FakeAccountRepository(
        sessions: [session(id: 's-cur', current: true), session(id: 's-other')],
      );
      final c = SessionsController(repo: repo);
      await c.load();

      final ok = await c.revoke(c.active.firstWhere((s) => s.id == 's-other'));

      expect(ok, isTrue);
      expect(c.active.map((s) => s.id), ['s-cur']);
      expect(c.otherActiveCount, 0);
      expect(c.pendingLogout, isFalse);
    });

    test('revoking the current device sets pendingLogout', () async {
      final repo = FakeAccountRepository(sessions: [session(id: 's-cur', current: true)]);
      final c = SessionsController(repo: repo);
      await c.load();

      final ok = await c.revoke(c.active.single);

      expect(ok, isTrue);
      expect(c.pendingLogout, isTrue);
      expect(c.active, isEmpty);
    });

    test('acknowledgeLogout clears the flag once handled', () async {
      final repo = FakeAccountRepository(sessions: [session(id: 's-cur', current: true)]);
      final c = SessionsController(repo: repo);
      await c.load();
      await c.revoke(c.active.single);
      expect(c.pendingLogout, isTrue);

      c.acknowledgeLogout();

      expect(c.pendingLogout, isFalse);
    });

    test('a 404 from a foreign/expired id surfaces as actionError and returns false', () async {
      final repo = FakeAccountRepository(
        sessions: [session(id: 's-cur', current: true), session(id: 's-other')],
      );
      final c = SessionsController(repo: repo);
      await c.load();
      repo.failNext = const AppError(
        ErrorKind.notFound,
        'Олдсонгүй',
        statusCode: 404,
        code: 'NOT_FOUND',
      );

      final ok = await c.revoke(c.active.firstWhere((s) => s.id == 's-other'));

      expect(ok, isFalse);
      expect(c.actionError?.statusCode, 404);
      // Nothing removed from the local list on failure.
      expect(c.active.map((s) => s.id), containsAll(['s-cur', 's-other']));
    });
  });

  group('SessionsController.revokeOthers', () {
    test('clears every non-current active session, never the caller\'s own', () async {
      final repo = FakeAccountRepository(
        sessions: [
          session(id: 's-cur', current: true),
          session(id: 's-o1'),
          session(id: 's-o2', source: AccountSessionSource.web),
        ],
      );
      final c = SessionsController(repo: repo);
      await c.load();

      final ok = await c.revokeOthers();

      expect(ok, isTrue);
      expect(c.active.map((s) => s.id), ['s-cur']);
      expect(c.otherActiveCount, 0);
      expect(c.pendingLogout, isFalse);
    });

    test('a failure sets actionError and leaves the list untouched', () async {
      final repo = FakeAccountRepository(
        sessions: [session(id: 's-cur', current: true), session(id: 's-o1')],
      );
      final c = SessionsController(repo: repo);
      await c.load();
      repo.failNext = const AppError(
        ErrorKind.unknown,
        'Хэт олон хүсэлт',
        statusCode: 429,
        code: 'RATE_LIMITED',
      );

      final ok = await c.revokeOthers();

      expect(ok, isFalse);
      expect(c.actionError?.code, 'RATE_LIMITED');
      expect(c.otherActiveCount, 1);
    });
  });

  group('SessionsController.loadMore', () {
    // FakeAccountRepository.getSessions (P8-F1) always returns the full
    // `ended` list with `hasNext: false` — it does not slice by
    // page/pageSize. This matches its own contract ("active is never
    // paginated"; here it's the fake that doesn't fake pagination either),
    // so loadMore is exercised as a documented no-op against it.
    test('the fake never reports a next page, so loadMore is a no-op', () async {
      final repo = FakeAccountRepository(
        sessions: [
          session(id: 's-cur', current: true),
          session(id: 'e-1', status: AccountSessionStatus.revoked),
          session(id: 'e-2', status: AccountSessionStatus.expired),
        ],
      );
      final c = SessionsController(repo: repo, pageSize: 2);
      await c.load();

      expect(c.ended.length, 2);
      expect(c.hasNext, isFalse);

      await c.loadMore();

      expect(c.ended.length, 2, reason: 'no next page, nothing appended');
      expect(c.loadingMore, isFalse);
    });
  });
}
