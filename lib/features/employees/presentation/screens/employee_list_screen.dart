import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/widgets/adaptive/async_state_view.dart';
import 'package:carcare_service/core/widgets/adaptive/permission_gate.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/core/widgets/mixin/pagination_mixin.dart';
import 'package:carcare_service/features/employees/domain/employee.dart';
import 'package:carcare_service/features/employees/domain/employees_repository.dart';
import 'package:carcare_service/features/employees/presentation/controllers/employee_list_controller.dart';

/// Server-paginated Employees list — P6-F2.
///
/// Copies `ServiceListScreen`'s controller/pagination/search shape. Search
/// (350ms debounce), branch chips with stable counts, role-label filter,
/// and an active/inactive filter are all rendered here. Gated on
/// `employees.view` at the surface level (D-163), matching every other list
/// screen in this app.
///
/// The synthetic "Хуваарилагдаагүй" (unassigned) chip from `meta.branches`
/// renders as a count-only badge, not a tappable filter — see
/// `EmployeeListController.setBranch`'s doc comment: the server route has
/// no way to filter *by* an unassigned branch at all (`branchId=""` is
/// dropped server-side), so faking that filter client-side over only the
/// already-loaded page would silently misreport results once there is more
/// than one page. That is worse than the chip simply not being tappable.
///
/// **Not wired to a route** — `lib/app/router.dart`/`app_shell.dart` are
/// owned by the later `P6-F5` slice. Intended route: `/employees` (list),
/// reached from the "Хүмүүс" section, gated on `employees.view`. [onTapRow]/
/// [onCreate]/[onBulkEdit] are hooks for that slice to wire, matching
/// `ServiceListScreen`'s `onSelectService`/`onCreateService` precedent —
/// each hidden affordance simply does not render when its hook is null.
class EmployeeListScreen extends StatelessWidget {
  const EmployeeListScreen({
    super.key,
    this.repository,
    this.user,
    this.onTapRow,
    this.onCreate,
    this.onBulkEdit,
  });

  final EmployeesRepository? repository;
  final User? user;
  final ValueChanged<Employee>? onTapRow;
  final VoidCallback? onCreate;
  final VoidCallback? onBulkEdit;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => EmployeeListController(repo: repository),
    child: _Body(
      user: user,
      onTapRow: onTapRow,
      onCreate: onCreate,
      onBulkEdit: onBulkEdit,
    ),
  );
}

class _Body extends StatefulWidget {
  const _Body({this.user, this.onTapRow, this.onCreate, this.onBulkEdit});

  final User? user;
  final ValueChanged<Employee>? onTapRow;
  final VoidCallback? onCreate;
  final VoidCallback? onBulkEdit;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> with PaginationMixin {
  final _searchController = TextEditingController();
  bool _didLoad = false;

  User? get _user => widget.user ?? Authenticator.user;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      final controller = context.read<EmployeeListController>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        initPagination(() {
          if (mounted) controller.loadMore();
        });
        controller.loadEmployees();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (!canSeeView(user, 'employees.view')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ажилтнууд')),
        body: const EmptyState(
          message: 'Танд ажилтны жагсаалт харах эрх байхгүй байна.',
          icon: Icons.lock_outline,
        ),
      );
    }

    final controller = context.watch<EmployeeListController>();
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Ажилтнууд'),
        actions: [
          if (widget.onBulkEdit != null)
            PermissionGate(
              permission: 'employees.edit',
              user: user,
              child: IconButton(
                icon: const Icon(Icons.checklist_rtl),
                tooltip: 'Бөөнөөр өөрчлөх',
                onPressed: widget.onBulkEdit,
              ),
            ),
          IconButton(
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(148),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _SearchField(
                  controller: _searchController,
                  onChanged: controller.setQuery,
                  onClear: () {
                    _searchController.clear();
                    controller.setQuery('');
                  },
                ),
              ),
              _BranchChipRow(controller: controller),
              const SizedBox(height: 6),
              _FilterRow(controller: controller),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
      floatingActionButton: widget.onCreate == null
          ? null
          : PermissionGate(
              permission: 'employees.create',
              user: user,
              child: FloatingActionButton(
                heroTag: 'employee_create_fab',
                onPressed: widget.onCreate,
                backgroundColor: context.colors.accent,
                child: Icon(
                  Icons.person_add_alt_1,
                  color: CarCareTheme.of(context).onAccent,
                ),
              ),
            ),
      body: AsyncStateView<List<Employee>>(
        state: controller.listState,
        isEmpty: (items) => items.isEmpty,
        empty: _EmptyView(query: controller.query),
        onRetry: controller.refresh,
        builder: (context, items) {
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.all(AppDimens.paddingMD),
              itemCount: items.length + 1,
              separatorBuilder: (_, i) =>
                  SizedBox(height: i == items.length - 1 ? 4 : 8),
              itemBuilder: (_, index) {
                if (index == items.length) {
                  return _ListFooter(controller: controller);
                }
                final employee = items[index];
                return _EmployeeCard(
                  employee: employee,
                  onTap: widget.onTapRow == null
                      ? null
                      : () => widget.onTapRow!(employee),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ─── Search / filters ────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(fontSize: 14, color: context.colors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Нэр, имэйл, утас хайх...',
        hintStyle: TextStyle(color: context.colors.textHint, fontSize: 14),
        prefixIcon: Icon(
          Icons.search,
          color: context.colors.textHint,
          size: 18,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close,
                  color: context.colors.textHint,
                  size: 18,
                ),
              ),
        filled: true,
        fillColor: context.colors.background,
        contentPadding: EdgeInsets.zero,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          borderSide: BorderSide(color: CarCareTheme.of(context).accentHi),
        ),
      ),
    ),
  );
}

class _BranchChipRow extends StatelessWidget {
  const _BranchChipRow({required this.controller});
  final EmployeeListController controller;

