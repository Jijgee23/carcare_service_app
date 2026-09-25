import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart';

import 'package:carcare_service/core/domain/working_branch_scope.dart';
import 'package:carcare_service/core/network/working_branch_interceptor.dart';
import 'package:carcare_service/features/shell/domain/working_branch.dart';

enum WorkingBranchLoadState { initial, loading, ready, error }

/// Owns branch-switcher state and reconciles persisted choices with the API.
class WorkingBranchController extends ChangeNotifier {
  final WorkingBranchRepository repository;
  final WorkingBranchSelectionStore store;
  final Future<void> Function()? onInvalidation;
  final Future<void> Function()? onSelectionChanged;
  final WorkingBranchInvalidationBus invalidationBus;
  bool _handlingInvalidation = false;
  int _loadRequestId = 0;

  WorkingBranchLoadState state = WorkingBranchLoadState.initial;
  WorkingBranchOptions options = const WorkingBranchOptions(
    branches: [],
    allowAll: false,
    lockedBranchId: null,
  );
  String? selection;
  Object? error;

  WorkingBranchController({
    required this.repository,
    WorkingBranchSelectionStore? store,
    this.onInvalidation,
    this.onSelectionChanged,
    WorkingBranchInvalidationBus? invalidationBus,
  }) : store = store ?? HiveWorkingBranchSelectionStore(),
       invalidationBus =
           invalidationBus ?? WorkingBranchInvalidationBus.instance {
    this.invalidationBus.addListener(handleInvalidBranch);
  }

  @override
  void dispose() {
    _loadRequestId++;
    invalidationBus.removeListener(handleInvalidBranch);
    super.dispose();
  }

  bool get isLoading => state == WorkingBranchLoadState.loading;
  bool get hasError => state == WorkingBranchLoadState.error;
  bool get isLocked => options.lockedBranchId != null;
  bool get isAllBranches => selection == allWorkingBranches;
  String? get selectedBranchId => isAllBranches ? null : selection;

  /// Web `/page/choose-branch` parity: after login, an owner or a staff
  /// member with 2+ branches must pick a working scope before the app opens,
  /// unless today's roster locks them to one branch. Single-option users fall
  /// through to the server's absent-header default.
  bool get needsChoice =>
      state == WorkingBranchLoadState.ready &&
      selection == null &&
      !isLocked &&
      (options.branches.length >= 2 ||
          (options.allowAll && options.branches.isNotEmpty));

  Future<void> load() async {
    final requestId = ++_loadRequestId;
    state = WorkingBranchLoadState.loading;
    error = null;
    notifyListeners();
    try {
      final fetched = await repository.fetchOptions();
      if (requestId != _loadRequestId) return;
      options = fetched;
      final persisted = await store.read();
      if (requestId != _loadRequestId) return;
      final reconciled = _reconcile(persisted, fetched);
      selection = reconciled;
      if (reconciled != persisted) await store.write(reconciled);
      if (requestId != _loadRequestId) return;
      state = WorkingBranchLoadState.ready;
    } catch (exception) {
      if (requestId != _loadRequestId) return;
      error = exception;
      state = WorkingBranchLoadState.error;
    }
    notifyListeners();
  }

  /// Handles the interceptor's stale-branch signal. It intentionally performs
  /// one clear and one refetch; the interceptor itself suppresses duplicate
  /// signals from concurrent failed requests.
  Future<void> handleInvalidBranch() async {
    if (_handlingInvalidation) return;
    _handlingInvalidation = true;
    // Invalidate an in-flight load before awaiting storage or callbacks. Its
    // result must not overwrite the refetch started below.
    _loadRequestId++;
    try {
      await _handleInvalidBranch();
    } finally {
      _handlingInvalidation = false;
    }
  }

  Future<void> _handleInvalidBranch() async {
    await store.clear();
    selection = null;
    notifyListeners();
    await onInvalidation?.call();
    await load();
  }

  Future<bool> selectAll() => select(allWorkingBranches);

  Future<bool> selectBranch(String? branchId) => select(branchId);

  Future<bool> select(String? next) async {
    if (isLocked) return next == options.lockedBranchId && selection == next;
    if (!options.isValidSelection(next)) return false;
    if (selection == next) return true;
    selection = next;
    await store.write(next);
    await onSelectionChanged?.call();
    notifyListeners();
    return true;
  }

  String? _reconcile(String? persisted, WorkingBranchOptions fetched) {
    final locked = fetched.lockedBranchId;
    if (locked != null) return locked;
    if (persisted == allWorkingBranches) {
      return fetched.allowAll ? allWorkingBranches : null;
    }
    if (persisted == null) return null;
    return fetched.containsBranch(persisted) ? persisted : null;
  }
}

/// The concrete working branch selected in the shell, or null for "all
/// branches" / outside the shell (tests, pre-login). Screens that create
/// branch-scoped records default to this — the server rejects a branch that
/// conflicts with the `X-Working-Branch` header (403/422).
String? workingBranchIdOf(BuildContext context) {
  try {
    return context.read<WorkingBranchController>().selectedBranchId;
  } on ProviderNotFoundException {
    return null;
  }
}
