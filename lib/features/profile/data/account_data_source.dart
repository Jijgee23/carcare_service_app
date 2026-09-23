import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/network/dio_error_mapper.dart';
import 'package:dio/dio.dart';

/// Thin transport seam — JSON and Dio stay below the repository contract,
/// exactly like `FeedbackDataSource`/`EmployeesDataSource`. Endpoints mirror
/// `app/api/v1/me*` (`P8-B1`).
abstract interface class AccountDataSource {
  Future<Object?> updateProfile(Map<String, dynamic> body);
  Future<Object?> changePassword(Map<String, dynamic> body);
  Future<Object?> getSessions(Map<String, dynamic> query);
  Future<Object?> revokeSession(String id, {required String source});
  Future<Object?> revokeOtherSessions();
}

class RemoteAccountDataSource implements AccountDataSource {
  RemoteAccountDataSource({Dio? dio}) : _dio = dio ?? ApiService.instance.dio;

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
  Future<Object?> updateProfile(Map<String, dynamic> body) async =>
      (await _request('me', 'PATCH', body: body)).data;

  @override
  Future<Object?> changePassword(Map<String, dynamic> body) async =>
      (await _request('me/password', 'POST', body: body)).data;

  @override
  Future<Object?> getSessions(Map<String, dynamic> query) async =>
      (await _request('me/sessions', 'GET', query: query)).data;

  @override
  Future<Object?> revokeSession(String id, {required String source}) async =>
      (await _request(
        'me/sessions/${Uri.encodeComponent(id)}',
        'DELETE',
        query: {'source': source},
      )).data;

  @override
  Future<Object?> revokeOtherSessions() async =>
      (await _request('me/sessions/revoke-others', 'POST')).data;
}
