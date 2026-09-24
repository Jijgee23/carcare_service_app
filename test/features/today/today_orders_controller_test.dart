import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/today/presentation/controllers/today_orders_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'today_fixtures.dart';

TodayOrdersController _controller(TodayFakeRepository repo) =>
    TodayOrdersController(
      repository: repo,
      clock: () => todayNow,
      autoRefresh: null,
    );

TodayBoard _board(TodayOrdersController c) =>
    (c.state as AsyncData<TodayBoard>).value;

void main() {
  test(
    'queries each lane by status without a scheduledAt date filter',
    () async {
      final repo = TodayFakeRepository();
      final c = _controller(repo);
      await c.load();

      expect(repo.queries.map((q) => q.status), [
        OrderStatus.SCHEDULED,
        OrderStatus.IN_PROGRESS,
        OrderStatus.COMPLETED,
      ]);
      // dateFrom/dateTo filter scheduledAt, which would hide walk-ins.
      expect(
        repo.queries.every((q) => q.dateFrom == null && q.dateTo == null),
        isTrue,
      );
      expect(
        repo.queries.every((q) => q.pageSize == TodayOrdersController.pageSize),
        isTrue,
      );
      c.dispose();
    },
  );

  test('waiting keeps walk-ins and overdue, counts later days separately, '
      'and sorts by due time', () async {
    final repo = TodayFakeRepository(
      byStatus: {
        OrderStatus.SCHEDULED: [
          todayOrder('later', scheduledAt: DateTime(2026, 9, 24, 9)),
          todayOrder('noon', scheduledAt: DateTime(2026, 9, 23, 12)),
          todayOrder('walkin', createdAt: DateTime(2026, 9, 23, 9, 30)),
          todayOrder('overdue', scheduledAt: DateTime(2026, 9, 22, 15)),
        ],
      },
    );
    final c = _controller(repo);
    await c.load();

    final board = _board(c);
    expect(board.waiting.map((o) => o.id), ['overdue', 'walkin', 'noon']);
    expect(board.laterCount, 1);
    c.dispose();
  });

  test(
    'completed lane keeps only orders completed today, newest first',
    () async {
      final repo = TodayFakeRepository(
        byStatus: {
          OrderStatus.COMPLETED: [
            todayOrder(
              'y',
              status: OrderStatus.COMPLETED,
              completedAt: DateTime(2026, 9, 22, 18),
            ),
            todayOrder(
              'a',
              status: OrderStatus.COMPLETED,
              completedAt: DateTime(2026, 9, 23, 8),
            ),
            todayOrder(
              'b',
              status: OrderStatus.COMPLETED,
              completedAt: DateTime(2026, 9, 23, 9),
            ),
          ],
        },
      );
      final c = _controller(repo);
      await c.load();
      expect(_board(c).completed.map((o) => o.id), ['b', 'a']);
      c.dispose();
    },
  );

  test('in-progress sorts by expected finish, unknown finish last', () async {
    final repo = TodayFakeRepository(
      byStatus: {
        OrderStatus.IN_PROGRESS: [
          todayOrder('none', status: OrderStatus.IN_PROGRESS),
          todayOrder(
            'late',
            status: OrderStatus.IN_PROGRESS,
            expectedFinishAt: DateTime(2026, 9, 23, 14),
          ),
          todayOrder(
            'soon',
            status: OrderStatus.IN_PROGRESS,
            expectedFinishAt: DateTime(2026, 9, 23, 10, 30),
          ),
        ],
      },
    );
    final c = _controller(repo);
    await c.load();
    expect(_board(c).inProgress.map((o) => o.id), ['soon', 'late', 'none']);
    c.dispose();
  });

  test('flags truncation when a lane has more rows than one page', () async {
    final repo = TodayFakeRepository(
      byStatus: {
        OrderStatus.IN_PROGRESS: [
          todayOrder('x', status: OrderStatus.IN_PROGRESS),
        ],
      },
      totals: {OrderStatus.IN_PROGRESS: 150},
    );
    final c = _controller(repo);
    await c.load();
    expect(_board(c).truncated, isTrue);
    c.dispose();
  });

  test(
    'a failed refresh keeps the last board and reports refreshError',
    () async {
      final repo = TodayFakeRepository(
        byStatus: {
          OrderStatus.SCHEDULED: [todayOrder('a')],
        },
      );
      final c = _controller(repo);
      await c.load();
      final updated = c.lastUpdated;

      repo.failWith = const AppError(ErrorKind.network, 'offline');
      await c.load();

      expect(c.state, isA<AsyncData<TodayBoard>>());
      expect(_board(c).waiting.single.id, 'a');
      expect(c.refreshError, isNotNull);
      expect(c.lastUpdated, updated);
      c.dispose();
    },
  );

  test('a failed first load is an error state', () async {
    final repo = TodayFakeRepository(
      failWith: const AppError(ErrorKind.network, 'offline'),
    );
    final c = _controller(repo);
    await c.load();
    expect(c.state, isA<AsyncError<TodayBoard>>());
    c.dispose();
  });

  test('changeStatus sends the transition with duration and reloads', () async {
    final order = todayOrder('a');
    final repo = TodayFakeRepository(
      byStatus: {
        OrderStatus.SCHEDULED: [order],
      },
    );
    final c = _controller(repo);
    await c.load();
    final before = repo.queries.length;

    final error = await c.changeStatus(
      order,
      OrderStatus.IN_PROGRESS,
      durationMinutes: 45,
    );

    expect(error, isNull);
    expect(repo.updates.single, (
      id: 'a',
      status: OrderStatus.IN_PROGRESS,
      duration: 45,
    ));
    expect(repo.queries.length, before + 3);
    expect(c.isBusy('a'), isFalse);
    c.dispose();
  });
}
