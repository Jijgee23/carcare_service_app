/// Services domain model — P4-F1.
///
/// Measured field-by-field against the `carcare.mn` backend as it stands
/// after `P4-B0a`/`P4-B0b`/`P4-B1`:
///
/// * `app/api/v1/services/route.ts` (GET list, POST create — create is out of
///   this slice's scope, see `lib/core/services/service_catalog_service.dart`),
/// * `app/api/v1/services/[id]/route.ts` (GET / PATCH / DELETE),
/// * `app/api/v1/services/[id]/stock/route.ts` (POST, directional),
/// * `app/api/v1/services/bulk/category/route.ts` (POST, per-item),
/// * `app/api/v1/units/route.ts`, `app/api/v1/labor-categories/route.ts`
///   (`?all=true` read-only lookups — D-164, no mutation from mobile),
/// * `lib/services/service-commands.ts` (`NormalizedServiceUpdateData`,
///   `ServiceUpdateRecord`, `ServiceDeleteResult`, `ServiceStockResult`,
///   `BulkCategoryChangeResult`), which is what `PATCH`/`DELETE`/`stock`/
///   `bulk/category` actually serialise.
///
/// Follows the Customers/Vehicles idiom (`P3-F1`) exactly: per-field
/// tolerance everywhere, and [ServiceParseException] thrown ONLY for a
/// structurally missing `id`. Everything else — an absent `code`, an
/// unparseable `price`, an unknown `type` string, a malformed nested
/// `unit`/`category` block — degrades to `null` or a tolerant default rather
/// than crashing a list or a detail screen.
///
/// Money and quantity fields (`price`, `costPrice`, `stock`, `durationValue`)
/// are Prisma `Decimal` columns server-side, which `NextResponse.json`
/// serialises via `Decimal#toJSON()` as a **string**, never a JS number —
/// exactly like `VehicleHistoryOrder.totalAmount` (P3-F1). They are modelled
/// here as raw decimal strings for the same reason: parsing one into a
/// `double` and rendering it back is how a client silently rounds money.
///
/// **MEASURED SHAPE DIVERGENCE — `PATCH` vs. `GET`, read before wiring a
/// screen in `P4-F2`/`P4-F3` onto this model.** `GET /api/v1/services` and
/// `GET /api/v1/services/[id]` both select the nested `unit`/`durationUnit`/
/// `category` objects (`{id, name, code}` / `{id, name}`). `PATCH
/// /api/v1/services/[id]` returns `updateServiceCommand`'s
/// `NormalizedServiceUpdateData & {id}` instead, which carries **flat**
/// `unitId`/`durationUnitId`/`categoryId` strings and no nested objects at
/// all — the same "PATCH strips the embed" shape `P3-F5` measured for
/// vehicles' `customer` block. [Service] models both: [unit]/[durationUnit]/
/// [category] are the nested refs (`GET`-only, `null` after a `PATCH`), while
/// [unitId]/[durationUnitId]/[categoryId] are always populated when either
/// shape supplies them (falling back to the nested ref's own `id` when the
/// flat key is absent). A screen that renders the picker's *label* after a
/// successful edit must keep its own copy or re-fetch — exactly the vehicle
/// owner-name lesson — because [unit]/[category] will be `null` on the
/// object `updateService` just returned.
///
/// A second, smaller divergence in the same direction: `PATCH`'s response
/// carries [reminderIntervalMonths] (echoed from the validated input) but
/// **neither `GET` route selects that column at all.** This looks like an
/// oversight in the measured backend (an edit form cannot currently
/// pre-fill the reminder interval from a fresh fetch), not something this
/// slice may silently "fix" by inventing a value — flagged here rather than
/// carried silently into `P4-F3`.
///
/// `PATCH` also omits `stock` and `createdAt`/`updatedAt`/`_count` entirely
/// (see [Service] field docs) — this is a whole-record-replace endpoint that
/// echoes the command's own normalized input, not a re-`SELECT` of the row.
library;

