import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:dio/dio.dart';

/// Raw transport boundary used by [RemoteNotificationsRepository].
abstract interface class NotificationsDataSource {
  Future<Object?> fetch({required int page, required int pageSize});

  Future<void> markRead(String id);

  Future<void> markAllRead();
}

/// Dio adapter for the existing staff notifications endpoints.
class RemoteNotificationsDataSource implements NotificationsDataSource {
  RemoteNotificationsDataSource({Dio? dio})
    : _dio = dio ?? ApiService.instance.dio;

  final Dio _dio;

  @override
  Future<Object?> fetch({required int page, required int pageSize}) async {
    try {
      final response = await _dio.get(
        'notifications',
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      return response.data;
    } on DioException catch (error) {
      throw _toAppError(error);
    }
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _dio.patch('notifications/${Uri.encodeComponent(id)}/read');
    } on DioException catch (error) {
      throw _toAppError(error);
    }
  }

  @override
  Future<void> markAllRead() async {
    try {
      await _dio.post('notifications/read-all');
    } on DioException catch (error) {
      throw _toAppError(error);
    }
  }
}

AppError _toAppError(DioException error) {
  return switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const AppError(
      ErrorKind.network,
      'Холболт байхгүй',
    ),
    DioExceptionType.badResponse => switch (error.response?.statusCode) {
      401 => const AppError(ErrorKind.unauthorized, 'Нэвтрэх шаардлагатай'),
      403 => const AppError(ErrorKind.forbidden, 'Хандах эрх байхгүй'),
      404 => const AppError(ErrorKind.notFound, 'Олдсонгүй'),
      500 => const AppError(ErrorKind.server, 'Серверийн алдаа'),
      _ => const AppError(ErrorKind.unknown, 'Алдаа гарлаа'),
    },
    _ => AppError(ErrorKind.unknown, error.message ?? 'Алдаа гарлаа'),
  };
}

/// Backwards-compatible singular spelling for callers migrating from the
/// original concrete repository file.
typedef NotificationRemoteDataSource = RemoteNotificationsDataSource;
