import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/services/domain/service.dart';
import 'package:carcare_service/features/services/domain/services_repository.dart';

/// Hand-written fake for [ServicesRepository] — P4-F1.
///
/// Placed under `test/features/services/data/` rather than `test/fakes/`:
/// unlike `P3-F1` (whose Owns line explicitly listed
/// `test/fakes/fake_customer_repository.dart` /
/// `test/fakes/fake_vehicle_repository.dart`), this slice's Owns line is
/// `lib/features/services/{domain,data}/**` and
/// `test/features/services/{domain,data}/**` only — `test/fakes/**` is not
/// in scope here, and file ownership is exclusive
/// (`TENANT_MOBILE_SLICES.md`'s "Rules for every slice" #1). If a later
/// slice wants this fake alongside the other two for a shared
/// `test/fakes/` convention, moving it is that slice's call, not a
/// unilateral one this slice may make.
///
/// Deterministic in-memory seed data; no network. Mirrors the server-side
/// rules this repository binds to, so a payload the real API would reject
/// cannot pass in a test that only exercises this fake:
///
/// * `type` is immutable after creation — accepted by [updateService] but
///   discarded;
/// * `stock` is likewise accepted and validated on a `GOODS` row but never
///   written — only [adjustStock] moves it;
/// * a duplicate `code` is a 409 `SERVICE_CODE_CONFLICT`;
/// * [deleteService] archives (`isActive: false`) when the row has
///   order-item history, else removes it;
/// * [adjustStock] is `GOODS`-only, directional, and rejects a resulting
///   negative balance rather than clamping to zero;
/// * [bulkChangeCategory] is per-item — a missing id is one failure, the
///   rest still apply — except a missing/unknown `categoryId`, which is a
///   whole-request rejection, never a per-item failure;
/// * **the object [updateService] returns mirrors the real `PATCH`
///   response's measured shape**: flat `unitId`/`durationUnitId`/
///   `categoryId`, no nested `unit`/`durationUnit`/`category` refs, no
///   `stock`/`createdAt`/`updatedAt`/`_count`, but `reminderIntervalMonths`
///   present — see `service.dart`'s module doc comment. A controller test
///   built on this fake that assumes the post-edit `Service` still has its
///   nested `category` for display would fail here exactly as it would
///   against the real server.
class FakeServiceRepository implements ServicesRepository {
  FakeServiceRepository({
    List<Service>? seed,
    List<Unit>? units,
    List<Category>? categories,
  }) : _services = [
         ...(seed ?? [seedService()]),
       ],
       _units = [
         ...(units ?? [seedUnit()]),
       ],
       _categories = [
         ...(categories ?? [seedCategory()]),
       ];

  final List<Service> _services;
  final List<Unit> _units;
  final List<Category> _categories;

  /// Call counters, so a controller test can assert a route was hit exactly
  /// once without reaching for a mocking framework.
  int listCalls = 0;

  static Service seedService({
    String id = 'svc-1',
    ServiceKind type = ServiceKind.goods,
    String name = 'Тормозны наклад',
    String? code = 'BRK-001',
    String price = '45000.00',
    String? stock = '12.5',
    bool isActive = true,
    String categoryId = 'cat-1',
    String? unitId = 'unit-1',
    int orderItemCount = 0,
  }) => Service(
    id: id,
    type: type,
    name: name,
    code: code,
    price: price,
    costPrice: '30000.00',
    stock: type == ServiceKind.goods ? stock : null,
    description: 'Урд тормоз',
    isActive: isActive,
    unit: ServiceUnitRef(id: unitId, name: 'ширхэг', code: 'ШИР'),
    unitId: unitId,
    category: ServiceCategoryRef(id: categoryId, name: 'Тормозны систем'),
    categoryId: categoryId,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
    orderItemCount: orderItemCount,
  );

  static Unit seedUnit({String id = 'unit-1'}) =>
      Unit(id: id, name: 'ширхэг', code: 'ШИР');

