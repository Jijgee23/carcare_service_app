import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/network/dio_error_mapper.dart';
import 'package:dio/dio.dart';

/// Thin transport seam — JSON and Dio stay below the repository contract,
/// exactly like `VehiclesDataSource`/`AppointmentsDataSource`/
/// `OrdersDataSource`. Endpoints mirror `app/api/v1/services*` and the two
/// read-only lookups (`P4-B0a`, `P4-B0b`, `P4-B1`).
abstract interface class ServicesDataSource {
  Future<Object?> list(Map<String, dynamic> query);
  Future<Object?> detail(String id);
  Future<Object?> update(String id, Map<String, dynamic> body);
  Future<Object?> delete(String id);
  Future<Object?> adjustStock(String id, Map<String, dynamic> body);
  Future<Object?> bulkChangeCategory(Map<String, dynamic> body);
  Future<Object?> units();
  Future<Object?> categories();
}

class RemoteServicesDataSource implements ServicesDataSource {
  RemoteServicesDataSource({Dio? dio}) : _dio = dio ?? ApiService.instance.dio;

  final Dio _dio;

  /// Error mapping uses the single consolidated `mapDioException`
  /// (`lib/core/network/dio_error_mapper.dart`, P3-D2). This slice adds no
  /// mapper of its own — a fourth copy is a slice failure. The consolidated
  /// mapper is what keeps `statusCode`, the server's `code` and
  /// `fieldErrors` intact, which this contract relies on to tell
  /// `SERVICE_CODE_CONFLICT` (409), `VALIDATION_FAILED` (422) and a
  /// negative-balance stock rejection (422 on `amount`) apart.
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
      (await _request('services', 'GET', query: query)).data;

  @override
  Future<Object?> detail(String id) async =>
      (await _request('services/${Uri.encodeComponent(id)}', 'GET')).data;

  @override
  Future<Object?> update(String id, Map<String, dynamic> body) async =>
      (await _request(
        'services/${Uri.encodeComponent(id)}',
        'PATCH',
        body: body,
      )).data;

  @override
  Future<Object?> delete(String id) async =>
      (await _request('services/${Uri.encodeComponent(id)}', 'DELETE')).data;

  @override
  Future<Object?> adjustStock(String id, Map<String, dynamic> body) async =>
      (await _request(
        'services/${Uri.encodeComponent(id)}/stock',
        'POST',
        body: body,
      )).data;

  @override
  Future<Object?> bulkChangeCategory(Map<String, dynamic> body) async =>
      (await _request('services/bulk/category', 'POST', body: body)).data;

  @override
  Future<Object?> units() async =>
      (await _request('units', 'GET', query: const {'all': 'true'})).data;

  @override
  Future<Object?> categories() async => (await _request(
    'labor-categories',
    'GET',
    query: const {'all': 'true'},
  )).data;
}