  @override
  Widget build(BuildContext context) {
    final branches = controller.meta.branches;
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(
            label: 'Бүгд',
            selected: controller.branchId == null,
            onTap: () => controller.setBranch(null),
          ),
          const SizedBox(width: 6),
          for (final b in branches) ...[
            b.isUnassigned
                // Count-only, not tappable — see `EmployeeListController.
                // setBranch`'s doc comment: the server cannot filter by an
                // unassigned branch at all, so this chip must not pretend
                // to be a working filter.
                ? Tooltip(
                    message: 'Зөвхөн тоог харуулна — шүүлтүүр биш',
                    child: _Chip(
                      label: 'Хуваарилагдаагүй (${b.count})',
                      selected: false,
                      onTap: null,
                    ),
                  )
                : _Chip(
                    label: '${b.name ?? '—'} (${b.count})',
                    selected: controller.branchId == b.id,
                    onTap: () => controller.setBranch(b.id),
                  ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.controller});
  final EmployeeListController controller;

  @override
  Widget build(BuildContext context) {
    final roles = controller.meta.roles;
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(
            label: 'Идэвхтэй',
            selected: controller.active == true,
            onTap: () =>
                controller.setActive(controller.active == true ? null : true),
          ),
          const SizedBox(width: 6),
          _Chip(
            label: 'Идэвхгүй',
            selected: controller.active == false,
            onTap: () =>
                controller.setActive(controller.active == false ? null : false),
          ),
          if (roles.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(width: 1, color: context.colors.divider),
            const SizedBox(width: 10),
          ],
          for (final r in roles) ...[
            _Chip(
              label: r.name ?? '—',
              selected: controller.roleId == r.id,
              onTap: () =>
                  controller.setRole(controller.roleId == r.id ? null : r.id),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? context.colors.accent.withValues(alpha: 0.14) : null,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        border: Border.all(
          color: onTap == null
              ? context.colors.divider.withValues(alpha: 0.6)
              : selected
              ? context.colors.accent
              : context.colors.divider,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          color: selected
              ? context.colors.accent
              : context.colors.textSecondary,
        ),
      ),
    ),
  );
}

// ─── Empty / footer ──────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.people_outline, size: 56, color: context.colors.textHint),
        const SizedBox(height: 12),
        Text(
          query.isNotEmpty
              ? '"$query" — үр дүн олдсонгүй'
              : 'Ажилтан бүртгэгдээгүй байна',
          style: context.textStyles.body.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});
  final EmployeeListController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final loadMoreError = controller.loadMoreError;
    if (loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton.icon(
          onPressed: controller.loadMore,
          icon: const Icon(Icons.refresh),
          label: Text('Дахин оролдох: ${loadMoreError.display}'),
        ),
      );
    }
    if (controller.hasNext) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton.icon(
          onPressed: controller.loadMore,
          icon: const Icon(Icons.expand_more),
          label: const Text('Дараагийн хуудас'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          'Нийт ${controller.total} ажилтан',
          style: context.textStyles.caption,
        ),
      ),
    );
  }
}

// ─── Employee card ────────────────────────────────────────────────────────

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee, this.onTap});

  final Employee employee;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final e = employee;
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppDimens.radiusLG),
      elevation: AppDimens.cardElevation,
      shadowColor: context.colors.textPrimary.withOpacity(0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: context.colors.accent.withValues(alpha: 0.12),
                child: Text(
                  e.displayName.isNotEmpty ? e.displayName[0] : '?',
                  style: TextStyle(
                    color: context.colors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.displayName,
                            style: context.textStyles.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (e.isOwner)
                          _Badge(
                            label: 'Эзэмшигч',
                            color: context.colors.accent,
                          ),
                        if (!e.isActive)
                          _Badge(
                            label: 'Идэвхгүй',
                            color: context.colors.textHint,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (e.roleName != null)
                      Text(e.roleName!, style: context.textStyles.caption),
                    if (e.phone != null)
                      Text(e.phone!, style: context.textStyles.caption),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: context.colors.textHint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
    ),
    child: Text(label, style: TextStyle(fontSize: 10, color: color)),
  );
}
