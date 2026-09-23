import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/notifications/domain/notification_item.dart';
import 'package:carcare_service/features/notifications/domain/notifications_repository.dart';

import '../support/completer_queue.dart';

typedef NotificationPage = ({
  List<NotificationItem> items,
  PaginationMeta pagination,
  int unreadCount,
});

NotificationItem seedNotification(
  String id, {
  bool read = false,
  DateTime? createdAt,
}) {
  return NotificationItem(
    id: id,
    type: 'order_completed',
    title: 'Мэдэгдэл $id',
    body: 'Дэлгэрэнгүй $id',
    data: const {},
    readAt: read ? DateTime(2026, 1, 2) : null,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

PaginationMeta _singlePageMeta(int count) => PaginationMeta(
  page: 1,
  pageSize: 20,
  total: count,
  totalPages: 1,
  hasPrev: false,
  hasNext: false,
);

/// Hand-written fake for [NotificationsRepository]. Seeds three
/// notifications, two unread, matching the shape the customer app uses for
/// its own tests.
class FakeNotificationRepository implements NotificationsRepository {
  final List<NotificationItem> _items = [
    seedNotification('n-1', read: false, createdAt: DateTime(2026, 1, 3)),
    seedNotification('n-2', read: false, createdAt: DateTime(2026, 1, 2)),
    seedNotification('n-3', read: true, createdAt: DateTime(2026, 1, 1)),
  ];

  @override
  Future<Result<NotificationPage>> getList({
    int page = 1,
    int pageSize = 20,
  }) async {
    return Ok((
      items: List.unmodifiable(_items),
      pagination: _singlePageMeta(_items.length),
      unreadCount: _items.where((n) => n.readAt == null).length,
    ));
  }

  @override
  Future<void> markRead(String id) async {
    final index = _items.indexWhere((n) => n.id == id);
    if (index == -1) return;
    final n = _items[index];
    _items[index] = NotificationItem(
      id: n.id,
      type: n.type,
      title: n.title,
      body: n.body,
      data: n.data,
      readAt: n.readAt ?? DateTime.now(),
      createdAt: n.createdAt,
    );
  }

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < _items.length; i++) {
      final n = _items[i];
      if (n.readAt != null) continue;
      _items[i] = NotificationItem(
        id: n.id,
        type: n.type,
        title: n.title,
        body: n.body,
        data: n.data,
        readAt: DateTime.now(),
        createdAt: n.createdAt,
      );
    }
  }
}

/// Race-test variant: [getList] never resolves on its own — each call is
/// queued on [queue] (see `test/support/completer_queue.dart`) so a test can
/// choose which of several overlapping `load()` calls "wins" by resolving
/// them out of order.
class RaceNotificationRepository implements NotificationsRepository {
  final queue = CompleterQueue<NotificationPage>();

  @override
  Future<Result<NotificationPage>> getList({int page = 1, int pageSize = 20}) {
    return queue.next().then((page) => Ok(page));
  }

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}
}
