/// Envelope parsing for Services — P4-F1.
///
/// Field-level tolerance lives on the domain models themselves
/// (`service.dart`'s `fromJson` factories never throw for an optional
/// field). This file only unwraps the top-level response envelopes
/// (`{services:[...], pagination}`, `{service:{...}}`, `{units:[...]}`,
/// `{categories:[...]}`, the bare `{succeeded, failed, errors}` bulk result)
/// and enforces the handful of fields the contract treats as structurally
/// required for a response to be usable at all.
///
/// Same shape as `features/vehicles/data/vehicle_dto.dart`; kept as a
/// sibling rather than a shared generic because the required/optional split
/// is contract-specific and a generic unwrapper would hide it.
library;

import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/features/services/domain/service.dart';

typedef JsonMap = Map<String, dynamic>;

JsonMap _map(Object? value, String label) {
  if (value is! Map) throw ServiceParseException('$label буруу байна.');
  return Map<String, dynamic>.from(value);
}

int _requiredInt(JsonMap json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw ServiceParseException('$key буруу байна.');
}

bool _requiredBool(JsonMap json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw ServiceParseException('$key буруу байна.');
}

PaginationMeta _pagination(Object? raw) {
  final json = _map(raw, 'pagination');
  final page = _requiredInt(json, 'page');
  final pageSize = _requiredInt(json, 'pageSize');
  final total = _requiredInt(json, 'total');
  final totalPages = _requiredInt(json, 'totalPages');
  if (page < 1 || pageSize < 1 || total < 0 || totalPages < 0) {
    throw const ServiceParseException('Хуудаслалтын мэдээлэл буруу байна.');
  }
  return PaginationMeta(
    page: page,
    pageSize: pageSize,
    total: total,
    totalPages: totalPages,
    hasPrev: _requiredBool(json, 'hasPrev'),
    hasNext: _requiredBool(json, 'hasNext'),
  );
}

/// `GET /api/v1/services` — `{services:[...], pagination}`.
///
/// A non-map entry in `services` is skipped rather than throwing, matching
/// `VehiclePageDto`; a row whose `id` is missing still throws, because a
/// service with no id cannot be opened, edited or have its stock adjusted
/// and silently dropping it would hide a real server defect behind a short
/// list.
class ServicePageDto {
  const ServicePageDto(this.items, this.pagination);
  final List<Service> items;
  final PaginationMeta pagination;

  factory ServicePageDto.fromJson(Object? raw) {
    final json = _map(raw, 'services response');
    final list = json['services'];
    if (list is! List) {
      throw const ServiceParseException('Үйлчилгээний жагсаалт буруу байна.');
    }
    return ServicePageDto(
      list
          .whereType<Map>()
          .map((item) => Service.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      _pagination(json['pagination']),
    );
  }
}

/// `GET /api/v1/services/[id]`, `PATCH /api/v1/services/[id]` — both
/// `{service:{...}}`. See `service.dart`'s module doc comment for the real
/// shape divergence between the two — this DTO only unwraps the envelope,
/// [Service.fromJson] handles the rest tolerantly either way.
class ServiceDto {
  const ServiceDto(this.value);
  final Service value;

  factory ServiceDto.fromJson(Object? raw) {
    final json = _map(raw, 'service response');
    return ServiceDto(Service.fromJson(_map(json['service'], 'service')));
  }
}

/// `DELETE /api/v1/services/[id]` — `{service:{id, name, type, outcome}}`.
class ServiceDeleteResultDto {
  const ServiceDeleteResultDto(this.value);
  final ServiceDeleteResult value;

  factory ServiceDeleteResultDto.fromJson(Object? raw) {
    final json = _map(raw, 'service delete response');
    return ServiceDeleteResultDto(
      ServiceDeleteResult.fromJson(_map(json['service'], 'service')),
    );
  }
}

/// `POST /api/v1/services/[id]/stock` — `{service:{id, stock}}`.
class ServiceStockResultDto {
  const ServiceStockResultDto(this.value);
  final ServiceStockResult value;

  factory ServiceStockResultDto.fromJson(Object? raw) {
    final json = _map(raw, 'service stock response');
    return ServiceStockResultDto(
      ServiceStockResult.fromJson(_map(json['service'], 'service')),
    );
  }
}

/// `POST /api/v1/services/bulk/category` — a **bare**
/// `{succeeded, failed, errors}`, unlike every other response in this
/// feature: there is no wrapping envelope key at all
/// (`jsonOk(result)` in the route, not `jsonOk({service: result})`).
///
/// Deliberately tolerant of a malformed/non-map payload — unlike the other
/// DTOs in this file, nothing in [BulkCategoryResult] is an id a caller acts
/// on, so there is no equivalent of "cannot be opened" to justify throwing.
/// A malformed response degrades to `succeeded: 0, failed: 0, errors: []`,
/// which a caller displays as "нэг ч амжилтгүй/амжилттай болсонгүй" rather
/// than crashing the sheet that triggered the bulk action.
class BulkCategoryResultDto {
  const BulkCategoryResultDto(this.value);
  final BulkCategoryResult value;

  factory BulkCategoryResultDto.fromJson(Object? raw) => BulkCategoryResultDto(
    raw is Map
        ? BulkCategoryResult.fromJson(Map<String, dynamic>.from(raw))
        : const BulkCategoryResult(),
  );
}

/// `GET /api/v1/units?all=true` — `{units:[...]}`. Read-only (D-164).
class UnitListDto {
  const UnitListDto(this.items);
  final List<Unit> items;

  factory UnitListDto.fromJson(Object? raw) {
    final json = _map(raw, 'units response');
    final list = json['units'];
    if (list is! List) {
      throw const ServiceParseException('Нэгжийн жагсаалт буруу байна.');
    }
    return UnitListDto(
      list
          .whereType<Map>()
          .map((item) => Unit.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
  }
}

/// `GET /api/v1/labor-categories?all=true` — `{categories:[...]}`.
/// Read-only (D-164).
class CategoryListDto {
  const CategoryListDto(this.items);
  final List<Category> items;

  factory CategoryListDto.fromJson(Object? raw) {
    final json = _map(raw, 'categories response');
    final list = json['categories'];
    if (list is! List) {
      throw const ServiceParseException('Ангиллын жагсаалт буруу байна.');
    }
    return CategoryListDto(
      list
          .whereType<Map>()
          .map((item) => Category.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
  }
}
