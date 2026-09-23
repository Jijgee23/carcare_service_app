import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/network/dio_error_mapper.dart';
import 'package:dio/dio.dart';

/// Thin transport seam — JSON and Dio stay below the repository contract,
/// exactly like `EmployeesDataSource`. Endpoint mirrors `app/api/v1/audit`
/// (`P7-B1`).
abstract interface class AuditDataSource {
  Future<Object?> list(Map<String, dynamic> query);
}

class RemoteAuditDataSource implements AuditDataSource {
  RemoteAuditDataSource({Dio? dio}) : _dio = dio ?? ApiService.instance.dio;

  final Dio _dio;

  @override
  Future<Object?> list(Map<String, dynamic> query) async {
    try {
      return (await _dio.request(
        'audit',
        queryParameters: query,
        options: Options(method: 'GET'),
      )).data;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}
