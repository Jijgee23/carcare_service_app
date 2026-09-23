import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/notifications/domain/notification_item.dart';

/// The read/write boundary for the notifications feature.
///
/// Presentation code depends on this contract, not on Dio or an API adapter.
/// A cache can be added behind this interface in a later phase without
/// changing controllers or screens. Notifications are intentionally not
/// cached in Phase 0.
typedef NotificationPage = ({
  List<NotificationItem> items,
  PaginationMeta pagination,
  int unreadCount,
});

abstract interface class NotificationsRepository {
  Future<Result<NotificationPage>> getList({int page = 1, int pageSize = 20});

  Future<void> markRead(String id);

  Future<void> markAllRead();
}
