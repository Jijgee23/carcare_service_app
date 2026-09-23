import 'package:carcare_service/core/domain/working_branch_scope.dart';

/// A branch the current staff user may use as their working scope.
class SwitchableBranch {
  final String id;
  final String name;
  final bool isPrimary;

  const SwitchableBranch({
    required this.id,
    required this.name,
    this.isPrimary = false,
  });

  factory SwitchableBranch.fromJson(dynamic value) {
    final json = value is Map ? value : const <dynamic, dynamic>{};
    final id = _string(json['id']);
    final name = _string(json['name']);
    return SwitchableBranch(
      id: id ?? '',
      name: name ?? id ?? 'Салбар',
      isPrimary: json['isPrimary'] == true,
    );
  }
}

/// Domain boundary consumed by the controller. Implementations may use Dio,
/// a fake, or a future cache without leaking that choice into presentation.
abstract interface class WorkingBranchRepository {
  Future<WorkingBranchOptions> fetchOptions();
}

/// Server-authoritative branch choices and roster lock for the current user.
class WorkingBranchOptions {
  final List<SwitchableBranch> branches;
  final bool allowAll;
  final String? lockedBranchId;

  const WorkingBranchOptions({
    required this.branches,
    required this.allowAll,
    required this.lockedBranchId,
  });

  factory WorkingBranchOptions.fromJson(dynamic value) {
    final json = value is Map ? value : const <dynamic, dynamic>{};
    final rawBranches = json['branches'];
    final branches = <SwitchableBranch>[];
    if (rawBranches is List) {
      for (final raw in rawBranches) {
        final branch = SwitchableBranch.fromJson(raw);
        if (branch.id.isEmpty || branches.any((item) => item.id == branch.id)) {
          continue;
        }
        branches.add(branch);
      }
    }
    return WorkingBranchOptions(
      branches: List.unmodifiable(branches),
      allowAll: json['allowAll'] == true,
      lockedBranchId: _string(json['lockedBranchId']),
    );
  }

  bool containsBranch(String? id) =>
      id != null && branches.any((branch) => branch.id == id);

  bool isValidSelection(String? selection) {
    if (selection == allWorkingBranches) {
      return allowAll && lockedBranchId == null;
    }
    return selection == null ||
        (lockedBranchId == null && containsBranch(selection));
  }
}

String? _string(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
