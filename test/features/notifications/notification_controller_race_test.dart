import 'dart:async';

import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_notification_repository.dart';

/// Worked example for `test/support/completer_queue.dart`, applied to real
/// production code rather than an idealised fixture.
///
/// Regression test for the request-generation guard. The second load resolves
/// first; its result must remain visible after the stale first load completes.
void main() {
  test('a stale load() response must not clobber a newer one that resolved '
      'first (request-generation guard)', () async {
    final repo = RaceNotificationRepository();
    final controller = NotificationController(repo: repo);

    // Two overlapping loads: #0 mirrors a slow pull-to-refresh that
    // started first; #1 mirrors a reload triggered right after (e.g. by a
    // mark-read tap) that happens to answer faster.
    unawaited(controller.load());
    final second = controller.load();
    expect(repo.queue.callCount, 2);

    // The SECOND (newer) call's response arrives first...
    repo.queue.resolve(1, (
      items: [seedNotification('newer')],
      pagination: const PaginationMeta(
        page: 1,
        pageSize: 20,
        total: 1,
        totalPages: 1,
        hasPrev: false,
        hasNext: false,
      ),
      unreadCount: 1,
    ));
    await second;

    // ...then the stale first call's response arrives late.
    repo.queue.resolve(0, (
      items: [seedNotification('older')],
      pagination: const PaginationMeta(
        page: 1,
        pageSize: 20,
        total: 1,
        totalPages: 1,
        hasPrev: false,
        hasNext: false,
      ),
      unreadCount: 1,
    ));
    await Future<void>.delayed(Duration.zero);

    // The stale response must not clobber the newer result.
    expect(controller.listState.valueOrNull!.single.id, 'newer');
  });
}
