import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/network/dio_error_mapper.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:dio/dio.dart';

abstract interface class DiagnosticsDataSource {
  Future<Object?> getTemplates();
  Future<Object?> getTemplate(String id);
  Future<Object?> createTemplate(Map<String, dynamic> body);
  Future<Object?> updateTemplate(String id, Map<String, dynamic> body);
  Future<Object?> deleteTemplate(String id);
  Future<Object?> duplicateTemplate(String id);
  Future<Object?> getReports(Map<String, dynamic> query);
  Future<Object?> getReport(String id);
  Future<Object?> createReport(FormData formData);
  Future<Object?> deleteReport(String id);
  Future<Object?> getPdfBytes(String id);
}

class RemoteDiagnosticsDataSource implements DiagnosticsDataSource {
  RemoteDiagnosticsDataSource({Dio? dio})
    : _dio = dio ?? ApiService.instance.dio;
  final Dio _dio;

  Future<Response<dynamic>> _request(
    String path,
    String method, {
    Object? data,
    Map<String, dynamic>? query,
    ResponseType? responseType,
  }) async {
    try {
      return await _dio.request(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method, responseType: responseType),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  String _id(String id) => Uri.encodeComponent(id);
  @override
  Future<Object?> getTemplates() async =>
      (await _request('diagnostics/templates', 'GET')).data;
  @override
  Future<Object?> getTemplate(String id) async =>
      (await _request('diagnostics/templates/${_id(id)}', 'GET')).data;
  @override
  Future<Object?> createTemplate(Map<String, dynamic> body) async =>
      (await _request('diagnostics/templates', 'POST', data: body)).data;
  @override
  Future<Object?> updateTemplate(String id, Map<String, dynamic> body) async =>
      (await _request(
        'diagnostics/templates/${_id(id)}',
        'PATCH',
        data: body,
      )).data;
  @override
  Future<Object?> deleteTemplate(String id) async =>
      (await _request('diagnostics/templates/${_id(id)}', 'DELETE')).data;
  @override
  Future<Object?> duplicateTemplate(String id) async => (await _request(
    'diagnostics/templates/${_id(id)}/duplicate',
    'POST',
  )).data;
  @override
  Future<Object?> getReports(Map<String, dynamic> query) async =>
      (await _request('diagnostics/reports', 'GET', query: query)).data;
  @override
  Future<Object?> getReport(String id) async =>
      (await _request('diagnostics/reports/${_id(id)}', 'GET')).data;
  @override
  Future<Object?> createReport(FormData formData) async =>
      (await _request('diagnostics/reports', 'POST', data: formData)).data;
  @override
  Future<Object?> deleteReport(String id) async =>
      (await _request('diagnostics/reports/${_id(id)}', 'DELETE')).data;
  @override
  Future<Object?> getPdfBytes(String id) async {
    final response = await _request(
      'diagnostics/reports/${_id(id)}/pdf',
      'GET',
      responseType: ResponseType.bytes,
    );
    final data = response.data;
    if (data is List<int>) return data;
    throw const AppError(ErrorKind.unknown, 'PDF хариуны формат буруу байна.');
  }
}
