import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/network/dio_error_mapper.dart';
import 'package:dio/dio.dart';

/// Thin transport seam — JSON and Dio stay below the repository contract,
/// exactly like `ServicesDataSource`. Endpoints mirror `app/api/v1/employees*`
/// (`P6-B0`, `P6-B2`).
abstract interface class EmployeesDataSource {
  Future<Object?> list(Map<String, dynamic> query);
  Future<Object?> detail(String id);
  Future<Object?> create(Map<String, dynamic> body);
  Future<Object?> update(String id, Map<String, dynamic> body);
  Future<Object?> delete(String id);
  Future<Object?> toggleActive(String id, Map<String, dynamic> body);
  Future<Object?> resetPassword(String id);
  Future<Object?> bulk(Map<String, dynamic> body);
}

class RemoteEmployeesDataSource implements EmployeesDataSource {
  RemoteEmployeesDataSource({Dio? dio}) : _dio = dio ?? ApiService.instance.dio;

  final Dio _dio;

  /// Error mapping uses the single consolidated `mapDioException` — this
  /// slice adds no mapper of its own.
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
  Future<Object?> list(Map<String, dynamic> query) async =>
      (await _request('employees', 'GET', query: query)).data;

  @override
  Future<Object?> detail(String id) async =>
      (await _request('employees/${Uri.encodeComponent(id)}', 'GET')).data;

  @override
  Future<Object?> create(Map<String, dynamic> body) async =>
      (await _request('employees', 'POST', body: body)).data;

  @override
  Future<Object?> update(String id, Map<String, dynamic> body) async =>
      (await _request(
        'employees/${Uri.encodeComponent(id)}',
        'PATCH',
        body: body,
      )).data;

  @override
  Future<Object?> delete(String id) async =>
      (await _request('employees/${Uri.encodeComponent(id)}', 'DELETE')).data;

  @override
  Future<Object?> toggleActive(String id, Map<String, dynamic> body) async =>
      (await _request(
        'employees/${Uri.encodeComponent(id)}/toggle-active',
        'POST',
        body: body,
      )).data;

  @override
  Future<Object?> resetPassword(String id) async => (await _request(
    'employees/${Uri.encodeComponent(id)}/reset-password',
    'POST',
  )).data;

  @override
  Future<Object?> bulk(Map<String, dynamic> body) async =>
      (await _request('employees/bulk', 'POST', body: body)).data;
}
