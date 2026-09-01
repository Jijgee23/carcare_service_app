import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/models/diagnostic.dart';
import 'package:carcare_service/features/presentation/controllers/create_template_controller.dart';
import 'package:carcare_service/shared/widgets/dialogs/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class CreateTemplateScreen extends StatelessWidget {
  const CreateTemplateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreateTemplateController()..init(),
      child: const _Body(),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body();

  Future<void> _submit(BuildContext context, CreateTemplateController ctrl) async {
    final result = await ctrl.submit();
    if (result != null && context.mounted) {
      messageComplete('Загвар амжилттай үүсгэлээ');
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CreateTemplateController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Загвар үүсгэх')),
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
                children: DiagnosticType.values.map((t) {
                  final active = ctrl.type == t;
                  return GestureDetector(
                    onTap: () => ctrl.setType(t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? t.bgColor : AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? t.color : AppColors.divider,
                          width: active ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        t.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                          color: active ? t.color : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Идэвхтэй',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary)),
                            Text('Шинэ тайланд харагдана',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Switch(
                        value: ctrl.isActive,
                        onChanged: ctrl.setIsActive,
                        activeColor: AppColors.accent,
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
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
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
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                const Text(
                  'СХЕМ БҮТЭЦ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHint,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  '${ctrl.sections.length} хэсэг',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                  color: AppColors.accent.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.accent.withOpacity(0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.accent),
                    SizedBox(width: 6),
                    Text(
                      'Хэсэг нэмэх',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
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
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -3)),
          ],
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: ctrl.canSubmit ? () => _submit(context, ctrl) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              disabledBackgroundColor: AppColors.accent.withOpacity(0.35),
            ),
            child: ctrl.submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Загвар үүсгэх',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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

  Future<void> _openItemSheet(BuildContext context, {TemplateItemDraft? editing}) async {
    final result = await showModalBottomSheet<TemplateItemDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemEditSheet(initial: editing ?? ctrl.newItem()),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
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
                    color: AppColors.accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${sectionIndex + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: section.titleCtrl,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Хэсгийн гарчиг...',
                      hintStyle: TextStyle(fontSize: 14, color: AppColors.textHint),
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
                    onTap: sectionIndex > 0 ? () => ctrl.moveSectionUp(section.id) : null,
                  ),
                  _IconBtn(
                    icon: Icons.keyboard_arrow_down_rounded,
                    onTap:
                        sectionIndex < total - 1 ? () => ctrl.moveSectionDown(section.id) : null,
                  ),
                ],
                _IconBtn(
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.danger,
                  onTap: () => ctrl.removeSection(section.id),
                ),
              ],
            ),
          ),

          const Divider(height: 16, thickness: 1, indent: 14, endIndent: 14),

          // Items
          if (section.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Асуулт байхгүй байна',
                style: TextStyle(fontSize: 13, color: AppColors.textHint),
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
                onMoveUp: itemIdx > 0 ? () => ctrl.moveItemUp(section.id, item.id) : null,
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
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: AppColors.textSecondary),
                    SizedBox(width: 4),
                    Text(
                      'Асуулт нэмэх',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
              decoration: const BoxDecoration(color: AppColors.textHint, shape: BoxShape.circle),
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
                      color: item.label.isEmpty ? AppColors.textHint : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _TypeBadge(item.type),
                      if (item.isRequired) ...[
                        const SizedBox(width: 4),
                        _Badge('Заавал', AppColors.danger.withOpacity(0.1), AppColors.danger),
                      ],
                      if (item.positionSet != null) ...[
                        const SizedBox(width: 4),
                        _Badge(
                          item.positionSet!.name,
                          AppColors.accent.withOpacity(0.1),
                          AppColors.accent,
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
              color: AppColors.danger,
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
  const _ItemEditSheet({required this.initial});

  @override
  State<_ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends State<_ItemEditSheet> {
  late final TextEditingController _labelCtrl;
  late ItemType _type;
  late bool _isRequired;
  late PositionSetKey? _positionSet;
  late List<String> _options;

  final List<TextEditingController> _optionCtrls = [];

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _labelCtrl = TextEditingController(text: i.label);
    _type = i.type;
    _isRequired = i.isRequired;
    _positionSet = i.positionSet;
    _options = List.of(i.options);
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
    final options = _optionCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    Navigator.pop(
      context,
      widget.initial.copyWith(
        label: _labelCtrl.text.trim(),
        type: _type,
        isRequired: _isRequired,
        options: _type == ItemType.check ? options : [],
        positionSet: _positionSet,
        clearPositionSet: _positionSet == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
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
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Асуулт тохируулах',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),

            // Label
            const _SheetLabel('Асуултын гарчиг'),
            const SizedBox(height: 6),
            TextField(
              controller: _labelCtrl,
              autofocus: true,
              decoration: _inputDec('Жишээ: Тос шалгах...'),
            ),
            const SizedBox(height: 16),

            // Type
            const _SheetLabel('Хариултын төрөл'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ItemType.values.map((t) {
                final active = _type == t;
                return GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? AppColors.accent.withOpacity(0.1) : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? AppColors.accent : AppColors.divider,
                        width: active ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_typeIcon(t), size: 14,
                            color: active ? AppColors.accent : AppColors.textSecondary),
                        const SizedBox(width: 5),
                        Text(
                          _typeLabel(t),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                            color: active ? AppColors.accent : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
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
                    child: const Text(
                      '+ Нэмэх',
                      style: TextStyle(fontSize: 12, color: AppColors.accent),
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
                          decoration: _inputDec('Сонголт...'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (_optionCtrls.length > 1)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.danger),
                          onPressed: () => _removeOption(e.key),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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

            // Required toggle
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Заавал бөглөх',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      Text('Тайланд заавал оруулна',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Switch(
                  value: _isRequired,
                  onChanged: (v) => setState(() => _isRequired = v),
                  activeColor: AppColors.accent,
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
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: AppColors.accent.withOpacity(0.35),
                ),
                child: const Text('Хадгалах', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
          color: active ? AppColors.accent.withOpacity(0.1) : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? AppColors.accent : AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? AppColors.accent : AppColors.textSecondary,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
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
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final double size;

  const _IconBtn({
    required this.icon,
    this.onTap,
    this.color = AppColors.textHint,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: size, color: onTap == null ? AppColors.divider : color),
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
    return _Badge(_typeLabel(type), AppColors.accent.withOpacity(0.08), AppColors.accent);
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
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
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
    );
  }
}

InputDecoration _inputDec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );

String _typeLabel(ItemType t) => switch (t) {
      ItemType.check => 'Сонголт',
      ItemType.text => 'Текст',
      ItemType.number => 'Тоо',
      ItemType.photo => 'Зураг',
      ItemType.signature => 'Гарын үсэг',
    };

IconData _typeIcon(ItemType t) => switch (t) {
      ItemType.check => Icons.check_circle_outline_rounded,
      ItemType.text => Icons.short_text_rounded,
      ItemType.number => Icons.pin_rounded,
      ItemType.photo => Icons.photo_camera_outlined,
      ItemType.signature => Icons.draw_outlined,
    };