  static Category seedCategory({String id = 'cat-1'}) =>
      Category(id: id, name: 'Тормозны систем');

  int _indexOf(String id) => _services.indexWhere((s) => s.id == id);

  AppError _notFound() => const AppError(
    ErrorKind.notFound,
    'Үйлчилгээ олдсонгүй.',
    statusCode: 404,
    code: 'SERVICE_NOT_FOUND',
  );

  bool _matchesSearch(Service s, String q) {
    final lower = q.toLowerCase();
    bool ci(String? value) =>
        value != null && value.toLowerCase().contains(lower);
    return ci(s.name) || ci(s.code) || ci(s.description);
  }

  @override
  Future<Result<PagedResult<Service>>> getServices({
    ServiceListQuery? query,
  }) async {
    listCalls++;
    final q = query ?? const ServiceListQuery();
    var rows = _services.toList();

    // Mirrors the route's one-way `isActive` switch exactly: the default is
    // active-only, and `includeInactive` shows both — there is no
    // inactive-only mode.
    if (!q.includeInactive) {
      rows = rows.where((s) => s.isActive).toList();
    }
    if (q.type != null && q.type != ServiceKind.unknown) {
      rows = rows.where((s) => s.type == q.type).toList();
    }
    final term = q.q?.trim();
    if (term != null && term.isNotEmpty) {
      rows = rows.where((s) => _matchesSearch(s, term)).toList();
    }

    final total = rows.length;
    final totalPages = (total / q.pageSize).ceil().clamp(1, 1 << 30);
    final page = q.page.clamp(1, totalPages);
    final skip = (page - 1) * q.pageSize;
    final items = rows.skip(skip).take(q.pageSize).toList(growable: false);

    return Ok(
      PagedResult(
        items: items,
        pagination: PaginationMeta(
          page: page,
          pageSize: q.pageSize,
          total: total,
          totalPages: totalPages,
          hasPrev: page > 1,
          hasNext: page < totalPages,
        ),
      ),
    );
  }

