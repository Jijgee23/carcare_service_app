import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/roles/domain/permission.dart';
import 'package:carcare_service/features/roles/domain/permission_catalog_repository.dart';
import 'package:carcare_service/features/roles/domain/role.dart';
import 'package:carcare_service/features/roles/domain/roles_repository.dart';
import 'package:carcare_service/features/roles/data/permission_catalog_repository.dart';
import 'package:carcare_service/features/roles/data/role_repository.dart';

/// Create/edit controller for the owner-only role form — P6-F3.
///
/// The permission picker is built **only** from [PermissionCatalogRepository]
/// — this file, and the screen it backs, must never hardcode a permission
/// code (grep target for the slice's acceptance check). [toggle]/
/// [toggleGroup] operate purely on the codes the catalogue handed back.
///
/// [orderScopeHint] mirrors `carcare.mn/lib/roles/validate.ts`'s
/// `validateOrderScopes` **client-side, as a hint only** — the server stays
/// authoritative and its own `fieldErrors.orderScopes` (surfaced through
/// [lastError]) always wins on submit. The exact rule, copied verbatim: if
/// `orders.edit` or `orders.editOwn` is selected without `orders.view` or
/// `orders.viewOwn`, and separately if `orders.edit` is selected without
/// `orders.view` specifically, show a hint. This controller keeps both of
/// the web's two messages distinct rather than collapsing them, since the
/// second is strictly narrower branch-scope guidance.
class RoleFormController extends ChangeNotifier {
  RoleFormController({
    this.existing,
    RolesRepository? rolesRepo,
    PermissionCatalogRepository? catalogRepo,
  }) : _rolesRepo = rolesRepo ?? RemoteRolesRepository(),
       _catalogRepo = catalogRepo ?? RemotePermissionCatalogRepository(),
       isActive = existing?.isActive ?? true,
       selected = {...(existing?.permissions ?? const <String>[])};

  /// `null` → create mode. Non-null → edit mode, the role being replaced.
  final Role? existing;
  final RolesRepository _rolesRepo;
  final PermissionCatalogRepository _catalogRepo;

  bool get isEditing => existing != null;

  // ─── Catalogue ─────────────────────────────────────────────────────────

  PermissionCatalog catalog = const PermissionCatalog();
  bool loadingCatalog = true;
  AppError? catalogError;

  // ─── Form state ────────────────────────────────────────────────────────

  bool isActive;
  bool submitting = false;
  final Set<String> selected;

  /// Last submit failure. The screen binds `lastError?.fieldErrors` per
  /// field, matching `CreateServiceController`'s convention, and falls back
  /// to a toast/banner when the server sent no field-level detail.
  AppError? lastError;
  Map<String, String> get fieldErrors => lastError?.fieldErrors ?? const {};

  Future<void> init() async {
    loadingCatalog = true;
    catalogError = null;
    notifyListeners();

    final result = await _catalogRepo.getPermissions();
    switch (result) {
      case Ok(:final value):
        catalog = value;
      case Err(:final error):
        catalogError = error;
    }
    loadingCatalog = false;
    notifyListeners();
  }

  // ─── Selection ─────────────────────────────────────────────────────────

  bool isSelected(String code) => selected.contains(code);

  void toggle(String code, bool value) {
    if (value) {
      selected.add(code);
    } else {
      selected.remove(code);
    }
    notifyListeners();
  }

  /// Group select-all. [items] is a group's own item list (or the
  /// standalone list) — this controller never assumes a group's identity
  /// beyond what the catalogue handed it.
  bool isGroupFullySelected(List<PermissionItem> items) =>
      items.isNotEmpty && items.every((i) => selected.contains(i.code));

  bool isGroupPartiallySelected(List<PermissionItem> items) =>
      items.any((i) => selected.contains(i.code)) &&
      !isGroupFullySelected(items);

  void toggleGroup(List<PermissionItem> items, bool value) {
    for (final item in items) {
      if (value) {
        selected.add(item.code);
      } else {
        selected.remove(item.code);
      }
    }
    notifyListeners();
  }

  void setIsActive(bool v) {
    isActive = v;
    notifyListeners();
  }

  // ─── Client-side hints (server authoritative) ───────────────────────────

  /// `true` when at least one permission is selected. Mirrors the server's
  /// `permissions.length === 0` rejection as a pre-submit hint only.
  bool get hasAtLeastOnePermission => selected.isNotEmpty;

  /// Mirrors `validateOrderScopes` from `lib/roles/validate.ts` verbatim.
  /// Returns the Mongolian message to show under the order-scope section,
  /// or `null` when no hint applies. The narrower branch-scope message
  /// (requires exactly `orders.view`, not just `orders.viewOwn`) takes
  /// precedence when both would fire, matching the web's `errors.orderScopes`
  /// single-slot assignment order (the second `if` overwrites the first).
  String? get orderScopeHint {
    final view =
        selected.contains('orders.view') || selected.contains('orders.viewOwn');
    final edit =
        selected.contains('orders.edit') || selected.contains('orders.editOwn');
    String? hint;
    if (edit && !view) {
      hint = 'Засах эрх олгохын өмнө засварын хуудсыг харах хүрээг сонгоно уу.';
    }
    if (selected.contains('orders.edit') && !selected.contains('orders.view')) {
      hint = 'Салбарын засах эрхэд Салбарын харах эрх шаардлагатай.';
    }
    return hint;
  }

  // ─── Submit ────────────────────────────────────────────────────────────

  Future<bool> submit({required String name, String? description}) async {
    submitting = true;
    lastError = null;
    notifyListeners();

    final permissions = selected.toList(growable: false);
    final result = isEditing
        ? await _rolesRepo.updateRole(
            existing!.id,
            name: name,
            description: description,
            permissions: permissions,
            isActive: isActive,
          )
        : await _rolesRepo.createRole(
            name: name,
            description: description,
            permissions: permissions,
            isActive: isActive,
          );

    submitting = false;
    switch (result) {
      case Ok():
        notifyListeners();
        return true;
      case Err(:final error):
        lastError = error;
        notifyListeners();
        return false;
    }
  }
}