/// Typed failure for a structurally malformed Services payload — thrown
/// only when an `id` the contract calls unconditionally required is missing
/// or the wrong type. Everything else degrades; see the module doc comment.
/// Mirrors `VehicleParseException` / `CustomerParseException`.
class ServiceParseException implements Exception {
  const ServiceParseException(this.message);

  final String message;

  @override
  String toString() => 'ServiceParseException: $message';
}

// ─── Kind ──────────────────────────────────────────────────────────────────

/// `Service.type` — `LABOR | GOODS | DIAGNOSTIC` server-side
/// (`lib/services/index.ts`'s `SERVICE_KINDS` plus `DIAGNOSTIC`, which the
/// entry-state audit found `TENANT_MOBILE_PARITY_PLAN.md` had wrongly
/// recorded as `PART`/`FEE`).
///
/// Modelled as an enum with a **non-throwing** [fromWire] rather than the
/// Orders feature's throwing `OrderStatus.fromString` idiom (D-156: "type
/// safety that converts a new server value into a client crash is not
/// safety"). [unknown] is the tolerant fallback for a value this build does
/// not recognise; it is a distinct case from any real kind, never silently
/// aliased to [labor], unlike the pre-existing
/// `lib/core/domain/service_catalog.dart`'s `ServiceKind.values.firstWhere(
/// orElse: () => ServiceKind.LABOR)` — that fallback would misclassify a
/// future kind as `LABOR` and run its GOODS/DIAGNOSTIC-gated validation
/// branches, which is worse than an inert `unknown`.
enum ServiceKind {
  labor,
  goods,
  diagnostic,
  unknown;

  static ServiceKind fromWire(Object? value) {
    if (value is! String) return unknown;
    return switch (value) {
      'LABOR' => labor,
      'GOODS' => goods,
      'DIAGNOSTIC' => diagnostic,
      _ => unknown,
    };
  }

  /// The wire value this kind serialises to, or `''` for [unknown] — sending
  /// an empty `type` is a 400/422 the server already rejects, which is the
  /// correct outcome for a kind this client cannot actually name.
  String get wire => switch (this) {
    labor => 'LABOR',
    goods => 'GOODS',
    diagnostic => 'DIAGNOSTIC',
    unknown => '',
  };

  String get label => switch (this) {
    labor => 'Ажил',
    goods => 'Сэлбэг/Бараа',
    diagnostic => 'Оношилгоо',
    unknown => 'Тодорхойгүй',
  };
}

// ─── Refs ──────────────────────────────────────────────────────────────────

/// The `unit`/`durationUnit` sub-object `GET` embeds: `{id, name, code}`.
/// Read-only from mobile (D-164) — there is no create/edit path for a
/// [ServiceUnitRef] anywhere in this feature.
class ServiceUnitRef {
  final String? id;
  final String? name;
  final String? code;

  const ServiceUnitRef({this.id, this.name, this.code});

  factory ServiceUnitRef.fromJson(Map<String, dynamic> j) => ServiceUnitRef(
    id: _optString(j['id']),
    name: _optString(j['name']),
    code: _optString(j['code']),
  );

  String get display => (code != null && code!.isNotEmpty)
      ? '${name ?? ''} ($code)'
      : (name ?? '');
}

/// The `category` sub-object `GET` embeds: `{id, name}`.
///
/// **The JSON key is literally `category`, not `laborCategory`.** The legacy
/// `lib/core/domain/service_catalog.dart`'s `CatalogService.fromJson` reads
/// `j['laborCategory']` — a field the backend never sends under that name —
/// which is a pre-existing bug in that (soon-to-be-superseded) model. This
/// type is not a port of that bug.
class ServiceCategoryRef {
  final String? id;
  final String? name;

  const ServiceCategoryRef({this.id, this.name});

  factory ServiceCategoryRef.fromJson(Map<String, dynamic> j) =>
      ServiceCategoryRef(id: _optString(j['id']), name: _optString(j['name']));
}