  @override
  Future<Result<Service>> getService(String serviceId) async {
    final index = _indexOf(serviceId);
    if (index < 0) return Err(_notFound());
    return Ok(_services[index]);
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
    final index = _indexOf(serviceId);
    if (index < 0) return Err(_notFound());
    final current = _services[index];

    final fieldErrors = <String, String>{};
    if (name.trim().isEmpty) fieldErrors['name'] = 'Нэр оруулна уу.';
    final priceValue = double.tryParse(price.trim());
    if (priceValue == null || priceValue < 0) {
      fieldErrors['price'] = 'Үнэ буруу.';
    }
    if (categoryId.trim().isEmpty) {
      fieldErrors['categoryId'] = 'Ангилал сонгоно уу.';
    }
    // `stock` is validated when present on a GOODS row, exactly as the real
    // command does, but is never written — see the class doc comment.
    if (current.type == ServiceKind.goods && stock != null) {
      if (double.tryParse(stock.trim()) == null) {
        fieldErrors['stock'] = 'Үлдэгдэл буруу.';
      }
    }
    if (fieldErrors.isNotEmpty) {
      return Err(
        AppError(
          ErrorKind.unknown,
          'Хүсэлт буруу.',
          statusCode: 422,
          code: 'VALIDATION_FAILED',
          fieldErrors: fieldErrors,
        ),
      );
    }

    final normalizedCode = code?.trim().isEmpty ?? true
        ? null
        : code!.trim().toUpperCase();
    if (normalizedCode != null) {
      final conflict = _services.any(
        (s) => s.id != serviceId && s.code == normalizedCode,
      );
      if (conflict) {
        return Err(
          const AppError(
            ErrorKind.unknown,
            'Энэ код өөр үйлчилгээнд ашиглагдсан байна.',
            statusCode: 409,
            code: 'SERVICE_CODE_CONFLICT',
            fieldErrors: {'code': 'Энэ код өөр үйлчилгээнд ашиглагдсан байна.'},
          ),
        );
      }
    }

    // Two distinct objects, mirroring what the real command actually does:
    // `prisma.service.updateMany` never touches `stock`/`type`, so the
    // STORED row keeps its old values for both (plus `createdAt` and the
    // nested refs a fresh `GET` would still show); the RETURNED value is
    // `{id, ...validatedData}` — the command's own input echoed back, never
    // a re-`SELECT` — so it has none of that. See `service.dart`'s module
    // doc comment and the class doc comment above.
    ServiceUnitRef? refOf(List<Unit> pool, String? id) {
      if (id == null) return null;
      for (final u in pool) {
        if (u.id == id) {
          return ServiceUnitRef(id: u.id, name: u.name, code: u.code);
        }
      }
      return null;
    }

    ServiceCategoryRef? categoryRefOf(String? id) {
      if (id == null) return null;
      for (final c in _categories) {
        if (c.id == id) return ServiceCategoryRef(id: c.id, name: c.name);
      }
      return null;
    }

    final stored = Service(
      id: current.id,
      type: current.type, // immutable — the caller's value is discarded.
      name: name.trim(),
      code: normalizedCode,
      price: priceValue!.toString(),
      costPrice: costPrice,
      stock: current.stock, // never written by this path.
      description: description,
      isActive: isActive,
      durationValue: durationValue,
      reminderIntervalMonths: reminderIntervalMonths,
      unit: refOf(_units, unitId),
      durationUnit: refOf(_units, durationUnitId),
      category: categoryRefOf(categoryId),
      unitId: unitId,
      durationUnitId: durationUnitId,
      categoryId: categoryId,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
      orderItemCount: current.orderItemCount,
    );
    _services[index] = stored;

    final echoed = Service(
      id: current.id,
      type: current.type,
      name: stored.name,
      code: stored.code,
      price: stored.price,
      costPrice: costPrice,
      durationValue: durationValue,
      reminderIntervalMonths: reminderIntervalMonths,
      description: description,
      isActive: isActive,
      unitId: unitId,
      durationUnitId: durationUnitId,
      categoryId: categoryId,
    );
    return Ok(echoed);
  }

  @override
  Future<Result<ServiceDeleteResult>> deleteService(String serviceId) async {
    final index = _indexOf(serviceId);
    if (index < 0) return Err(_notFound());
    final current = _services[index];

    if (current.orderItemCount != null && current.orderItemCount! > 0) {
      // Archive: only `isActive` flips. Everything else about the row is
      // untouched — this is a soft-delete, not a re-create.
      _services[index] = Service(
        id: current.id,
        type: current.type,
        name: current.name,
        code: current.code,
        price: current.price,
        costPrice: current.costPrice,
        stock: current.stock,
        description: current.description,
        isActive: false,
        durationValue: current.durationValue,
        reminderIntervalMonths: current.reminderIntervalMonths,
        unit: current.unit,
        durationUnit: current.durationUnit,
        category: current.category,
        unitId: current.unitId,
        durationUnitId: current.durationUnitId,
        categoryId: current.categoryId,
        createdAt: current.createdAt,
        updatedAt: current.updatedAt,
        orderItemCount: current.orderItemCount,
      );
      return Ok(
        ServiceDeleteResult(
          id: current.id,
          name: current.name,
          type: current.type,
          outcome: ServiceDeleteOutcome.archived,
        ),
      );
    }

    _services.removeAt(index);
    return Ok(
      ServiceDeleteResult(
        id: current.id,
        name: current.name,
        type: current.type,
        outcome: ServiceDeleteOutcome.deleted,
      ),
    );
  }

