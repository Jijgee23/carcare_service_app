import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/services/data/service_dto.dart';
import 'package:carcare_service/features/services/data/services_data_source.dart';
import 'package:carcare_service/features/services/domain/service.dart';
import 'package:carcare_service/features/services/domain/services_repository.dart';

/// Remote adapter for [ServicesRepository] — P4-F1. JSON and Dio stay below
/// the repository contract; controllers depend on [ServicesRepository] or a
/// fake, matching `RemoteVehiclesRepository`.
class RemoteServicesRepository implements ServicesRepository {
  RemoteServicesRepository({ServicesDataSource? dataSource})
    : _dataSource = dataSource ?? RemoteServicesDataSource();

  final ServicesDataSource _dataSource;

  @override
  Future<Result<PagedResult<Service>>> getServices({
    ServiceListQuery? query,
  }) async {
    final effective = query ?? const ServiceListQuery();
    try {
      final parsed = ServicePageDto.fromJson(
        await _dataSource.list(_listQuery(effective)),
      );
      return Ok(
        PagedResult(items: parsed.items, pagination: parsed.pagination),
      );
    } catch (error) {
      return Err(_error(error, 'Үйлчилгээний жагсаалт ачаалж чадсангүй'));
    }
  }

  @override
  Future<Result<Service>> getService(String serviceId) async {
    try {
      return Ok(ServiceDto.fromJson(await _dataSource.detail(serviceId)).value);
    } catch (error) {
      return Err(_error(error, 'Үйлчилгээний мэдээлэл ачаалж чадсангүй'));
    }
  }

  @override
  Future<Result<Service>> updateService(
    String serviceId, {
    required ServiceKind type,
    required String name,
    String? code,
    String? unitId,
    required String price,
    String? costPrice,
    String? stock,
    String? durationValue,
    String? durationUnitId,
    int? reminderIntervalMonths,
    String? description,
    bool isActive = true,
    required String categoryId,
  }) async {
    try {
      // Whole-record replace (`P4-B1`'s decision) — every editable field is
      // sent every time, including an explicit `null` for an omitted
      // optional one, exactly like `RemoteVehiclesRepository.updateVehicle`.
      // `type` and `stock` are sent (and validated server-side) but the
      // command never persists either — see the repository interface's doc
      // comment.
      return Ok(
        ServiceDto.fromJson(
          await _dataSource.update(serviceId, {
            'type': type.wire,
            'name': name,
            'code': code,
            'unitId': unitId,
            'price': price,
            'costPrice': costPrice,
            'stock': stock,
            'durationValue': durationValue,
            'durationUnitId': durationUnitId,
            'reminderIntervalMonths': reminderIntervalMonths,
            'description': description,
            'isActive': isActive,
            'categoryId': categoryId,
          }),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Үйлчилгээ хадгалж чадсангүй'));
    }
  }

  @override
  Future<Result<ServiceDeleteResult>> deleteService(String serviceId) async {
    try {
      return Ok(
        ServiceDeleteResultDto.fromJson(await _dataSource.delete(serviceId))
            .value,
      );
    } catch (error) {
      return Err(_error(error, 'Үйлчилгээ устгаж чадсангүй'));
    }
  }

  @override
  Future<Result<ServiceStockResult>> adjustStock(
    String serviceId, {
    required StockDirection direction,
    required String amount,
  }) async {
    try {
      return Ok(
        ServiceStockResultDto.fromJson(
          await _dataSource.adjustStock(serviceId, {
            'direction': direction.wire,
            'amount': amount,
          }),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Үлдэгдэл тохируулж чадсангүй'));
    }
  }

  @override
  Future<Result<BulkCategoryResult>> bulkChangeCategory({
    required List<String> serviceIds,
    required String categoryId,
  }) async {
    try {
      return Ok(
        BulkCategoryResultDto.fromJson(
          await _dataSource.bulkChangeCategory({
            'serviceIds': serviceIds,
            'categoryId': categoryId,
          }),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Ангилал сольж чадсангүй'));
    }
  }

  @override
  Future<Result<List<Unit>>> getUnits() async {
    try {
      return Ok(UnitListDto.fromJson(await _dataSource.units()).items);
    } catch (error) {
      return Err(_error(error, 'Нэгжийн жагсаалт ачаалж чадсангүй'));
    }
  }

  @override
  Future<Result<List<Category>>> getCategories() async {
    try {
      return Ok(CategoryListDto.fromJson(await _dataSource.categories()).items);
    } catch (error) {
      return Err(_error(error, 'Ангиллын жагсаалт ачаалж чадсангүй'));
    }
  }
}

/// Builds only the parameters this slice's `ServiceListQuery` allows. The
/// route does not `rejectUnknownParams` (see that class's doc comment), but
/// this map is still the single place that must stay in step with the
/// allow-list this client chooses to send.
Map<String, dynamic> _listQuery(ServiceListQuery query) => {
  'page': query.page,
  'pageSize': query.pageSize,
  if (query.type != null && query.type != ServiceKind.unknown)
    'type': query.type!.wire,
  // Trimmed, and omitted entirely when empty/whitespace-only — an empty `q`
  // is a vacuous parameter on the wire.
  if (query.q != null && query.q!.trim().isNotEmpty) 'q': query.q!.trim(),
  // See `ServiceListQuery`'s doc comment: this is a one-way switch, not a
  // tri-state filter. Only ever sent as the literal string `"false"`.
  if (query.includeInactive) 'isActive': 'false',
};

AppError _error(Object error, String fallback) => switch (error) {
  AppError value => value,
  ServiceParseException value => AppError(ErrorKind.unknown, value.message),
  _ => AppError(ErrorKind.unknown, fallback),
};
