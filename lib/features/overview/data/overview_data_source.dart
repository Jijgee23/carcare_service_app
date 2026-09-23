import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/network/dio_error_mapper.dart';
import 'package:dio/dio.dart';

/// Thin transport seam — JSON and Dio stay below the repository contract,
/// exactly like `ReportsDataSource`. Endpoint mirrors `app/api/v1/overview`
/// (`P7-B1`).
abstract interface class OverviewDataSource {
  Future<Object?> get(Map<String, dynamic> query);
}

class RemoteOverviewDataSource implements OverviewDataSource {
  RemoteOverviewDataSource({Dio? dio}) : _dio = dio ?? ApiService.instance.dio;

  final Dio _dio;

  @override
  Future<Object?> get(Map<String, dynamic> query) async {
    try {
      return (await _dio.request(
        'overview',
        queryParameters: query,
        options: Options(method: 'GET'),
      )).data;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}
