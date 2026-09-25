// `Category` (this file's domain model) collides with `package:meta`'s
// `@Category` annotation class, re-exported through `foundation.dart` —
// hidden here rather than aliasing the far more frequently used domain type.
import 'package:flutter/foundation.dart' hide Category;

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/services/service_catalog_service.dart'
    show ServiceCatalogService;
import 'package:carcare_service/core/domain/service_catalog.dart' as legacy;
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/services/domain/service.dart';
import 'package:carcare_service/features/services/domain/services_repository.dart';
import 'package:carcare_service/features/services/data/service_repository.dart';

/// Create/edit form controller — P4-F3 rebuild.
///
/// **Two backends behind one form, deliberately.** `P4-F1` froze
/// [ServicesRepository] with no `createService` method — `service.dart`'s
/// module doc comment records that `POST /api/v1/services` is out of that
/// slice's scope and stays served by the legacy
/// `lib/core/services/service_catalog_service.dart` (`ServiceCatalogService`,
/// out of scope for this slice too — see `AGENTS.md`'s no-opportunistic-
/// refactor rule). So:
/// * **create** ([existing] `null`) submits through
///   `ServiceCatalogService.createService`, unchanged;
/// * **edit** ([existing] non-`null`) submits through
///   [ServicesRepository.updateService] — the new, frozen, whole-record-
///   replace contract.
///
/// Both paths share one lookup source: [ServicesRepository.getUnits]/
/// [getCategories] (D-164, read-only). The legacy `createService` only needs
/// the picked id strings, so feeding it ids sourced from the new [Unit]/
/// [Category] models is safe — no second, legacy lookup call is made.
///
/// **Category is now required for every kind, not just `LABOR`.** The
/// repository interface's [ServicesRepository.updateService] takes
/// `categoryId` as `required String`, and `Category`'s own doc comment
/// records `P4-B1`'s widened `allowedKinds`. The legacy create path still
/// accepts a null `laborCategoryId`, but this form requires a selection for
/// every kind on both create and edit — the stricter of the two rules wins,
/// since sending a category the server will need to keep anyway is never
/// wrong.
///
/// **`type` is immutable after creation** ([ServicesRepository.updateService]'s
/// doc comment) — [setType] is a no-op once [isEditing] is true; the screen
/// must not offer the kind switcher in edit mode.
///
/// **Stock is never edited here.** On create, [showCostAndStock] still
/// collects an initial `stock` for `GOODS` because the legacy `createService`
/// actually writes it. On edit, `stock` is resent verbatim from [existing]
/// only to satisfy `updateService`'s validation — never taken from user
/// input — because the server discards it unconditionally on that path (see
/// the repository doc comment) and only [ServicesRepository.adjustStock]
/// (the stock-adjust sheet) ever changes it.
///
/// **`reminderIntervalMonths` is pre-filled on edit** from [existing]: both
/// `GET` routes select it, and because `PATCH` replaces the whole record a
/// blank value would clear the service's reminder interval.
class CreateServiceController extends ChangeNotifier {
  CreateServiceController({
    this.existing,
    ServicesRepository? repo,
    ServiceKind initialType = ServiceKind.labor,
  }) : _repo = repo ?? RemoteServicesRepository(),
       type = existing?.type ?? initialType,
       isActive = existing?.isActive ?? true;

  /// `null` → create mode. Non-null → edit mode, the record being replaced.
  final Service? existing;
  final ServicesRepository _repo;

  bool get isEditing => existing != null;

  // ─── Lookup data (shared by both modes, D-164 read-only) ──────────────────

  List<Unit> units = const [];
  List<Category> categories = const [];
  bool loadingLookups = true;
  AppError? lookupError;

  // ─── Form state ────────────────────────────────────────────────────────────

  ServiceKind type;
  bool isActive;
  bool submitting = false;

  Unit? selectedUnit;
  Category? selectedCategory;
  Unit? selectedDurationUnit;

  /// Last submit failure, if any. `null` on success or before the first
  /// submit. The screen binds `lastError?.fieldErrors` to individual fields
  /// and falls back to a toast only when the server sent no field-level
  /// detail (matching `CustomerEditSheet`'s convention).
  AppError? lastError;
  Map<String, String> get fieldErrors => lastError?.fieldErrors ?? const {};

  // ─── Derived visibility — category is mandatory for every kind now ────────

  bool get showUnit => true;
  bool get showCategory => true;
  bool get showDuration =>
      type == ServiceKind.labor || type == ServiceKind.diagnostic;
  bool get showCostAndStock => type == ServiceKind.goods;

  /// Edit mode only: the stock value this form resends verbatim to satisfy
  /// `updateService`'s validation. Never surfaced as an editable field — see
  /// the class doc comment.
  String? get lockedStock => existing?.stock;

  // ─── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    loadingLookups = true;
    lookupError = null;
    notifyListeners();

    final results = await Future.wait([
      _repo.getUnits(),
      _repo.getCategories(),
    ]);

