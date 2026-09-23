import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/network/dio_error_mapper.dart';
import 'package:dio/dio.dart';

/// Thin transport seam — JSON and Dio stay below the repository contract,
/// exactly like `EmployeesDataSource`. Endpoints mirror
/// `app/api/v1/feedback*` (`P7-B2`).
abstract interface class FeedbackDataSource {
  Future<Object?> list(Map<String, dynamic> query);
  Future<Object?> detail(String id);
  Future<Object?> create(FormData formData);
  Future<Object?> reply(String id, Map<String, dynamic> body);
}

class RemoteFeedbackDataSource implements FeedbackDataSource {
  RemoteFeedbackDataSource({Dio? dio}) : _dio = dio ?? ApiService.instance.dio;

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

  String _id(String id) => Uri.encodeComponent(id);

  @override
  Future<Object?> list(Map<String, dynamic> query) async =>
      (await _request('feedback', 'GET', query: query)).data;

  @override
  Future<Object?> detail(String id) async =>
      (await _request('feedback/${_id(id)}', 'GET')).data;

  @override
  Future<Object?> create(FormData formData) async =>
      (await _request('feedback', 'POST', body: formData)).data;

  @override
  Future<Object?> reply(String id, Map<String, dynamic> body) async =>
      (await _request('feedback/${_id(id)}/replies', 'POST', body: body)).data;
}
