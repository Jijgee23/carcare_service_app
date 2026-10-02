import 'package:carservice_business/core/domain/diagnostic.dart'
    show CustomerSummary;
import 'package:carservice_business/core/errors/app_error.dart';
import 'package:carservice_business/core/network/api_client.dart';
import 'package:carservice_business/core/network/dio_error_mapper.dart';
import 'package:carservice_business/core/utils/result.dart';
import 'package:carservice_business/features/customers/data/customer_dto.dart';
import 'package:carservice_business/features/vehicles/data/vehicle_dto.dart';
import 'package:carservice_business/features/vehicles/domain/vehicle.dart';
import 'package:carservice_business/features/vehicles/domain/vehicle_lookup.dart';
import 'package:dio/dio.dart';

/// Remote adapter for [VehicleLookupRepository]. Errors go through the
/// consolidated `mapDioException`, so `statusCode`/`code`/`fieldErrors`
/// survive (429, 502, 404 `OWNER_NOT_FOUND`, 422 field errors).
class RemoteVehicleLookupRepository implements VehicleLookupRepository {
  RemoteVehicleLookupRepository({Dio? dio})
    : _dio = dio ?? ApiService.instance.dio;

  final Dio _dio;

  Future<Object?> _request(
    String path,
    String method, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    try {
      final res = await _dio.request(
        path,
        queryParameters: query,
        data: body,
        options: Options(method: method),
      );
      return res.data;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<Result<VehicleLookup>> lookupVehicle(String plate) async {
    try {
      final data = await _request(
        'hur/vehicle',
        'GET',
        query: {'plate': plate},
      );
      return Ok(VehicleLookup.fromJson(data));
    } catch (error) {
      return Err(_error(error, 'Мэдээлэл татаж чадсангүй'));
    }
  }

  @override
  Future<Result<CustomerSummary>> registerOwnerFromPlate(String plate) async {
    try {
      final data = await _request(
        'customers/from-plate',
        'POST',
        body: {'plate': plate},
      );
      final c = CustomerEnvelopeDto.fromJson(data).value;
      return Ok(
        CustomerSummary(
          id: c.id,
          fullName: c.fullName,
          phone: c.phone ?? '',
          email: c.email,
        ),
      );
    } catch (error) {
      return Err(_error(error, 'Эзэмшигч бүртгэж чадсангүй'));
    }
  }

  @override
  Future<Result<Vehicle>> createVehicleFromLookup({
    required String plate,
    required String make,
    required String model,
    String? vin,
    int? year,
    int? mileage,
    String? customerId,
  }) async {
    try {
      final data = await _request(
        'vehicles',
        'POST',
        body: {
          'plate': plate,
          'make': make,
          'model': model,
          if (vin != null) 'vin': vin,
          if (year != null) 'year': year,
          if (mileage != null) 'mileage': mileage,
          if (customerId != null) 'customerId': customerId,
          'fromLookup': true,
        },
      );
      return Ok(VehicleDto.fromJson(data).value);
    } catch (error) {
      return Err(_error(error, 'Машин бүртгэж чадсангүй'));
    }
  }
}

AppError _error(Object error, String fallback) =>
    error is AppError ? error : AppError(ErrorKind.unknown, fallback);
