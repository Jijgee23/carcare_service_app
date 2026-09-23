import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/notifications/data/notification_dto.dart';
import 'package:carcare_service/features/notifications/data/notifications_data_source.dart';
import 'package:carcare_service/features/notifications/domain/notifications_repository.dart';

/// Remote repository adapter. JSON stays below this boundary and all parse
/// failures become safe [AppError] values for presentation code.
class RemoteNotificationsRepository implements NotificationsRepository {
  RemoteNotificationsRepository({NotificationsDataSource? dataSource})
    : _dataSource = dataSource ?? RemoteNotificationsDataSource();

  final NotificationsDataSource _dataSource;

  @override
  Future<Result<NotificationPage>> getList({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final raw = await _dataSource.fetch(page: page, pageSize: pageSize);
      return Ok(NotificationPageDto.fromJson(raw).toDomain());
    } on AppError catch (error) {
      return Err(error);
    } on NotificationParseException catch (error) {
      return Err(AppError(ErrorKind.unknown, error.message));
    } catch (_) {
      return const Err(
        AppError(ErrorKind.unknown, 'Мэдэгдэл ачаалж чадсангүй'),
      );
    }
  }

  @override
  Future<void> markRead(String id) => _dataSource.markRead(id);

  @override
  Future<void> markAllRead() => _dataSource.markAllRead();
}

/// Singular spelling used by some feature adapters in the customer app.
class RemoteNotificationRepository extends RemoteNotificationsRepository {
  RemoteNotificationRepository({super.dataSource});
}

/// Kept so existing app wiring can migrate without a broad unrelated edit.
/// New presentation code should type dependencies as [NotificationsRepository].
class NotificationRepository extends RemoteNotificationsRepository {
  NotificationRepository({super.dataSource});
}
