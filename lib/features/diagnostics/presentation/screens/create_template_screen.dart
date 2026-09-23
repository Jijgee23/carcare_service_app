import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/widgets/adaptive/permission_gate.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostic.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:carcare_service/features/diagnostics/presentation/controllers/create_template_controller.dart';

class CreateTemplateScreen extends StatelessWidget {
  const CreateTemplateScreen({
    super.key,
    this.templateId,
    this.repo,
    this.user,
  });

  final String? templateId;
  final DiagnosticTemplateRepository? repo;
  final User? user;

  @override
  Widget build(BuildContext context) {
    final effectiveUser = user ?? Authenticator.user;
    if (!canSeeView(effectiveUser, 'diagnostics.view')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Загвар')),
        body: const EmptyState(
          message: 'Энэ үйлдэлд эрх байхгүй байна',
          icon: Icons.lock_outline,
        ),
      );
    }
    return ChangeNotifierProvider(
      create: (_) =>
          CreateTemplateController(repo: repo, templateId: templateId)..init(),
      child: _Body(user: user),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({this.user});
  final User? user;

  Future<void> _submit(
    BuildContext context,
    CreateTemplateController ctrl,
  ) async {
    final result = await ctrl.submit();
    if (result != null && context.mounted) {
      messageComplete(
        ctrl.templateId == null
            ? 'Загвар амжилттай үүсгэлээ'
            : 'Загвар амжилттай шинэчлэгдлээ',
      );
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CreateTemplateController>();
    final isEditing = ctrl.templateId != null;

    if (ctrl.loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Загвар ачаалж байна')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (ctrl.loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Загвар')),
        body: EmptyState(message: ctrl.loadError!, icon: Icons.error_outline),
      );
    }
    if (ctrl.isSystemDefault) {
      return Scaffold(
        appBar: AppBar(title: Text(ctrl.nameCtrl.text)),
        body: const EmptyState(
          message: 'Системийн загварыг өөрчлөх боломжгүй байна',
          icon: Icons.lock_outline,
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: Text(isEditing ? 'Загвар засах' : 'Загвар үүсгэх')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Үндсэн мэдээлэл ───────────────────────────────────────
            _Card(
              title: 'ҮНДСЭН МЭДЭЭЛЭЛ',
              child: Column(
                children: [
                  _Field(
                    controller: ctrl.nameCtrl,
                    label: 'Нэр',
                    hint: 'Хүлээж авах үзлэг...',
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: ctrl.descCtrl,
                    label: 'Тайлбар',
                    hint: 'Нэмэлт мэдээлэл (заавал биш)',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ─── Төрөл ─────────────────────────────────────────────────
            _Card(
              title: 'ТӨРӨЛ',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DiagnosticType.values
                    .where((t) => t != DiagnosticType.unknown)
                    .map((t) {
                      final active = ctrl.type == t;
                      return GestureDetector(
                        onTap: () => ctrl.setType(t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? _typeColor(t, context).withValues(alpha: 0.12)
                                : context.colors.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active
                                  ? _typeColor(t, context)
                                  : context.colors.divider,
                              width: active ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            t.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: active
                                  ? _typeColor(t, context)
                                  : context.colors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),

            // ─── Тохиргоо ──────────────────────────────────────────────
            _Card(
              title: 'ТОХИРГОО',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Идэвхтэй',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            Text(
                              'Шинэ тайланд харагдана',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: ctrl.isActive,
                        onChanged: ctrl.setIsActive,
                        activeColor: context.colors.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          controller: ctrl.priceCtrl,
                          label: 'Үнэ ₮',
                          hint: '0 (заавал биш)',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Field(
                          controller: ctrl.durationCtrl,
                          label: 'Хугацаа (мин)',
                          hint: '30 (заавал биш)',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ─── Схем бүтэц ────────────────────────────────────────────
            Row(
              children: [
                Text(
                  'СХЕМ БҮТЭЦ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textHint,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  '${ctrl.sections.length} хэсэг',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ...ctrl.sections.asMap().entries.map((e) {
              final idx = e.key;
              final sec = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SectionCard(
                  section: sec,
                  sectionIndex: idx,
                  total: ctrl.sections.length,
                  ctrl: ctrl,
                ),
              );
            }),

            // + Хэсэг нэмэх
            GestureDetector(
              onTap: ctrl.addSection,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: context.colors.accent.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.colors.accent.withOpacity(0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                      color: context.colors.accent,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Хэсэг нэмэх',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ─── Bottom submit bar ────────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          boxShadow: [
            BoxShadow(
              color: context.colors.textPrimary.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SizedBox(
          height: 50,
          child: PermissionGate(
            permission: isEditing ? 'diagnostics.edit' : 'diagnostics.create',
            user: user,
            child: ElevatedButton(
              onPressed: ctrl.canSubmit ? () => _submit(context, ctrl) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accent,
                foregroundColor: CarCareTheme.of(context).onAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                disabledBackgroundColor: context.colors.accent.withOpacity(
                  0.35,
                ),
              ),
              child: ctrl.submitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: CarCareTheme.of(context).onAccent,
                      ),
                    )
                  : Text(
                      isEditing ? 'Өөрчлөлт хадгалах' : 'Загвар үүсгэх',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Section card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final TemplateSectionDraft section;
  final int sectionIndex;
  final int total;
  final CreateTemplateController ctrl;

  const _SectionCard({
    required this.section,
    required this.sectionIndex,
    required this.total,
    required this.ctrl,
  });

  Future<void> _openItemSheet(
    BuildContext context, {
    TemplateItemDraft? editing,
  }) async {
    final result = await showModalBottomSheet<TemplateItemDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemEditSheet(
        initial: editing ?? ctrl.newItem(),
        priorItems: ctrl.priorCheckItems(section.id, editing?.id ?? ''),
      ),
    );
    if (result == null) return;
    if (editing != null) {
      ctrl.updateItem(section.id, result);
    } else {
      ctrl.addItem(section.id, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.colors.textPrimary.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${sectionIndex + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.colors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: section.titleCtrl,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Хэсгийн гарчиг...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: context.colors.textHint,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                // Reorder + delete
                if (total > 1) ...[
                  _IconBtn(
                    icon: Icons.keyboard_arrow_up_rounded,
                    onTap: sectionIndex > 0
                        ? () => ctrl.moveSectionUp(section.id)
                        : null,
                  ),
                  _IconBtn(
                    icon: Icons.keyboard_arrow_down_rounded,
                    onTap: sectionIndex < total - 1
                        ? () => ctrl.moveSectionDown(section.id)
                        : null,
                  ),
                ],
                _IconBtn(
                  icon: Icons.delete_outline_rounded,
                  color: context.colors.danger,
                  onTap: () => ctrl.removeSection(section.id),
                ),
              ],
            ),
          ),

          const Divider(height: 16, thickness: 1, indent: 14, endIndent: 14),

          // Items
          if (section.items.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Асуулт байхгүй байна',
                style: TextStyle(fontSize: 13, color: context.colors.textHint),
              ),
            )
          else
            ...section.items.asMap().entries.map((e) {
              final itemIdx = e.key;
              final item = e.value;
              return _ItemRow(
                item: item,
                itemIndex: itemIdx,
                total: section.items.length,
                onEdit: () => _openItemSheet(context, editing: item),
                onDelete: () => ctrl.removeItem(section.id, item.id),
                onMoveUp: itemIdx > 0
                    ? () => ctrl.moveItemUp(section.id, item.id)
                    : null,
                onMoveDown: itemIdx < section.items.length - 1
                    ? () => ctrl.moveItemDown(section.id, item.id)
                    : null,
              );
            }),

          // Add item button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: GestureDetector(
              onTap: () => _openItemSheet(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: context.colors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.colors.divider),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: context.colors.textSecondary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Асуулт нэмэх',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Item row ─────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final TemplateItemDraft item;
  final int itemIndex;
  final int total;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _ItemRow({
    required this.item,
    required this.itemIndex,
    required this.total,
    required this.onEdit,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            // Index dot
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: context.colors.textHint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label.isEmpty ? '(гарчиг оруулаагүй)' : item.label,
                    style: TextStyle(
                      fontSize: 13,
                      color: item.label.isEmpty
                          ? context.colors.textHint
                          : context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _TypeBadge(item.type),
                      if (item.isRequired) ...[
                        const SizedBox(width: 4),
                        _Badge(
                          'Заавал',
                          context.colors.danger.withOpacity(0.1),
                          context.colors.danger,
                        ),
                      ],
                      if (item.positionSet != null) ...[
                        const SizedBox(width: 4),
                        _Badge(
                          item.positionSet!.name,
                          context.colors.accent.withOpacity(0.1),
                          context.colors.accent,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (total > 1) ...[
              _IconBtn(
                icon: Icons.keyboard_arrow_up_rounded,
                size: 18,
                onTap: onMoveUp,
              ),
              _IconBtn(
                icon: Icons.keyboard_arrow_down_rounded,
                size: 18,
                onTap: onMoveDown,
              ),
            ],
            _IconBtn(
              icon: Icons.delete_outline_rounded,
              size: 18,
              color: context.colors.danger,
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Item edit sheet ──────────────────────────────────────────────────────────

class _ItemEditSheet extends StatefulWidget {
  final TemplateItemDraft initial;
  final List<TemplateItemDraft> priorItems;
  const _ItemEditSheet({required this.initial, required this.priorItems});

  @override
  State<_ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends State<_ItemEditSheet> {
  late final TextEditingController _labelCtrl;
  late ItemType _type;
  late bool _isRequired;
  late PositionSetKey? _positionSet;
  late List<String> _options;
  String? _showWhenItemId;
  final Set<String> _showWhenValues = {};

  final List<TextEditingController> _optionCtrls = [];

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _labelCtrl = TextEditingController(text: i.label);
    _type = i.type;
    _isRequired = i.isRequired;
    _positionSet = i.positionSet;
    _options = List.of(
      i.type == ItemType.check && i.options.isEmpty
          ? i.effectiveOptions
          : i.options,
    );
    final source = widget.priorItems
        .where((item) => item.id == i.showWhen?.itemId)
        .firstOrNull;
    _showWhenItemId = source?.id;
    if (source != null) {
      _showWhenValues.addAll(
        (i.showWhen?.values ?? const []).where(
          (value) => source.effectiveOptions.contains(value),
        ),
      );
    }
    for (final o in _options) {
      _optionCtrls.add(TextEditingController(text: o));
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _options.add('');
      _optionCtrls.add(TextEditingController());
    });
  }

  void _removeOption(int idx) {
    setState(() {
      _optionCtrls[idx].dispose();
      _options.removeAt(idx);
      _optionCtrls.removeAt(idx);
    });
  }

  void _confirm() {
    final options = _optionCtrls
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    Navigator.pop(
      context,
      widget.initial.copyWith(
        label: _labelCtrl.text.trim(),
        type: _type,
        isRequired: _isRequired,
        options: _type == ItemType.check ? options : [],
        positionSet: _positionSet,
        clearPositionSet: _positionSet == null,
        showWhen: _showWhenItemId == null || _showWhenValues.isEmpty
            ? null
            : ShowWhen(
                itemId: _showWhenItemId!,
                values: _showWhenValues.toList(),
              ),
        clearShowWhen: _showWhenItemId == null || _showWhenValues.isEmpty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Асуулт тохируулах',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Label
            const _SheetLabel('Асуултын гарчиг'),
            const SizedBox(height: 6),
            TextField(
              controller: _labelCtrl,
              autofocus: true,
              decoration: _inputDec(context, 'Жишээ: Тос шалгах...'),
            ),
            const SizedBox(height: 16),

            // Type
            const _SheetLabel('Хариултын төрөл'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ItemType.values.where((t) => t != ItemType.unknown).map(
                (t) {
                  final active = _type == t;
                  return GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? context.colors.accent.withOpacity(0.1)
                            : context.colors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? context.colors.accent
                              : context.colors.divider,
                          width: active ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _typeIcon(t),
                            size: 14,
                            color: active
                                ? context.colors.accent
                                : context.colors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _typeLabel(t),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: active
                                  ? context.colors.accent
                                  : context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ).toList(),
            ),
            const SizedBox(height: 16),

            // Options (check only)
            if (_type == ItemType.check) ...[
              Row(
                children: [
                  const _SheetLabel('Сонголтууд'),
                  const Spacer(),
                  GestureDetector(
                    onTap: _addOption,
                    child: Text(
                      '+ Нэмэх',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._optionCtrls.asMap().entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: e.value,
                          decoration: _inputDec(context, 'Сонголт...'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (_optionCtrls.length > 1)
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: context.colors.danger,
                          ),
                          onPressed: () => _removeOption(e.key),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],

            // Position set
            if (_type != ItemType.photo && _type != ItemType.signature) ...[
              const _SheetLabel('Байрлалаар давтах'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _posChip(null, 'Байхгүй'),
                  ...PositionSetKey.values.map((p) => _posChip(p, p.name)),
                ],
              ),
              const SizedBox(height: 16),
            ],

            if (widget.priorItems.isNotEmpty) ...[
              const _SheetLabel('Өмнөх сонголтоос хамаарах'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: _showWhenItemId,
                decoration: _inputDec(context, 'Хамааралгүй'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Хамааралгүй'),
                  ),
                  ...widget.priorItems.map(
                    (item) => DropdownMenuItem<String?>(
                      value: item.id,
                      child: Text(item.label),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _showWhenItemId = value;
                  _showWhenValues.clear();
                }),
              ),
              if (_showWhenItemId != null) ...[
                const SizedBox(height: 8),
                ...widget.priorItems
                    .where((item) => item.id == _showWhenItemId)
                    .expand((item) => item.effectiveOptions)
                    .map(
                      (value) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(value),
                        value: _showWhenValues.contains(value),
                        onChanged: (selected) => setState(() {
                          if (selected == true) {
                            _showWhenValues.add(value);
                          } else {
                            _showWhenValues.remove(value);
                          }
                        }),
                      ),
                    ),
              ],
              const SizedBox(height: 12),
            ],

            // Required toggle
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Заавал бөглөх',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Тайланд заавал оруулна',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isRequired,
                  onChanged: (v) => setState(() => _isRequired = v),
                  activeColor: context.colors.accent,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Confirm
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _labelCtrl.text.trim().isEmpty ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.accent,
                  foregroundColor: CarCareTheme.of(context).onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: context.colors.accent.withOpacity(
                    0.35,
                  ),
                ),
                child: Text(
                  'Хадгалах',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CarCareTheme.of(context).onAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _posChip(PositionSetKey? key, String label) {
    final active = _positionSet == key;
    return GestureDetector(
      onTap: () => setState(() => _positionSet = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? context.colors.accent.withOpacity(0.1)
              : context.colors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? context.colors.accent : context.colors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active
                ? context.colors.accent
                : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.colors.textPrimary.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.colors.textHint,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: context.colors.textHint, fontSize: 13),
        filled: true,
        fillColor: context.colors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.colors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.colors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.colors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final double size;

  const _IconBtn({required this.icon, this.onTap, this.color, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        icon,
        size: size,
        color: onTap == null
            ? context.colors.divider
            : (color ?? context.colors.textHint),
      ),
      onPressed: onTap,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final ItemType type;
  const _TypeBadge(this.type);

  @override
  Widget build(BuildContext context) {
    return _Badge(
      _typeLabel(type),
      context.colors.accent.withOpacity(0.08),
      context.colors.accent,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Badge(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;
  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: context.colors.textSecondary,
      ),
    );
  }
}

InputDecoration _inputDec(BuildContext context, String hint) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: context.colors.textHint, fontSize: 13),
  filled: true,
  fillColor: context.colors.background,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: context.colors.divider),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: context.colors.divider),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: context.colors.accent, width: 1.5),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
);

String _typeLabel(ItemType t) => switch (t) {
  ItemType.check => 'Сонголт',
  ItemType.text => 'Текст',
  ItemType.number => 'Тоо',
  ItemType.photo => 'Зураг',
  ItemType.signature => 'Гарын үсэг',
  ItemType.unknown => 'Тодорхойгүй',
};

IconData _typeIcon(ItemType t) => switch (t) {
  ItemType.check => Icons.check_circle_outline_rounded,
  ItemType.text => Icons.short_text_rounded,
  ItemType.number => Icons.pin_rounded,
  ItemType.photo => Icons.photo_camera_outlined,
  ItemType.signature => Icons.draw_outlined,
  ItemType.unknown => Icons.help_outline_rounded,
};

Color _typeColor(DiagnosticType type, BuildContext context) => switch (type) {
  DiagnosticType.INTAKE => CarCareTheme.of(context).accentHi,
  DiagnosticType.POST_SERVICE => CarCareTheme.of(context).ok,
  DiagnosticType.ROUTINE => context.colors.accent,
  DiagnosticType.DAMAGE_REPORT => CarCareTheme.of(context).warn,
  DiagnosticType.unknown => context.colors.textHint,
};