    switch (results[0]) {
      case Ok(:final value):
        units = value as List<Unit>;
      case Err(:final error):
        lookupError = error;
    }
    switch (results[1]) {
      case Ok(:final value):
        categories = value as List<Category>;
      case Err(:final error):
        lookupError ??= error;
    }

    final current = existing;
    if (current != null) {
      selectedUnit = _findUnit(current.unitId);
      selectedCategory = _findCategory(current.categoryId);
      selectedDurationUnit = _findUnit(current.durationUnitId);
    }

    loadingLookups = false;
    notifyListeners();
  }

  Unit? _findUnit(String? id) {
    if (id == null) return null;
    for (final u in units) {
      if (u.id == id) return u;
    }
    return null;
  }

  Category? _findCategory(String? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ─── Setters ───────────────────────────────────────────────────────────────

  void setType(ServiceKind k) {
    // Immutable after creation — see the class doc comment. The screen must
    // not present this control in edit mode, but the guard stays here too so
    // a stray call cannot silently "succeed" without persisting.
    if (isEditing) return;
    type = k;
    if (!showDuration) selectedDurationUnit = null;
    notifyListeners();
  }

  void setUnit(Unit? u) {
    selectedUnit = u;
    notifyListeners();
  }

  void setCategory(Category? c) {
    selectedCategory = c;
    notifyListeners();
  }

  void setDurationUnit(Unit? u) {
    selectedDurationUnit = u;
    notifyListeners();
  }

  void setIsActive(bool v) {
    isActive = v;
    notifyListeners();
  }

  // ─── Submit ────────────────────────────────────────────────────────────────

  /// Returns `true` on success. The caller (the screen) pops with that
  /// boolean rather than any created/updated object — the two backends
  /// return different types ([legacy.CatalogService] vs. [Service]), and a
  /// bare "saved, please refresh" signal sidesteps reconciling them. Per the
  /// module doc comment on `service.dart`, a display surface must re-fetch
  /// after a successful edit rather than trust either response's echo.
  Future<bool> submit({
    required String name,
    String? code,
    required String price,
    String? costPrice,
    String? stock,
    String? durationValue,
    int? reminderIntervalMonths,
    String? description,
  }) async {
    submitting = true;
    lastError = null;
    notifyListeners();

    final result = isEditing
        ? await _submitEdit(
            name: name,
            code: code,
            price: price,
            costPrice: costPrice,
            durationValue: durationValue,
            reminderIntervalMonths: reminderIntervalMonths,
            description: description,
          )
        : await _submitCreate(
            name: name,
            code: code,
            price: price,
            costPrice: costPrice,
            stock: stock,
            durationValue: durationValue,
            description: description,
          );

    submitting = false;
    notifyListeners();
    return result;
  }

  Future<bool> _submitEdit({
    required String name,
    String? code,
    required String price,
    String? costPrice,
    String? durationValue,
    int? reminderIntervalMonths,
    String? description,
  }) async {
    final result = await _repo.updateService(
      existing!.id,
      type: type,
      name: name,
      code: code,
      unitId: selectedUnit?.id,
      price: price,
      costPrice: costPrice,
      // Resent verbatim, never edited here — see the class doc comment.
      stock: lockedStock,
      durationValue: showDuration ? durationValue : null,
      durationUnitId: showDuration ? selectedDurationUnit?.id : null,
      reminderIntervalMonths: reminderIntervalMonths,
      description: description,
      isActive: isActive,
      categoryId: selectedCategory?.id ?? '',
    );
    switch (result) {
      case Ok():
        return true;
      case Err(:final error):
        lastError = error;
        return false;
    }
  }

  Future<bool> _submitCreate({
    required String name,
    String? code,
    required String price,
    String? costPrice,
    String? stock,
    String? durationValue,
    String? description,
  }) async {
    final result = await ServiceCatalogService.createService(
      type: _legacyKind(type),
      name: name,
      code: code,
      price: double.tryParse(price) ?? 0,
      costPrice: showCostAndStock && costPrice != null
          ? double.tryParse(costPrice)
          : null,
      stock: showCostAndStock && stock != null ? double.tryParse(stock) : null,
      description: description,
      isActive: isActive,
      unitId: selectedUnit?.id,
      laborCategoryId: selectedCategory?.id,
      durationValue: showDuration && durationValue != null
          ? double.tryParse(durationValue)
          : null,
      durationUnitId: showDuration ? selectedDurationUnit?.id : null,
    );
    switch (result) {
      case Ok():
        return true;
      case Err(:final error):
        lastError = error;
        return false;
    }
  }

  static legacy.ServiceKind _legacyKind(ServiceKind kind) => switch (kind) {
    ServiceKind.labor => legacy.ServiceKind.LABOR,
    ServiceKind.goods => legacy.ServiceKind.GOODS,
    ServiceKind.diagnostic => legacy.ServiceKind.DIAGNOSTIC,
    // `unknown` has no legacy counterpart and the kind selector never lets a
    // user choose it (see `create_service_screen.dart`) — LABOR is the same
    // permissive default the constructor itself falls back to.
    ServiceKind.unknown => legacy.ServiceKind.LABOR,
  };
}
