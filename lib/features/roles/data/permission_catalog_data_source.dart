import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/network/dio_error_mapper.dart';
import 'package:dio/dio.dart';

/// Thin transport seam for `GET /api/v1/permissions`.
abstract interface class PermissionCatalogDataSource {
  Future<Object?> get();
}

class RemotePermissionCatalogDataSource implements PermissionCatalogDataSource {
  RemotePermissionCatalogDataSource({Dio? dio})
    : _dio = dio ?? ApiService.instance.dio;

  final Dio _dio;

  @override
  Future<Object?> get() async {
    try {
      return (await _dio.get('permissions')).data;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}
