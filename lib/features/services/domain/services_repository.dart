import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/services/domain/service.dart';

/// Server-side filters supported by `GET /api/v1/services`, measured against
/// `app/api/v1/services/route.ts`.
///
/// Unlike `VehicleListQuery`/`CustomerListQuery`, this route does **not**
/// call `rejectUnknownParams` — an unlisted query key is silently ignored,
/// not a 400. This class stays closed anyway, for the same reason those two
/// are: a typo'd filter should fail to compile, not silently do nothing on
/// the wire.
///
/// **`isActive` is a one-way switch, not a tri-state filter — read the route
/// before assuming otherwise.** The handler computes
/// `onlyActive = url.searchParams.get("isActive") !== "false"`, so:
/// * the parameter omitted, or any value other than the literal string
///   `"false"` → only active rows (`isActive: true` is added to the `where`);
/// * the parameter is exactly `"false"` → **no** `isActive` filter at all,
///   meaning both active and archived rows come back.
///
/// There is no way to ask for archived-only rows through this endpoint. This
/// class's [includeInactive] models exactly that binary: `false` (default)
/// sends nothing and gets active-only; `true` sends `isActive=false` and
/// gets everything.
class ServiceListQuery {
  /// `?type=` — omit for every kind. [ServiceKind.unknown] is never sent
  /// (its [ServiceKind.wire] is `''`, which the route would treat as "no
  /// service has this type" rather than "no filter" — there is deliberately
  /// no way to construct that footgun through this class other than passing
  /// `null`).
  final ServiceKind? type;

  /// `?q=` — matches `name`, `code`, `description`, case-insensitively
  /// (`OR` clause in the route). Sent trimmed, omitted entirely when empty.
  final String? q;

  /// See the class doc comment — `false` (default) is "active only",
  /// `true` sends `isActive=false` and returns both active and archived.
  final bool includeInactive;

  final int page;
  final int pageSize;

  const ServiceListQuery({
    this.type,
    this.q,
    this.includeInactive = false,
    this.page = 1,
    this.pageSize = 50,
  });
}

/// One frozen repository contract for the Services feature — P4-F1.
///
/// One named method per backend route, exactly as `VehiclesRepository`/
/// `CustomersRepository` do. [getUnits]/[getCategories] are the two
/// read-only lookups D-164 allows from mobile — neither has a create/edit/
/// delete counterpart here or anywhere else in this feature.
///
/// `PATCH /api/v1/services/[id]` is a **whole-record replace** (`P4-B1`'s
/// explicit decision, matching `PATCH /customers/[id]` and
/// `PATCH /vehicles/[id]`): [updateService] has no partial-update mode and
/// every editable field is a required or explicitly-sent argument — an
/// omitted optional argument is sent as `null` and clears the stored value,
/// same contract as `VehiclesRepository.updateVehicle`.
///
/// Two fields are the documented exceptions to "every field, verbatim" on
/// [updateService], both inherited unchanged from the command it calls:
/// * `type` is accepted (and validated against the widened LABOR/GOODS/
///   DIAGNOSTIC set the mobile route passes) but **never persisted** — it is
///   immutable after creation.
/// * `stock` is accepted and validated (a malformed value on a `GOODS` row
///   still 422s) but is **never written** by this path — it only ever
///   changes through [adjustStock]. Callers must still resend the service's
///   current `stock` string every time, purely to satisfy that validation;
///   see the module doc comment on `Service` for why the response then omits
///   it entirely rather than echoing it back.
///
/// Errors a caller must expect and cannot prevent locally, all surfaced as
/// `Err(AppError)` with `statusCode`/`code`/`fieldErrors` preserved by the
/// shared `mapDioException`:
/// * `403` — every verb requires `services.view`/`.edit`/`.delete` as
///   appropriate; [getUnits]/[getCategories] also require `services.view`
///   (neither resource has its own permission code — `P4-B0b`).
/// * `404 SERVICE_NOT_FOUND` — a service with no row for this tenant is
///   indistinguishable from one that does not exist.
/// * `422 VALIDATION_FAILED` — carries `fieldErrors` keyed by the update
///   input's field names, or by `amount`/`direction` on [adjustStock].
/// * `409 SERVICE_CODE_CONFLICT` — [updateService] against a `code` another
///   service in the tenant already uses. Carries `fieldErrors: {code: …}`.
/// * `400 CATEGORY_REQUIRED` / `404 CATEGORY_NOT_FOUND` /
///   `400 EMPTY_SELECTION` — [bulkChangeCategory] whole-request rejections;
///   these are never reflected in the per-item [BulkCategoryResult].
abstract interface class ServicesRepository {
  /// `GET /api/v1/services`.
  Future<Result<PagedResult<Service>>> getServices({ServiceListQuery? query});

  /// `GET /api/v1/services/[id]` — the only response carrying `updatedAt`
  /// and the order-item usage count.
  Future<Result<Service>> getService(String serviceId);

  /// `PATCH /api/v1/services/[id]` — see the class doc comment for the
  /// whole-record-replace contract and its two accepted-but-discarded
  /// fields.
  Future<Result<Service>> updateService(
    String serviceId, {
    required ServiceKind type,
    required String name,
    String? code,
    String? unitId,
    required String price,
    String? costPrice,

    /// Resent only to satisfy server-side validation; never written. See
    /// the class doc comment.
    String? stock,
    String? durationValue,
    String? durationUnitId,
    int? reminderIntervalMonths,
    String? description,
    bool isActive = true,
    required String categoryId,
  });

  /// `DELETE /api/v1/services/[id]` — archives (`isActive: false`) rather
  /// than removing the row when it has order-item history; see
  /// [ServiceDeleteResult.outcome].
  Future<Result<ServiceDeleteResult>> deleteService(String serviceId);

  /// `POST /api/v1/services/[id]/stock` — directional, `GOODS`-only.
  /// [amount] must be a positive decimal string; the server rejects a
  /// resulting negative balance as a 422 field error rather than clamping to
  /// zero. This client never computes or sends an absolute target stock.
  Future<Result<ServiceStockResult>> adjustStock(
    String serviceId, {
    required StockDirection direction,
    required String amount,
  });

  /// `POST /api/v1/services/bulk/category` — per-item, not all-or-nothing.
  /// A missing/empty [categoryId] is a whole-request rejection (see the
  /// class doc comment); a [serviceIds] entry with no matching row is one
  /// failure inside the returned [BulkCategoryResult], and every other id
  /// still applies.
  Future<Result<BulkCategoryResult>> bulkChangeCategory({
    required List<String> serviceIds,
    required String categoryId,
  });

  /// `GET /api/v1/units?all=true` — read-only (D-164). No corresponding
  /// create/edit/delete method exists on this repository, deliberately.
  Future<Result<List<Unit>>> getUnits();

  /// `GET /api/v1/labor-categories?all=true` — read-only (D-164), same
  /// reasoning as [getUnits].
  Future<Result<List<Category>>> getCategories();
}
