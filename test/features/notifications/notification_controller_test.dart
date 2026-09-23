import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/notifications/domain/notification_item.dart';
import 'package:carcare_service/features/notifications/domain/notifications_repository.dart';
import 'package:carcare_service/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements NotificationsRepository {
  final List<NotificationPage> pages = [];
  int getCalls = 0;
  int markReadCalls = 0;
  int markAllCalls = 0;

  @override
  Future<Result<NotificationPage>> getList({
    int page = 1,
    int pageSize = 20,
  }) async {
    getCalls++;
    return Ok(pages[page - 1]);
  }

  @override
  Future<void> markRead(String id) async => markReadCalls++;

  @override
  Future<void> markAllRead() async => markAllCalls++;
}

NotificationPage _page(String id, {bool unread = true}) => (
  items: [
    NotificationItem(
      id: id,
      type: 'broadcast',
      title: id,
      body: 'body',
      data: const {},
      readAt: unread ? null : DateTime(2026),
      createdAt: DateTime(2026),
    ),
  ],
  pagination: const PaginationMeta(
    page: 1,
    pageSize: 20,
    total: 1,
    totalPages: 1,
    hasPrev: false,
    hasNext: false,
  ),
  unreadCount: unread ? 1 : 0,
);

void main() {
  test('markRead and markAllRead reload instead of mutating locally', () async {
    final repository = _Repository()..pages.add(_page('n-1'));
    final controller = NotificationController(repo: repository);

    await controller.load();
    await controller.markRead('n-1');
    await controller.markAllRead();

    expect(repository.markReadCalls, 1);
    expect(repository.markAllCalls, 1);
    expect(repository.getCalls, 3);
  });

  test('incoming push reloads the authoritative inbox', () async {
    final repository = _Repository()..pages.add(_page('n-1'));
    final controller = NotificationController(repo: repository);

    await controller.handleIncomingPush(
      title: 'push',
      body: 'body',
      data: const {'type': 'broadcast'},
    );

    expect(repository.getCalls, 1);
    expect(controller.listState.valueOrNull!.single.id, 'n-1');
  });

  test('reset invalidates an in-flight load', () async {
    final repository = _Repository()..pages.add(_page('n-1'));
    final controller = NotificationController(repo: repository);
    controller.reset();
    await controller.load();
    expect(controller.listState.valueOrNull!.single.id, 'n-1');
  });
}