/// `GET /api/v1/units?all=true` — `{units:[{id, name, code, isActive}]}`.
/// A distinct shape from [ServiceUnitRef]: the lookup row carries
/// `isActive`, which the embedded ref on a [Service] does not select.
/// Read-only (D-164).
class Unit {
  final String id;
  final String? name;
  final String? code;
  final bool isActive;

  const Unit({required this.id, this.name, this.code, this.isActive = true});

  factory Unit.fromJson(Map<String, dynamic> j) => Unit(
    id: _reqString(j, 'id'),
    name: _optString(j['name']),
    code: _optString(j['code']),
    isActive: _optBool(j['isActive']) ?? true,
  );
}

/// `GET /api/v1/labor-categories?all=true` —
/// `{categories:[{id, name, description, isActive}]}`. A distinct shape from
/// [ServiceCategoryRef] for the same reason as [Unit]. Read-only (D-164).
/// Despite the route's legacy `labor-categories` path segment, this resource
/// backs every service kind, not just `LABOR` — `P4-B1`'s widened
/// `allowedKinds` on `PATCH` relies on exactly that.
class Category {
  final String id;
  final String? name;
  final String? description;
  final bool isActive;

  const Category({
    required this.id,
    this.name,
    this.description,
    this.isActive = true,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: _reqString(j, 'id'),
    name: _optString(j['name']),
    description: _optString(j['description']),
    isActive: _optBool(j['isActive']) ?? true,
  );
}

// ─── Service ───────────────────────────────────────────────────────────────

/// One tenant service/goods/diagnostic catalogue row.
///
/// A single class covers the three response shapes this slice speaks to —
/// list `GET`, detail `GET`, and the `PATCH` echo — for the same reason
/// [Vehicle] does: they are overlapping subsets, and a second near-identical
/// class would only invite drift. See the module doc comment for the
/// measured `PATCH`-vs-`GET` shape divergence this class's field docs below
/// each note individually.
class Service {
  final String id;
  final ServiceKind type;
  final String? name;
  final String? code;

  /// Raw decimal string. Never `null` on a genuine row, but modelled
  /// nullable per this slice's tolerance rule — a malformed `price` degrades
  /// rather than throwing.
  final String? price;
  final String? costPrice;

  /// `null` on every non-`GOODS` row, and always absent from the `PATCH`
  /// response regardless of kind (see the module doc comment — `stock` is
  /// validated but never persisted or echoed by that endpoint).
  final String? stock;
  final String? description;

  /// Defaults to `true` when absent/malformed — the permissive value,
  /// matching `lib/core/domain/service_catalog.dart`'s existing convention
  /// for this same field (`isActive as bool? ?? true`). A missing flag
  /// hiding an otherwise-active service is worse than the reverse.
  final bool isActive;

  final String? durationValue;

  /// Present ONLY on the `PATCH` response — see the module doc comment's
  /// second divergence. Always `null` from either `GET` route today.
  final int? reminderIntervalMonths;

  /// Nested ref, `GET`-only. `null` after `PATCH` — see [unitId].
  final ServiceUnitRef? unit;

  /// Nested ref, `GET`-only. `null` after `PATCH` — see [durationUnitId].
  final ServiceUnitRef? durationUnit;

  /// Nested ref, `GET`-only. `null` after `PATCH` — see [categoryId].
  final ServiceCategoryRef? category;

  /// Populated from either shape: the nested ref's `id` on a `GET` response,
  /// or the flat `unitId` key `PATCH` sends instead. Prefer this over
  /// `unit?.id` when only the id is needed (e.g. re-submitting an edit),
  /// since it survives both shapes.
  final String? unitId;
  final String? durationUnitId;
  final String? categoryId;

  /// `GET`-only; `null` on `PATCH`.
  final DateTime? createdAt;

  /// Detail-`GET`-only (`GET /api/v1/services/[id]`); `null` on the list
  /// route and on `PATCH`.
  final DateTime? updatedAt;

  /// `_count.items` — detail-`GET`-only. `null` everywhere else, including
  /// the list route (which never selects `_count`).
  final int? orderItemCount;

