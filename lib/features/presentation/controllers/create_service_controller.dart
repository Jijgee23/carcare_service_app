import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/services/service_catalog_service.dart';
import 'package:carcare_service/features/models/service_catalog.dart';
import 'package:carcare_service/shared/widgets/dialogs/message.dart';
import 'package:flutter/foundation.dart';

class CreateServiceController extends ChangeNotifier {
  CreateServiceController({ServiceKind initialType = ServiceKind.LABOR})
      : type = initialType;

  // ─── Lookup data ───────────────────────────────────────────────────────────

  List<ServiceUnit> units = [];
  List<LaborCategory> categories = [];
  bool loadingLookups = true;

  // ─── Form state ────────────────────────────────────────────────────────────

  ServiceKind type;
  bool isActive = true;
  bool submitting = false;

  ServiceUnit? selectedUnit;
  LaborCategory? selectedCategory;
  ServiceUnit? selectedDurationUnit;

  // ─── Derived visibility ────────────────────────────────────────────────────

  bool get showUnit => true;
  bool get showCategory => type == ServiceKind.LABOR;
  bool get showDuration => type == ServiceKind.LABOR || type == ServiceKind.DIAGNOSTIC;
  bool get showCostAndStock => type == ServiceKind.GOODS;

  // ─── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    loadingLookups = true;
    notifyListeners();

    final results = await Future.wait([
      ServiceCatalogService.getUnits(),
      ServiceCatalogService.getLaborCategories(),
    ]);

    if (results[0] case Ok(value: final u)) units = u as List<ServiceUnit>;
    if (results[1] case Ok(value: final c)) categories = c as List<LaborCategory>;

    loadingLookups = false;
    notifyListeners();
  }

  // ─── Setters ───────────────────────────────────────────────────────────────

  void setType(ServiceKind k) {
    type = k;
    if (!showCategory) selectedCategory = null;
    if (!showDuration) selectedDurationUnit = null;
    notifyListeners();
  }

  void setUnit(ServiceUnit? u) {
    selectedUnit = u;
    notifyListeners();
  }

  void setCategory(LaborCategory? c) {
    selectedCategory = c;
    notifyListeners();
  }

  void setDurationUnit(ServiceUnit? u) {
    selectedDurationUnit = u;
    notifyListeners();
  }

  void setIsActive(bool v) {
    isActive = v;
    notifyListeners();
  }

  // ─── Submit ────────────────────────────────────────────────────────────────

  Future<CatalogService?> submit({
    required String name,
    String? code,
    required double price,
    double? costPrice,
    double? stock,
    double? durationValue,
    String? description,
  }) async {
    submitting = true;
    notifyListeners();

    final result = await ServiceCatalogService.createService(
      type: type,
      name: name,
      code: code,
      price: price,
      costPrice: showCostAndStock ? costPrice : null,
      stock: showCostAndStock ? stock : null,
      description: description,
      isActive: isActive,
      unitId: selectedUnit?.id,
      laborCategoryId: selectedCategory?.id,
      durationValue: showDuration ? durationValue : null,
      durationUnitId: showDuration ? selectedDurationUnit?.id : null,
    );

    submitting = false;
    notifyListeners();

    return switch (result) {
      Ok(:final value) => value,
      Err(:final error) => () {
          messageError(error.display);
          return null;
        }(),
    };
  }
}
