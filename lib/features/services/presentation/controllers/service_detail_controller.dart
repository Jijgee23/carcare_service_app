import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/services/data/service_repository.dart';
import 'package:carcare_service/features/services/domain/service.dart';
import 'package:carcare_service/features/services/domain/services_repository.dart';

/// Detail-screen controller — P4-F3.
///
/// Fetches by id only (no preloaded-summary constructor), matching the
/// `P3-F4`/`P3-F5` convention. [load] carries a generation guard — the same
/// "second call wins, stale first response never overwrites it" rule
/// `CustomerDetailController`/`CustomerListController` already use — since a
/// user can back out and re-enter, or pull-to-refresh, while a previous
/// fetch is still in flight.
///
/// **Never renders `updateService`'s echo.** This controller has no `update`
/// method of its own; editing goes through `CreateServiceController` /
/// `CreateServiceScreen` in edit mode, and the caller is expected to call
/// [refresh] (a fresh `getService`) after a successful edit rather than
/// splice the `PATCH` response's — nested-ref-stripped, `stock`-omitting —
/// shape into [service]. See `service.dart`'s module doc comment.
class ServiceDetailController extends ChangeNotifier {
  ServiceDetailController({required this.serviceId, ServicesRepository? repo})
    : _repo = repo ?? RemoteServicesRepository();

  final String serviceId;
  final ServicesRepository _repo;

  AsyncValue<Service> state = const AsyncLoading();
  Service? get service => state.valueOrNull;

  bool mutating = false;
  AppError? lastError;

  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    state = const AsyncLoading();
    notifyListeners();

    final result = await _repo.getService(serviceId);
    if (generation != _generation) return; // superseded by a newer load()

    switch (result) {
      case Ok(:final value):
        state = AsyncData(value);
      case Err(:final error):
        state = AsyncError(error);
    }
    notifyListeners();
  }

  Future<void> refresh() => load();

  /// `DELETE /services/[id]` — the caller renders [ServiceDeleteResult.outcome]
  /// (`archived` vs. `deleted`) distinctly; this controller only forwards the
  /// server's answer, it never predicts it beyond what the confirm dialog
  /// already estimates from `orderItemCount`.
  Future<Result<ServiceDeleteResult>> delete() async {
    mutating = true;
    lastError = null;
    notifyListeners();
    final result = await _repo.deleteService(serviceId);
    mutating = false;
    if (result case Err(:final error)) lastError = error;
    notifyListeners();
    return result;
  }

  /// `POST /services/[id]/stock` — directional, `GOODS`-only (enforced by the
  /// sheet, not re-checked here since the repository/server already reject a
  /// non-`GOODS` id). Reloads the detail on success so [service.stock]
  /// reflects the server's resulting balance rather than a locally-computed
  /// guess.
  Future<Result<ServiceStockResult>> adjustStock({
    required StockDirection direction,
    required String amount,
  }) async {
    mutating = true;
    notifyListeners();
    final result = await _repo.adjustStock(
      serviceId,
      direction: direction,
      amount: amount,
    );
    mutating = false;
    if (result case Ok()) {
      notifyListeners();
      await load();
      return result;
    }
    notifyListeners();
    return result;
  }
}
