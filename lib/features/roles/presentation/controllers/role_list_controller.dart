import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/roles/domain/role.dart';
import 'package:carcare_service/features/roles/domain/roles_repository.dart';
import 'package:carcare_service/features/roles/data/role_repository.dart';

/// Presentation state for the owner-only Roles list — P6-F3.
///
/// Ownership is decided by the screen (`user.isOwner`), not here — this
/// controller assumes it is only ever constructed once a caller has already
/// passed that gate, matching `ServiceListScreen`'s pattern of returning a
/// refusal `Scaffold` before ever building the state-holding subtree.
class RoleListController extends ChangeNotifier {
  RoleListController({RolesRepository? repo})
    : _repo = repo ?? RemoteRolesRepository();

  final RolesRepository _repo;
  bool _disposed = false;

  AsyncValue<List<Role>> listState = const AsyncLoading();

  /// Last delete failure, surfaced by the screen (e.g. `ROLE_IN_USE`).
  AppError? deleteError;
  bool deleting = false;

  Future<void> load() async {
    listState = const AsyncLoading();
    notifyListeners();
    final result = await _repo.getRoles();
    if (_disposed) return;
    switch (result) {
      case Ok(:final value):
        listState = AsyncData(value.items);
      case Err(:final error):
        listState = AsyncError(error);
    }
    notifyListeners();
  }

  Future<void> refresh() => load();

  /// Returns `true` on success. On `ROLE_IN_USE` (or any other failure),
  /// [deleteError] is set for the screen to surface and the list is left
  /// untouched.
  Future<bool> deleteRole(String roleId) async {
    deleting = true;
    deleteError = null;
    notifyListeners();

    final result = await _repo.deleteRole(roleId);
    deleting = false;
    switch (result) {
      case Ok():
        final current = listState.valueOrNull ?? const <Role>[];
        listState = AsyncData(
          current.where((r) => r.id != roleId).toList(growable: false),
        );
        notifyListeners();
        return true;
      case Err(:final error):
        deleteError = error;
        notifyListeners();
        return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
