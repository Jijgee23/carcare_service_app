import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/network/dio_error_mapper.dart';
import 'package:dio/dio.dart';

/// Raw export response — bytes plus the `Content-Disposition` header
/// verbatim, so the repository (not this transport seam) owns filename
/// parsing/fallback policy.
class ReportExportRaw {
  final List<int> bytes;
  final String? contentDisposition;

  const ReportExportRaw({required this.bytes, this.contentDisposition});
}

/// Thin transport seam — JSON and Dio stay below the repository contract,
/// exactly like `EmployeesDataSource`. Endpoints mirror
/// `app/api/v1/reports*` (`P7-B0`).
abstract interface class ReportsDataSource {
  Future<Object?> get(Map<String, dynamic> query);
  Future<ReportExportRaw> export(Map<String, dynamic> query);
}

class RemoteReportsDataSource implements ReportsDataSource {
  RemoteReportsDataSource({Dio? dio}) : _dio = dio ?? ApiService.instance.dio;

  final Dio _dio;

  Future<Response<dynamic>> _request(
    String path, {
    Map<String, dynamic>? query,
    ResponseType? responseType,
  }) async {
    try {
      return await _dio.request(
        path,
        queryParameters: query,
        options: Options(method: 'GET', responseType: responseType),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<Object?> get(Map<String, dynamic> query) async =>
      (await _request('reports', query: query)).data;

  @override
  Future<ReportExportRaw> export(Map<String, dynamic> query) async {
    final response = await _request(
      'reports/export',
      query: query,
      responseType: ResponseType.bytes,
    );
    final data = response.data;
    final bytes = data is List<int> ? data : const <int>[];
    return ReportExportRaw(
      bytes: bytes,
      contentDisposition: response.headers.value('content-disposition'),
    );
  }
}