  @override
  Future<Result<ServiceStockResult>> adjustStock(
    String serviceId, {
    required StockDirection direction,
    required String amount,
  }) async {
    final index = _indexOf(serviceId);
    if (index < 0) return Err(_notFound());
    final current = _services[index];
    if (current.type != ServiceKind.goods) return Err(_notFound());

    final amountValue = double.tryParse(amount.trim());
    if (amountValue == null || amountValue <= 0) {
      return Err(
        const AppError(
          ErrorKind.unknown,
          'Хүсэлт буруу.',
          statusCode: 422,
          code: 'VALIDATION_FAILED',
          fieldErrors: {'amount': 'Эерэг тоо оруулна уу.'},
        ),
      );
    }

    final currentStock = double.tryParse(current.stock ?? '0') ?? 0;
    final delta = direction == StockDirection.incoming
        ? amountValue
        : -amountValue;
    final next = currentStock + delta;
    if (next < 0) {
      return Err(
        AppError(
          ErrorKind.unknown,
          'Хүсэлт буруу.',
          statusCode: 422,
          code: 'VALIDATION_FAILED',
          fieldErrors: {
            'amount': 'Үлдэгдэл сөрөг болж байна. Одоо: $currentStock',
          },
        ),
      );
    }

    final nextStock = next.toString();
    _services[index] = Service(
      id: current.id,
      type: current.type,
      name: current.name,
      code: current.code,
      price: current.price,
      costPrice: current.costPrice,
      stock: nextStock,
      description: current.description,
      isActive: current.isActive,
      durationValue: current.durationValue,
      reminderIntervalMonths: current.reminderIntervalMonths,
      unit: current.unit,
      durationUnit: current.durationUnit,
      category: current.category,
      unitId: current.unitId,
      durationUnitId: current.durationUnitId,
      categoryId: current.categoryId,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
      orderItemCount: current.orderItemCount,
    );
    return Ok(ServiceStockResult(id: current.id, stock: nextStock));
  }

  @override
  Future<Result<BulkCategoryResult>> bulkChangeCategory({
    required List<String> serviceIds,
    required String categoryId,
  }) async {
    if (categoryId.trim().isEmpty) {
      return Err(
        const AppError(
          ErrorKind.unknown,
          'Ангилал сонгоно уу.',
          statusCode: 400,
          code: 'CATEGORY_REQUIRED',
        ),
      );
    }
    final category = _categories.where((c) => c.id == categoryId).toList();
    if (category.isEmpty) {
      return Err(
        const AppError(
          ErrorKind.notFound,
          'Сонгосон ангилал олдсонгүй.',
          statusCode: 404,
          code: 'CATEGORY_NOT_FOUND',
        ),
      );
    }
    if (serviceIds.isEmpty) {
      return Err(
        const AppError(
          ErrorKind.unknown,
          'Дор хаяж нэг мөр сонгоно уу.',
          statusCode: 400,
          code: 'EMPTY_SELECTION',
        ),
      );
    }

    var succeeded = 0;
    final errors = <String>[];
    for (final id in serviceIds) {
      final index = _indexOf(id);
      if (index < 0) {
        errors.add('$id: Олдсонгүй.');
        continue;
      }
      final current = _services[index];
      if (current.categoryId != categoryId) {
        final newCategory = category.first;
        _services[index] = Service(
          id: current.id,
          type: current.type,
          name: current.name,
          code: current.code,
          price: current.price,
          costPrice: current.costPrice,
          stock: current.stock,
          description: current.description,
          isActive: current.isActive,
          durationValue: current.durationValue,
          reminderIntervalMonths: current.reminderIntervalMonths,
          unit: current.unit,
          durationUnit: current.durationUnit,
          category: ServiceCategoryRef(
            id: newCategory.id,
            name: newCategory.name,
          ),
          unitId: current.unitId,
          durationUnitId: current.durationUnitId,
          categoryId: categoryId,
          createdAt: current.createdAt,
          updatedAt: current.updatedAt,
          orderItemCount: current.orderItemCount,
        );
      }
      succeeded++;
    }
    return Ok(
      BulkCategoryResult(
        succeeded: succeeded,
        failed: errors.length,
        errors: errors,
      ),
    );
  }

  @override
  Future<Result<List<Unit>>> getUnits() async => Ok(List.unmodifiable(_units));

  @override
  Future<Result<List<Category>>> getCategories() async =>
      Ok(List.unmodifiable(_categories));
}
