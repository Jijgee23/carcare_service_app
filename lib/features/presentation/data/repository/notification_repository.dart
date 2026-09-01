import 'package:carcare_service/core/api/api_client.dart';
import 'package:carcare_service/core/error/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/models/notification_item.dart';
import 'package:carcare_service/features/models/pagination.dart';

class NotificationRepository {
  Future<Result<({List<NotificationItem> items, PaginationMeta pagination, int unreadCount})>>
      getList({int page = 1, int pageSize = 20}) async {
    try {
      final res = await apiOrThrow(
        Api.get,
        'notifications?page=$page&pageSize=$pageSize',
      );
      final list = (res.data['notifications'] as List)
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final p = PaginationMeta.fromJson(res.data['pagination'] as Map<String, dynamic>);
      final unread = res.data['unreadCount'] as int;
      return Ok((items: list, pagination: p, unreadCount: unread));
    } on AppError catch (e) {
      return Err(e);
    }
  }

  Future<void> markRead(String id) async {
    await apiOrThrow(Api.patch, 'notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await apiOrThrow(Api.post, 'notifications/read-all');
  }
}
