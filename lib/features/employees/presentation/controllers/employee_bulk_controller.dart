import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/widgets/selection/selection_controller.dart';
import 'package:carcare_service/features/employees/data/employee_repository.dart';
import 'package:carcare_service/features/employees/domain/employee.dart';
import 'package:carcare_service/features/employees/domain/employees_repository.dart';

/// Loads every employee (defensively capped, matching
/// `BulkCategoryScreen._load`'s 1,000-row/10-page cap) and drives bulk
/// role/branch reassignment through the generic
/// `lib/core/widgets/selection/` [SelectionController] — P6-F2.
///
/// `POST /employees/bulk` is per-row, never all-or-nothing (see
/// `EmployeesRepository.bulkUpdateRoleBranch`'s doc comment) — a partial
/// failure is surfaced via [lastResult], not thrown, exactly like
/// `BulkCategoryScreen`'s `_lastResult`/`_BulkResultBanner`.
class EmployeeBulkController extends ChangeNotifier {
  EmployeeBulkController({EmployeesRepository? repo})
    : _repo = repo ?? RemoteEmployeesRepository();

  final EmployeesRepository _repo;

  /// Exposed rather than owned privately so a screen can pass it straight
  /// to `SelectionActionBar`/`SelectableListTile` — this controller only
  /// adds the data-loading and bulk-submit half on top.
  final SelectionController<String> selection = SelectionController<String>();

  AsyncValue<List<Employee>> listState = const AsyncLoading();
  bool submitting = false;
  EmployeeBulkResult? lastResult;

  List<Employee> get items => listState.valueOrNull ?? const <Employee>[];

  Future<void> load() async {
    listState = const AsyncLoading();
    notifyListeners();

    final items = <Employee>[];
    AppError? loadError;
    const pageSize = 100;
    const maxPages = 10; // defensive cap — 1,000 rows, see class doc comment
    for (var page = 1; page <= maxPages; page++) {
      final result = await _repo.getEmployees(
        query: EmployeeListQuery(page: page, pageSize: pageSize),
      );
      if (result case Ok(:final value)) {
        items.addAll(value.page.items);
        if (!value.page.pagination.hasNext) break;
      } else if (result case Err(:final error)) {
        loadError = error;
        break;
      }
    }

    listState = loadError != null && items.isEmpty
        ? AsyncError<List<Employee>>(loadError)
        : AsyncData(items);
    selection.pruneMissing(items.map((e) => e.id));
    notifyListeners();
  }

  Future<void> refresh() => load();

  Future<Result<EmployeeBulkResult>> apply({
    String? roleId,
    String? branchId,
  }) async {
    if (selection.isEmpty) {
      return const Err(
        AppError(
          ErrorKind.unknown,
          'Дор хаяж нэг ажилтан сонгоно уу.',
          statusCode: 422,
          code: 'VALIDATION',
        ),
      );
    }
    submitting = true;
    notifyListeners();
    final result = await _repo.bulkUpdateRoleBranch(
      employeeIds: selection.selected.toList(growable: false),
      roleId: roleId,
      branchId: branchId,
    );
    switch (result) {
      case Ok(:final value):
        lastResult = value;
        selection.clear();
        await load();
      case Err():
        // Whole-request rejection (e.g. neither roleId nor branchId sent) —
        // never folded into `lastResult`, matching
        // `EmployeesRepository.bulkUpdateRoleBranch`'s doc comment.
        break;
    }
    submitting = false;
    notifyListeners();
    return result;
  }
}
