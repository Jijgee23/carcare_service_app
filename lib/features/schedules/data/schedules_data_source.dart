import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/network/dio_error_mapper.dart';
import 'package:dio/dio.dart';

/// Thin transport seam for `app/api/v1/employee-schedules*` and
/// `app/api/v1/me/schedule` (`P6-B1`, `P6-B3`).
abstract interface class SchedulesDataSource {
  Future<Object?> grid(Map<String, dynamic> query);
  Future<Object?> mySchedule(Map<String, dynamic> query);
  Future<Object?> upsert(String userId, Map<String, dynamic> body);
  Future<Object?> reset(String userId, Map<String, dynamic> query);
  Future<Object?> bulkUpsert(Map<String, dynamic> body);
}

class RemoteSchedulesDataSource implements SchedulesDataSource {
  RemoteSchedulesDataSource({Dio? dio}) : _dio = dio ?? ApiService.instance.dio;

  final Dio _dio;

  Future<Response<dynamic>> _request(
    String path,
    String method, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    try {
      return await _dio.request(
        path,
        queryParameters: query,
        data: body,
        options: Options(method: method),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<Object?> grid(Map<String, dynamic> query) async =>
      (await _request('employee-schedules', 'GET', query: query)).data;

  @override
  Future<Object?> mySchedule(Map<String, dynamic> query) async =>
      (await _request('me/schedule', 'GET', query: query)).data;

  @override
  Future<Object?> upsert(String userId, Map<String, dynamic> body) async =>
      (await _request(
        'employee-schedules/${Uri.encodeComponent(userId)}',
        'PUT',
        body: body,
      )).data;

  @override
  Future<Object?> reset(String userId, Map<String, dynamic> query) async =>
      (await _request(
        'employee-schedules/${Uri.encodeComponent(userId)}',
        'DELETE',
        query: query,
      )).data;

  @override
  Future<Object?> bulkUpsert(Map<String, dynamic> body) async =>
      (await _request('employee-schedules/bulk', 'POST', body: body)).data;
}
