import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/widgets/adaptive/async_state_view.dart';
import 'package:carcare_service/core/widgets/adaptive/permission_gate.dart';
import 'package:carcare_service/core/widgets/dialogs/confirm_sheet.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:carcare_service/features/employees/domain/employee.dart';
import 'package:carcare_service/features/employees/domain/employees_repository.dart';
import 'package:carcare_service/features/employees/presentation/controllers/employee_detail_controller.dart';

/// Employee detail — P6-F2.
///
/// Every action button is gated on its own permission through the shared
/// [PermissionGate]/[canSeeView] (D-163): a hidden or disabled action is a
/// UX hint only, never access control — the server enforces every guard
/// (`SELF_DEACTIVATE`, `LAST_OWNER`, `OWNER_ROLE_LOCKED`, `FK_CONFLICT`,
/// `SELF_ACTION`, `PLAN_LIMIT_REACHED`) independently, and this screen shows
/// whatever message/`code` the server returns verbatim rather than
/// pre-guessing which actions are blocked beyond permission-hiding.
///
/// **Reset password never shows, generates, or requests a password** — see
/// [_resetPassword]'s confirmation copy: the employee re-activates their
/// account by completing OTP verification again on next login, exactly as
/// `EmployeesRepository.resetPassword`'s doc comment describes.
///
/// **Not wired to a route** — intended path: `/employees/:id`, reached from
/// [EmployeeListScreen]'s row tap. [onEdit] is a hook (mirrors
/// `CustomerDetailScreen`'s `CustomerEditSheet.show` pattern, but the form
/// screen here is a full push rather than a sheet — see
/// `employee_form_screen.dart`), invoked with the employee id to edit.
class EmployeeDetailScreen extends StatefulWidget {
  const EmployeeDetailScreen({
    super.key,
    required this.employeeId,
    this.repo,
    this.user,
    this.onEdit,
  });

  final String employeeId;
  final EmployeesRepository? repo;
  final User? user;
  final ValueChanged<String>? onEdit;

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  late final EmployeeDetailController _controller;

  User? get _user => widget.user ?? Authenticator.user;

  @override
  void initState() {
    super.initState();
    _controller = EmployeeDetailController(
      employeeId: widget.employeeId,
      repo: widget.repo,
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: _controller,
    child: _Body(user: _user, onEdit: widget.onEdit),
  );
}

class _Body extends StatelessWidget {
  const _Body({required this.user, this.onEdit});

  final User? user;
  final ValueChanged<String>? onEdit;

  Future<void> _toggleActive(
    BuildContext context,
    EmployeeDetailController ctrl,
    Employee employee,
  ) async {
    final nextActive = !employee.isActive;
    final confirmed = await ConfirmSheet.show(
      context,
      title: nextActive ? 'Идэвхжүүлэх үү?' : 'Идэвхгүй болгох уу?',
      message: nextActive
          ? '${employee.displayName}-г дахин идэвхжүүлэх үү?'
          : '${employee.displayName}-г идэвхгүй болгосноор тэр систем рүү нэвтрэх боломжгүй болно.',
      confirmLabel: nextActive ? 'Идэвхжүүлэх' : 'Тийм',
      icon: nextActive ? Icons.check_circle_outline : Icons.block,
      isDangerous: !nextActive,
    );
    if (!confirmed) return;
    final result = await ctrl.toggleActive(nextActive);
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        messageComplete(nextActive ? 'Идэвхжлээ' : 'Идэвхгүй боллоо');
      case Err(:final error):
        messageError(error.display);
    }
  }