  const Service({
    required this.id,
    this.type = ServiceKind.unknown,
    this.name,
    this.code,
    this.price,
    this.costPrice,
    this.stock,
    this.description,
    this.isActive = true,
    this.durationValue,
    this.reminderIntervalMonths,
    this.unit,
    this.durationUnit,
    this.category,
    this.unitId,
    this.durationUnitId,
    this.categoryId,
    this.createdAt,
    this.updatedAt,
    this.orderItemCount,
  });

  factory Service.fromJson(Map<String, dynamic> j) {
    final unit = _optMap(j['unit']);
    final durationUnit = _optMap(j['durationUnit']);
    final category = _optMap(j['category']);
    final count = _optMap(j['_count']);
    final unitRef = unit == null ? null : ServiceUnitRef.fromJson(unit);
    final durationUnitRef = durationUnit == null
        ? null
        : ServiceUnitRef.fromJson(durationUnit);
    final categoryRef = category == null
        ? null
        : ServiceCategoryRef.fromJson(category);
    return Service(
      id: _reqString(j, 'id'),
      type: ServiceKind.fromWire(j['type']),
      name: _optString(j['name']),
      code: _optString(j['code']),
      price: _optDecimalString(j['price']),
      costPrice: _optDecimalString(j['costPrice']),
      stock: _optDecimalString(j['stock']),
      description: _optString(j['description']),
      isActive: _optBool(j['isActive']) ?? true,
      durationValue: _optDecimalString(j['durationValue']),
      reminderIntervalMonths: _optInt(j['reminderIntervalMonths']),
      unit: unitRef,
      durationUnit: durationUnitRef,
      category: categoryRef,
      // Flat key wins when both are present (the two shapes never actually
      // overlap on the wire, but a nested ref's own id is the fallback so a
      // future response that sent both would not silently lose the value).
      unitId: _optString(j['unitId']) ?? unitRef?.id,
      durationUnitId: _optString(j['durationUnitId']) ?? durationUnitRef?.id,
      categoryId: _optString(j['categoryId']) ?? categoryRef?.id,
      createdAt: _optDate(j['createdAt']),
      updatedAt: _optDate(j['updatedAt']),
      orderItemCount: _optInt(count?['items']),
    );
  }

  /// `"CODE · Name"`, or just the name/code alone when the other is absent,
  /// or a placeholder when both are — never empty, so a list row always
  /// renders something.
  String get displayName {
    final hasCode = code != null && code!.isNotEmpty;
    final hasName = name != null && name!.isNotEmpty;
    if (hasCode && hasName) return '$code · $name';
    if (hasName) return name!;
    if (hasCode) return code!;
    return 'Нэргүй';
  }

  /// `GOODS`-only, per the module doc comment's directional-stock rule —
  /// [ServicesRepository.adjustStock] is meaningless for any other kind and
  /// the server rejects it at the Prisma `where` (`type: "GOODS"`) before it
  /// ever reaches [computeStockAdjustment]-equivalent logic.
  bool get isStockAdjustable => type == ServiceKind.goods;
}

/// `DELETE /api/v1/services/[id]` outcome — `{id, name, type, outcome}`.
///
/// Modelled as its own class rather than reusing [Service]: the delete
/// command's `ServiceDeleteResult` is a narrower, unrelated shape (no price,
/// no code, no refs), and conflating the two would invite a caller to read a
/// field this response never carries.
enum ServiceDeleteOutcome {
  /// The row was soft-deleted (`isActive: false`) because it has order-item
  /// history. The catalogue row still exists and is still fetchable.
  archived,

  /// The row was hard-removed — no order-item history referenced it.
  deleted,

  /// Tolerant fallback for a value this build does not recognise. Treated as
  /// the more conservative reading by callers (i.e. "assume it might still
  /// exist, re-fetch to be sure") rather than assumed deleted.
  unknown;

