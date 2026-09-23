import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/widgets/adaptive/async_state_view.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/features/roles/domain/permission.dart';
import 'package:carcare_service/features/roles/domain/permission_catalog_repository.dart';
import 'package:carcare_service/features/roles/domain/role.dart';
import 'package:carcare_service/features/roles/domain/roles_repository.dart';
import 'package:carcare_service/features/roles/presentation/controllers/role_form_controller.dart';

/// Create/edit form for a role — P6-F3.
///
/// **Not registered by this slice** — see `role_list_screen.dart`'s doc
/// comment. Intended route paths (`P6-F5`): `/roles/new` and
/// `/roles/:id/edit`, both owner-gated.
///
/// The permission picker renders **only** from [PermissionCatalogRepository]
/// (`RoleFormController.catalog`) — grouped sections with a group
/// select-all checkbox (tri-state: fully/partially/un-selected), plus a
/// standalone section for ungrouped items. No permission code is written
/// literally anywhere in this file.
class RoleFormScreen extends StatelessWidget {
  const RoleFormScreen({
    super.key,
    this.existing,
    this.rolesRepository,
    this.catalogRepository,
    this.onSaved,
  });

  /// `null` → create mode.
  final Role? existing;
  final RolesRepository? rolesRepository;
  final PermissionCatalogRepository? catalogRepository;

  /// Called after a successful save. The screen itself does not pop or
  /// navigate — routing/back-stack decisions belong to whatever wires this
  /// screen in (`P6-F5`), matching `ServiceListScreen`'s hook convention.
  final VoidCallback? onSaved;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => RoleFormController(
      existing: existing,
      rolesRepo: rolesRepository,
      catalogRepo: catalogRepository,
    )..init(),
    child: _Body(isEditing: existing != null, onSaved: onSaved),
  );
}

class _Body extends StatefulWidget {
  const _Body({required this.isEditing, this.onSaved});
  final bool isEditing;
  final VoidCallback? onSaved;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  String? _nameError;
  String? _permissionsError;

  @override
  void initState() {
    super.initState();
    final controller = context.read<RoleFormController>();
    _nameController = TextEditingController(text: controller.existing?.name);
    _descriptionController = TextEditingController(
      text: controller.existing?.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit(RoleFormController controller) async {
    final name = _nameController.text.trim();
    setState(() {
      _nameError = name.isEmpty
          ? 'Нэрээ оруулна уу.'
          : name.length > 60
          ? 'Нэр 60 тэмдэгтээс хэтрэхгүй байх ёстой.'
          : null;
      _permissionsError = controller.hasAtLeastOnePermission
          ? null
          : 'Дор хаяж нэг эрх сонгоно уу.';
    });
    if (_nameError != null || _permissionsError != null) return;

    final ok = await controller.submit(
      name: name,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      widget.onSaved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RoleFormController>();
    final fieldErrors = controller.fieldErrors;
    final serverError = controller.lastError;
    final generalError = serverError != null && fieldErrors.isEmpty
        ? serverError.display
        : null;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Үүрэг засах' : 'Шинэ үүрэг'),
      ),
      body: AsyncStateView<PermissionCatalog>(
        state: controller.loadingCatalog
            ? const AsyncLoading()
            : (controller.catalogError != null
                  ? AsyncError(controller.catalogError!)
                  : AsyncData(controller.catalog)),
        onRetry: controller.init,
        builder: (context, catalog) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (generalError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.dangerBg,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                  ),
                  child: Text(
                    generalError,
                    style: TextStyle(color: context.colors.danger),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                key: const ValueKey('role_name_field'),
                controller: _nameController,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: 'Нэр',
                  errorText: _nameError ?? fieldErrors['name'],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('role_description_field'),
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Тайлбар',
                  errorText: fieldErrors['description'],
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const ValueKey('role_active_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Идэвхтэй'),
                value: controller.isActive,
                onChanged: controller.setIsActive,
              ),
              const SizedBox(height: 12),
              Text('Эрхүүд', style: context.textStyles.bodyMedium),
              const SizedBox(height: 4),
              if (_permissionsError != null ||
                  fieldErrors['permissions'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    _permissionsError ?? fieldErrors['permissions']!,
                    style: TextStyle(
                      color: context.colors.danger,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (controller.orderScopeHint != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: context.colors.warning,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          controller.orderScopeHint!,
                          style: TextStyle(
                            color: context.colors.warning,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (fieldErrors['orderScopes'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    fieldErrors['orderScopes']!,
                    style: TextStyle(
                      color: context.colors.danger,
                      fontSize: 12,
                    ),
                  ),
                ),
              for (final group in catalog.groups)
                _PermissionGroupSection(group: group, controller: controller),
              if (catalog.standalone.isNotEmpty)
                _PermissionGroupSection(
                  group: PermissionGroup(
                    group: null,
                    items: catalog.standalone,
                  ),
                  controller: controller,
                  title: 'Бусад',
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('role_submit_button'),
                  onPressed: controller.submitting
                      ? null
                      : () => _submit(controller),
                  child: controller.submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.isEditing ? 'Хадгалах' : 'Үүсгэх'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionGroupSection extends StatelessWidget {
  const _PermissionGroupSection({
    required this.group,
    required this.controller,
    this.title,
  });

  final PermissionGroup group;
  final RoleFormController controller;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final items = group.items;
    final fullySelected = controller.isGroupFullySelected(items);
    final partiallySelected = controller.isGroupPartiallySelected(items);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: context.colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            key: ValueKey(
              'role_group_select_all_${group.group ?? "standalone"}',
            ),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              title ?? group.group ?? '—',
              style: context.textStyles.bodyMedium,
            ),
            tristate: true,
            value: fullySelected ? true : (partiallySelected ? null : false),
            onChanged: (value) => controller.toggleGroup(items, value != false),
          ),
          const Divider(height: 1),
          for (final item in items)
            CheckboxListTile(
              key: ValueKey('role_permission_${item.code}'),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: Text(item.label ?? item.code),
              subtitle: item.description != null
                  ? Text(item.description!)
                  : null,
              value: controller.isSelected(item.code),
              onChanged: (value) =>
                  controller.toggle(item.code, value ?? false),
            ),
        ],
      ),
    );
  }
}