  Future<void> _resetPassword(
    BuildContext context,
    EmployeeDetailController ctrl,
    Employee employee,
  ) async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Нууц үг дахин тохируулах уу?',
      message:
          '${employee.displayName}-ийн одоогийн нэвтрэх мэдээлэл цуцлагдана. '
          'Тэрээр дараагийн удаа нэвтрэхдээ утасны дугаараа баталгаажуулж '
          '(OTP) шинээр идэвхжүүлэх шаардлагатай болно. Шинэ нууц үг энд '
          'харагдахгүй.',
      confirmLabel: 'Тийм',
      icon: Icons.lock_reset,
      isDangerous: true,
    );
    if (!confirmed) return;
    final result = await ctrl.resetPassword();
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        messageComplete('Нууц үг дахин тохируулагдлаа');
      case Err(:final error):
        messageError(error.display);
    }
  }

  Future<void> _delete(
    BuildContext context,
    EmployeeDetailController ctrl,
    Employee employee,
  ) async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Ажилтан устгах уу?',
      message: '${employee.displayName}-г устгахдаа итгэлтэй байна уу?',
      confirmLabel: 'Устгах',
      icon: Icons.delete_forever_rounded,
      isDangerous: true,
    );
    if (!confirmed) return;
    final result = await ctrl.delete();
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        messageComplete('Ажилтан устгагдлаа');
        Navigator.of(context).pop();
      case Err(:final error):
        messageError(error.display);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EmployeeDetailController>();
    final employee = ctrl.employee;
    final canEdit = canSeeView(user, 'employees.edit');
    final canDelete = canSeeView(user, 'employees.delete');

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(employee?.displayName ?? 'Ажилтан'),
        actions: [
          PermissionGate(
            permission: 'employees.edit',
            user: user,
            child: IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Засах',
              onPressed: canEdit && employee != null && onEdit != null
                  ? () => onEdit!(employee.id)
                  : null,
            ),
          ),
          PermissionGate(
            permission: 'employees.delete',
            user: user,
            child: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Устгах',
              onPressed: canDelete && employee != null
                  ? () => _delete(context, ctrl, employee)
                  : null,
            ),
          ),
        ],
      ),
      body: AsyncStateView<Employee>(
        state: ctrl.detailState,
        onRetry: ctrl.refresh,
        builder: (context, employee) => RefreshIndicator(
          onRefresh: ctrl.refresh,
          child: ListView(
            padding: const EdgeInsets.all(AppDimens.paddingMD),
            children: [
              _InfoCard(employee: employee),
              const SizedBox(height: 16),
              PermissionGate(
                permission: 'employees.edit',
                user: user,
                child: _ActionTile(
                  icon: employee.isActive
                      ? Icons.block
                      : Icons.check_circle_outline,
                  label: employee.isActive ? 'Идэвхгүй болгох' : 'Идэвхжүүлэх',
                  dangerous: employee.isActive,
                  busy: ctrl.mutating,
                  onTap: () => _toggleActive(context, ctrl, employee),
                ),
              ),
              PermissionGate(
                permission: 'employees.edit',
                user: user,
                child: _ActionTile(
                  icon: Icons.lock_reset,
                  label: 'Нууц үг дахин тохируулах',
                  busy: ctrl.mutating,
                  onTap: () => _resetPassword(context, ctrl, employee),
                ),
              ),
              PermissionGate(
                permission: 'employees.delete',
                user: user,
                child: _ActionTile(
                  icon: Icons.delete_forever_outlined,
                  label: 'Устгах',
                  dangerous: true,
                  busy: ctrl.mutating,
                  onTap: () => _delete(context, ctrl, employee),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    borderRadius: BorderRadius.circular(AppDimens.radiusLG),
    elevation: AppDimens.cardElevation,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(employee.displayName, style: context.textStyles.h3),
              ),
              if (employee.isOwner)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                  ),
                  child: Text(
                    'Эзэмшигч',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.accent,
                    ),
                  ),
                ),
              if (!employee.isActive)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.dangerBg,
                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                  ),
                  child: Text(
                    'Идэвхгүй',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.danger,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.email_outlined, value: employee.email ?? '—'),
          _InfoRow(icon: Icons.phone_outlined, value: employee.phone ?? '—'),
          _InfoRow(
            icon: Icons.badge_outlined,
            value: employee.roleName ?? 'Үүрэггүй',
          ),
          _InfoRow(
            icon: Icons.store_outlined,
            value: employee.branchId == null || employee.branchId!.isEmpty
                ? 'Хуваарилагдаагүй'
                : 'Салбар: ${employee.branchId}',
          ),
          _InfoRow(
            icon: employee.verified
                ? Icons.verified_outlined
                : Icons.hourglass_empty,
            value: employee.verified
                ? 'Идэвхжсэн (OTP баталгаажсан)'
                : 'Идэвхжүүлээгүй — OTP хүлээгдэж байна',
          ),
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: context.colors.textHint),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: context.textStyles.body)),
      ],
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.dangerous = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dangerous;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final color = dangerous
        ? context.colors.danger
        : context.colors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
        child: ListTile(
          enabled: !busy,
          leading: Icon(icon, color: color),
          title: Text(label, style: TextStyle(color: color)),
          trailing: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: onTap,
        ),
      ),
    );
  }
}