  static ServiceDeleteOutcome fromWire(Object? value) => switch (value) {
    'archived' => archived,
    'deleted' => deleted,
    _ => unknown,
  };
}

class ServiceDeleteResult {
  final String id;
  final String? name;
  final ServiceKind type;
  final ServiceDeleteOutcome outcome;

  const ServiceDeleteResult({
    required this.id,
    this.name,
    this.type = ServiceKind.unknown,
    this.outcome = ServiceDeleteOutcome.unknown,
  });

  factory ServiceDeleteResult.fromJson(Map<String, dynamic> j) =>
      ServiceDeleteResult(
        id: _reqString(j, 'id'),
        name: _optString(j['name']),
        type: ServiceKind.fromWire(j['type']),
        outcome: ServiceDeleteOutcome.fromWire(j['outcome']),
      );
}

/// `POST /api/v1/services/[id]/stock` — `{id, stock}`. `stock` is always the
/// **resulting balance**, never an echo of the requested delta.
class ServiceStockResult {
  final String id;
  final String? stock;

  const ServiceStockResult({required this.id, this.stock});

  factory ServiceStockResult.fromJson(Map<String, dynamic> j) =>
      ServiceStockResult(
        id: _reqString(j, 'id'),
        stock: _optDecimalString(j['stock']),
      );
}

/// The direction `POST /api/v1/services/[id]/stock` takes — never an
/// absolute overwrite. See [computeStockAdjustment]-equivalent server logic:
/// a resulting negative balance is rejected as a 422 field error on
/// `amount`, not clamped to zero.
enum StockDirection {
  /// Adds `amount` to the current balance. Wire value `"in"`.
  incoming,

  /// Subtracts `amount` from the current balance. Wire value `"out"`.
  outgoing;

  String get wire => this == incoming ? 'in' : 'out';
}

/// `POST /api/v1/services/bulk/category` — `{succeeded, failed, errors}`.
///
/// Per-item, NOT all-or-nothing (explicitly the opposite of
/// `bulkChangeOrderStatusAction`/`bulkChangeAppointmentCategoryAction`): a
/// service id with no matching tenant-scoped row is one failure recorded in
/// [errors], and every other requested id still succeeds. [errors] has no
/// structural link back to which id failed beyond its human-readable text —
/// the server does not return a parallel id list, only display strings.
class BulkCategoryResult {
  final int succeeded;
  final int failed;
  final List<String> errors;

  const BulkCategoryResult({
    this.succeeded = 0,
    this.failed = 0,
    this.errors = const [],
  });

  factory BulkCategoryResult.fromJson(Map<String, dynamic> j) {
    final errors = j['errors'];
    return BulkCategoryResult(
      succeeded: _optInt(j['succeeded']) ?? 0,
      failed: _optInt(j['failed']) ?? 0,
      errors: errors is List
          ? errors.whereType<String>().toList(growable: false)
          : const [],
    );
  }
}

// ─── Parse helpers ─────────────────────────────────────────────────────────

String _reqString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw ServiceParseException('$key талбар буруу байна.');
  }
  return value.trim();
}

String? _optString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Accepts the server's raw `Decimal#toJSON()` string as-is (trimmed), and
/// tolerates a bare JSON number too (some proxies coerce), converting it with
/// `toString()` rather than through a `double` — a decimal string built from
/// a parsed double can already have lost precision by the time it is turned
/// back into text, which is exactly what this helper exists to avoid for a
/// money/quantity field.
String? _optDecimalString(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num) return value.toString();
  return null;
}

bool? _optBool(Object? value) => value is bool ? value : null;

/// Accepts a JSON number and a numeric string, but never truncates a
/// fractional value into a silently-wrong integer (`reminderIntervalMonths`,
/// `_count.items`).
int? _optInt(Object? value) {
  if (value is int) return value;
  if (value is double) {
    return value == value.roundToDouble() ? value.toInt() : null;
  }
  if (value is String) return int.tryParse(value.trim());
  return null;
}

DateTime? _optDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toLocal();
}

Map<String, dynamic>? _optMap(Object? value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
}
