import 'package:carservice_business/features/services/domain/services_repository.dart';
import 'package:carservice_business/core/domain/user.dart';
import 'package:carservice_business/core/services/auth_storage.dart';
import 'package:carservice_business/core/utils/price_input.dart';
import 'package:carservice_business/core/widgets/adaptive/permission_gate.dart';
import 'package:carservice_business/core/widgets/common/common_widgets.dart';
import 'package:carservice_business/core/widgets/app_dropdown.dart';
import 'package:carservice_business/app/theme/app_theme.dart';
import 'package:carservice_business/features/diagnostics/domain/diagnostic.dart';
import 'package:carservice_business/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carservice_business/features/diagnostics/presentation/widgets/template_preview.dart';
import 'package:carservice_business/features/diagnostics/presentation/widgets/template_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:carservice_business/core/widgets/dialogs/message.dart';
import 'package:carservice_business/features/diagnostics/presentation/controllers/create_template_controller.dart';
import 'package:carservice_business/core/navigation/app_nav.dart';

/// Create, edit or view one diagnostic service — the web's
/// `app/dashboard/services/diagnostics/{new,[id]}` pages: three numbered
/// panels (basic details, page structure, fill preview) above a sticky save
/// bar. System templates open as a preview only.
class CreateTemplateScreen extends StatelessWidget {
  const CreateTemplateScreen({
    super.key,
    this.templateId,
    this.repo,
    this.user,
    this.categoriesRepo,
  });

  final String? templateId;
  final DiagnosticTemplateRepository? repo;
  final User? user;

  /// Category list source; tests inject a fake.
  final ServicesRepository? categoriesRepo;

  @override
  Widget build(BuildContext context) {
    final effectiveUser = user ?? Authenticator.user;
    if (!canSeeView(effectiveUser, 'diagnostics.view')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Оношилгоо')),
        body: const EmptyState(
          message: 'Энэ үйлдэлд эрх байхгүй байна',
          icon: Icons.lock_outline,
        ),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => CreateTemplateController(
        repo: repo,
        categoriesRepo: categoriesRepo,
        templateId: templateId,
      )..init(),
      child: _Body(user: effectiveUser),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({this.user});
  final User? user;

  Future<void> _submit(CreateTemplateController ctrl) async {
    final result = await ctrl.submit();
    if (result == null) return;
    messageComplete(
      ctrl.isEditing ? 'Оношилгоо хадгалагдлаа' : 'Оношилгоо үүсгэгдлээ',
    );
    AppNav.back(result);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CreateTemplateController>();
    final theme = CarserviceTheme.of(context);

    if (ctrl.loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Оношилгоо')),
        body: const AppLoading(),
      );
    }
    if (ctrl.loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Оношилгоо')),
        body: EmptyState(message: ctrl.loadError!, icon: Icons.error_outline),
      );
    }

    final title = !ctrl.isEditing
        ? 'Шинэ оношилгоо'
        : ctrl.readOnly
        ? 'Оношилгоо харах'
        : 'Оношилгоо засах';
    final subtitle = ctrl.isEditing
        ? 'v${ctrl.version ?? 1} · ${ctrl.nameCtrl.text}'
        : 'Үнэ, хугацаа, асуултуудаа тохируулж оношилгооны үйлчилгээгээ '
              'үүсгэнэ үү';

    return Scaffold(
      backgroundColor: theme.shellBackground,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        key: const ValueKey('template_editor_scroll'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            subtitle,
            style: context.textStyles.caption.copyWith(color: theme.mutedText3),
          ),
          const SizedBox(height: 12),
          if (ctrl.formError != null) ...[
            _Banner(message: ctrl.formError!, color: theme.danger),
            const SizedBox(height: 12),
          ],
          if (ctrl.readOnly) ...[
            _Banner(
              message: ctrl.isShared
                  ? 'Энэ бол системийн сан загвар — платформын админ удирддаг, '
                        'засах, устгах боломжгүй. Өөрчлөх шаардлагатай бол '
                        'жагсаалтаас Хуулах дарж хувь эх үүсгэн, тэрийг '
                        'засаарай.'
                  : 'Энэ бол системийн үндсэн загвар — шинэ байгууллага бүрт '
                        'автоматаар үүсдэг тул засах, устгах боломжгүй. Өөрчлөх '
                        'шаардлагатай бол жагсаалтаас Хуулах дарж хувь эх '
                        'үүсгэн, тэрийг засаарай.',
              color: theme.accent,
            ),
            const SizedBox(height: 12),
            _Panel(child: TemplatePreview(schema: ctrl.schema)),
          ] else ...[
            _Panel(
              index: 1,
              title: 'Үндсэн мэдээлэл',
              child: _BasicFields(ctrl: ctrl),
            ),
            const SizedBox(height: 12),
            _Panel(
              index: 2,
              title: 'Хуудасны бүтэц',
              action: TextButton.icon(
                key: const ValueKey('template_add_section'),
                onPressed: ctrl.addSection,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Хэсэг нэмэх'),
              ),
              child: _Structure(ctrl: ctrl),
            ),
            const SizedBox(height: 12),
            const _PreviewPanel(),
          ],
        ],
      ),
      bottomNavigationBar: ctrl.readOnly
          ? null
          : _SaveBar(
              dirty: ctrl.dirty,
              submitting: ctrl.submitting,
              label: ctrl.isEditing ? 'Хадгалах' : 'Үүсгэх',
              permission: ctrl.isEditing
                  ? 'diagnostics.edit'
                  : 'diagnostics.create',
              user: user,
              onSubmit: ctrl.canSubmit ? () => _submit(ctrl) : null,
            ),
    );
  }
}

// ─── Panels ───────────────────────────────────────────────────────────────────

/// The web's `SectionPanel`: a flat bordered block, numbered "01 / 03".
class _Panel extends StatelessWidget {
  const _Panel({this.index, this.title, this.action, required this.child});

  final int? index;
  final String? title;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final index = this.index;
    return _Surface(
      color: theme.panel,
      radius: AppDimens.radiusMD,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: context.textStyles.h3.copyWith(color: theme.ink),
                  ),
                ),
                if (index != null)
                  Text(
                    '${'$index'.padLeft(2, '0')} / 03',
                    style: TextStyle(
                      fontFamily: theme.monoFontFamily,
                      fontSize: 11,
                      color: theme.mutedText3,
                    ),
                  ),
              ],
            ),
            if (action != null)
              Align(alignment: Alignment.centerRight, child: action),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// A flat bordered surface that ink (buttons, list tiles) can paint on.
class _Surface extends StatelessWidget {
  const _Surface({
    required this.color,
    required this.radius,
    required this.padding,
    required this.child,
    this.margin = EdgeInsets.zero,
  });

  final Color color;
  final double radius;
  final EdgeInsetsGeometry padding, margin;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: margin,
    child: Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: CarserviceTheme.of(context).border),
      ),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppDimens.radiusMD),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      message,
      style: context.textStyles.caption.copyWith(
        color: CarserviceTheme.of(context).ink2,
      ),
    ),
  );
}

/// A labelled form row, the web's `Field`: label, input, then the error or
/// the hint beneath.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.child,
    this.hint,
    this.error,
  });

  final String label;
  final Widget child;
  final String? hint;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final note = error ?? hint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: context.textStyles.captionMedium.copyWith(color: theme.ink2),
        ),
        const SizedBox(height: 6),
        child,
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(
            note,
            style: context.textStyles.caption.copyWith(
              color: error != null ? theme.danger : theme.mutedText3,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── 01 · Basic details ───────────────────────────────────────────────────────

class _BasicFields extends StatelessWidget {
  const _BasicFields({required this.ctrl});
  final CreateTemplateController ctrl;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final errors = ctrl.fieldErrors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
          label: 'Хуудасны нэр',
          error: errors['name'],
          child: TextField(
            key: const ValueKey('template_name'),
            controller: ctrl.nameCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Жишээ: Машин хүлээж авах ерөнхий үзлэг',
            ),
          ),
        ),
        const SizedBox(height: 14),
        _CategoryField(ctrl: ctrl),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Field(
                label: 'Үнэ (₮)',
                hint: 'засварын хуудсанд автоматаар буух',
                error: errors['price'],
                child: TextField(
                  key: const ValueKey('template_price'),
                  controller: ctrl.priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [PriceInputFormatter()],
                  onEditingComplete: () {
                    ctrl.priceCtrl.text = formatPriceInput(ctrl.priceCtrl.text);
                    FocusScope.of(context).nextFocus();
                  },
                  decoration: const InputDecoration(hintText: '25,000'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Field(
                label: 'Дундаж хугацаа (минут)',
                hint: 'засварын хуудасны тооцоо',
                error: errors['durationMin'],
                child: TextField(
                  key: const ValueKey('template_duration'),
                  controller: ctrl.durationCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: '30'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Field(
          label: 'Тайлбар',
          child: TextField(
            key: const ValueKey('template_description'),
            controller: ctrl.descCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Энэ загварыг хэзээ хэрэглэх вэ?',
            ),
          ),
        ),
        const SizedBox(height: 14),
        _Field(
          label: 'Төрөл',
          error: errors['type'],
          child: Column(
            children: [
              for (final type in DiagnosticType.selectable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TypeOption(
                    type: type,
                    selected: ctrl.type == type,
                    onTap: () => ctrl.setType(type),
                  ),
                ),
            ],
          ),
        ),
        CheckboxListTile(
          key: const ValueKey('template_active'),
          value: ctrl.isActive,
          onChanged: (value) => ctrl.setIsActive(value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            'Идэвхтэй (засварын хуудсан дээр сонгох боломжтой)',
            style: context.textStyles.body.copyWith(color: theme.ink2),
          ),
        ),
      ],
    );
  }
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({required this.ctrl});
  final CreateTemplateController ctrl;

  @override
  Widget build(BuildContext context) {
    final options = ctrl.selectableCategories;
    final String? hint;
    final Widget input;
    if (ctrl.categoriesLoading && ctrl.categories.isEmpty) {
      hint = null;
      input = const LinearProgressIndicator();
    } else if (ctrl.categoriesError != null) {
      hint = ctrl.categoriesError;
      input = OutlinedButton.icon(
        onPressed: ctrl.loadCategories,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Ангилал дахин ачаалах'),
      );
    } else {
      hint = options.isEmpty ? 'Үйлчилгээ → Ангилалд эхлээд бүртгээрэй.' : null;
      input = AppDropdown<String>(
        key: const ValueKey('template_category'),
        value: ctrl.categoryId,
        hint: '— Ангилал —',
        items: [
          for (final category in options)
            AppDropdownItem(
              value: category.id,
              label: category.isActive
                  ? category.name ?? ''
                  : '${category.name ?? ''} (идэвхгүй)',
            ),
        ],
        onChanged: ctrl.setCategory,
      );
    }
    return _Field(
      label: 'Ангилал',
      hint: hint,
      error: ctrl.fieldErrors['categoryId'],
      child: input,
    );
  }
}

/// One of the four types, as the web's radio card: label and what it is for.
class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final DiagnosticType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final radius = BorderRadius.circular(AppDimens.radiusSM);
    return Material(
      color: selected ? theme.accent.withValues(alpha: 0.1) : theme.panel2,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? theme.accent.withValues(alpha: 0.4) : theme.border,
        ),
      ),
      child: InkWell(
        key: ValueKey('template_type_${type.name}'),
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 10),
          child: Row(
            children: [
              IgnorePointer(
                child: Radio<bool>(
                  value: true,
                  groupValue: selected,
                  onChanged: (_) {},
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: templateTypeColor(context, type),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          type.label,
                          style: context.textStyles.bodyMedium.copyWith(
                            color: theme.ink2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      type.description,
                      style: context.textStyles.caption.copyWith(
                        color: theme.mutedText3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 02 · Page structure ──────────────────────────────────────────────────────

class _Structure extends StatelessWidget {
  const _Structure({required this.ctrl});
  final CreateTemplateController ctrl;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ctrl.schemaError != null) ...[
          _Banner(message: ctrl.schemaError!, color: theme.danger),
          const SizedBox(height: 12),
        ],
        if (ctrl.sections.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Хэсэг алга. «Хэсэг нэмэх» товчоор эхлээрэй.',
              textAlign: TextAlign.center,
              style: context.textStyles.caption.copyWith(
                color: theme.mutedText3,
              ),
            ),
          ),
        for (final (index, section) in ctrl.sections.indexed)
          Padding(
            key: ValueKey('template_section_${section.id}'),
            padding: const EdgeInsets.only(bottom: 12),
            child: _SectionCard(
              ctrl: ctrl,
              section: section,
              first: index == 0,
              last: index == ctrl.sections.length - 1,
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.ctrl,
    required this.section,
    required this.first,
    required this.last,
  });

  final CreateTemplateController ctrl;
  final TemplateSectionDraft section;
  final bool first, last;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return _Surface(
      color: theme.panel2,
      radius: AppDimens.radiusMD,
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: section.titleCtrl,
                  style: context.textStyles.bodyMedium.copyWith(
                    color: theme.ink2,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Хэсгийн нэр',
                    isDense: true,
                    filled: false,
                    border: UnderlineInputBorder(),
                    enabledBorder: UnderlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              _MoveButtons(
                first: first,
                last: last,
                onUp: () => ctrl.moveSectionUp(section.id),
                onDown: () => ctrl.moveSectionDown(section.id),
                onRemove: () => ctrl.removeSection(section.id),
                removeTooltip: 'Хэсгийг устгах',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.only(left: 10, right: 8),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: theme.border, width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, item) in section.items.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ItemCard(
                      key: ValueKey('template_item_${item.id}'),
                      ctrl: ctrl,
                      sectionId: section.id,
                      item: item,
                      first: index == 0,
                      last: index == section.items.length - 1,
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => ctrl.addItem(section.id, ctrl.newItem()),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Асуулт нэмэх'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveButtons extends StatelessWidget {
  const _MoveButtons({
    required this.first,
    required this.last,
    required this.onUp,
    required this.onDown,
    required this.onRemove,
    required this.removeTooltip,
  });

  final bool first, last;
  final VoidCallback onUp, onDown, onRemove;
  final String removeTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    const size = BoxConstraints.tightFor(width: 36, height: 36);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Дээш',
          constraints: size,
          padding: EdgeInsets.zero,
          iconSize: 18,
          color: theme.mutedText2,
          onPressed: first ? null : onUp,
          icon: const Icon(Icons.arrow_upward_rounded),
        ),
        IconButton(
          tooltip: 'Доош',
          constraints: size,
          padding: EdgeInsets.zero,
          iconSize: 18,
          color: theme.mutedText2,
          onPressed: last ? null : onDown,
          icon: const Icon(Icons.arrow_downward_rounded),
        ),
        IconButton(
          tooltip: removeTooltip,
          constraints: size,
          padding: EdgeInsets.zero,
          iconSize: 18,
          color: theme.danger,
          onPressed: onRemove,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

/// One question, edited in place like the web's `ItemRow`: its label, type,
/// position set, required flag, check options and `showWhen` dependency.
class _ItemCard extends StatefulWidget {
  const _ItemCard({
    super.key,
    required this.ctrl,
    required this.sectionId,
    required this.item,
    required this.first,
    required this.last,
  });

  final CreateTemplateController ctrl;
  final String sectionId;
  final TemplateItemDraft item;
  final bool first, last;

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  late final _label = TextEditingController(text: widget.item.label);

  /// Kept as typed — "Хэвийн, " stays until the next option is written —
  /// while the item holds the parsed list.
  late final _options = TextEditingController(
    text: widget.item.effectiveOptions.join(', '),
  );

  @override
  void didUpdateWidget(_ItemCard old) {
    super.didUpdateWidget(old);
    // Switching back to a check question restores the default options.
    if (widget.item.type == ItemType.check && old.item.type != ItemType.check) {
      _options.text = widget.item.effectiveOptions.join(', ');
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _options.dispose();
    super.dispose();
  }

  TemplateItemDraft get _item => widget.item;

  void _update(TemplateItemDraft updated) =>
      widget.ctrl.updateItem(widget.sectionId, updated);

  void _setOptions(String text) {
    final options = text
        .split(',')
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList();
    _update(
      _item.copyWith(
        options: options.isEmpty ? List.of(defaultCheckOptions) : options,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final ctrl = widget.ctrl;
    final dense = context.textStyles.caption.copyWith(color: theme.ink2);
    return _Surface(
      color: theme.panel,
      radius: AppDimens.radiusSM,
      padding: const EdgeInsets.fromLTRB(10, 2, 2, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _label,
                  onChanged: (value) => _update(_item.copyWith(label: value)),
                  style: context.textStyles.body.copyWith(color: theme.ink2),
                  decoration: const InputDecoration(
                    hintText: 'Асуултын нэр',
                    isDense: true,
                    filled: false,
                    border: UnderlineInputBorder(),
                    enabledBorder: UnderlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              _MoveButtons(
                first: widget.first,
                last: widget.last,
                onUp: () => ctrl.moveItemUp(widget.sectionId, _item.id),
                onDown: () => ctrl.moveItemDown(widget.sectionId, _item.id),
                onRemove: () => ctrl.removeItem(widget.sectionId, _item.id),
                removeTooltip: 'Асуултыг устгах',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Compact<ItemType>(
                value: _item.type,
                items: {for (final t in ItemType.selectable) t: t.label},
                onChanged: (type) => _update(_item.copyWith(type: type)),
              ),
              _Compact<PositionSetKey?>(
                value: _item.positionSet,
                items: {
                  null: 'Байрлалгүй',
                  for (final key in PositionSetKey.values) key: key.label,
                },
                onChanged: (key) => _update(
                  _item.copyWith(
                    positionSet: key,
                    clearPositionSet: key == null,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(AppDimens.radiusSM),
                onTap: () =>
                    _update(_item.copyWith(isRequired: !_item.isRequired)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _item.isRequired,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (value) =>
                          _update(_item.copyWith(isRequired: value ?? false)),
                    ),
                    Text('Заавал', style: dense),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ],
          ),
          if (_item.type == ItemType.check) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _options,
              onChanged: _setOptions,
              style: dense,
              decoration: const InputDecoration(
                isDense: true,
                hintText:
                    'Сонголтуудыг таслалаар тусгаарлана уу (жишээ: Хэвийн, '
                    'Анхаарах, Солих)',
              ),
            ),
          ],
          _Dependency(ctrl: ctrl, sectionId: widget.sectionId, item: _item),
        ],
      ),
    );
  }
}

/// The question's `showWhen`: which earlier check question it follows, and
/// which of that question's answers show it.
class _Dependency extends StatelessWidget {
  const _Dependency({
    required this.ctrl,
    required this.sectionId,
    required this.item,
  });

  final CreateTemplateController ctrl;
  final String sectionId;
  final TemplateItemDraft item;

  @override
  Widget build(BuildContext context) {
    final prior = ctrl.priorCheckItems(sectionId, item.id);
    final showWhen = item.showWhen;
    if (prior.isEmpty && showWhen == null) return const SizedBox.shrink();
    final theme = CarserviceTheme.of(context);
    final dependency = ctrl.dependencyOf(sectionId, item);
    final small = context.textStyles.caption.copyWith(color: theme.mutedText3);
    return _Surface(
      color: theme.panel2,
      radius: AppDimens.radiusSM,
      margin: const EdgeInsets.only(top: 8, right: 8),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Хамаарал:', style: small),
              const SizedBox(width: 8),
              Expanded(
                child: _Compact<String?>(
                  value: dependency?.id,
                  expand: true,
                  items: {
                    null: '— Хамаарал байхгүй —',
                    for (final p in prior)
                      p.id: p.label.trim().isEmpty ? 'Нэргүй асуулт' : p.label,
                  },
                  onChanged: (id) {
                    final source = prior.where((p) => p.id == id).firstOrNull;
                    _set(
                      source == null
                          ? null
                          : ShowWhen(
                              itemId: source.id,
                              values: [source.effectiveOptions.first],
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (dependency != null) ...[
            Text('→ хариу нь:', style: small),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final option in dependency.effectiveOptions)
                  FilterChip(
                    label: Text(option),
                    labelStyle: context.textStyles.caption,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    selected: showWhen!.values.contains(option),
                    onSelected: (on) => _set(
                      ShowWhen(
                        itemId: showWhen.itemId,
                        values: on
                            ? [...showWhen.values, option]
                            : [
                                for (final v in showWhen.values)
                                  if (v != option) v,
                              ],
                      ),
                    ),
                  ),
              ],
            ),
          ] else if (showWhen != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Хамаарал тогтоосон асуулт алга болсон байна — дахин сонгоно уу.',
                style: context.textStyles.caption.copyWith(color: theme.warn),
              ),
            ),
        ],
      ),
    );
  }

  void _set(ShowWhen? showWhen) => ctrl.updateItem(
    sectionId,
    item.copyWith(showWhen: showWhen, clearShowWhen: showWhen == null),
  );
}

/// A small dropdown for the question's settings.
class _Compact<T> extends StatelessWidget {
  const _Compact({
    required this.value,
    required this.items,
    required this.onChanged,
    this.expand = false,
  });

  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) => AppDropdown<T>(
    value: value,
    variant: AppDropdownVariant.compact,
    expand: expand,
    items: [
      for (final MapEntry(:key, value: label) in items.entries)
        AppDropdownItem<T>(value: key, label: label),
    ],
    onChanged: onChanged,
  );
}

// ─── 03 · Preview ─────────────────────────────────────────────────────────────

class _PreviewPanel extends StatefulWidget {
  const _PreviewPanel();

  @override
  State<_PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<_PreviewPanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CreateTemplateController>();
    return _Panel(
      index: 3,
      title: 'Бөглөх урьдчилан харах',
      action: TextButton(
        key: const ValueKey('template_preview_toggle'),
        onPressed: () => setState(() => _open = !_open),
        child: Text(_open ? 'Нуух' : 'Харах'),
      ),
      child: _open
          ? TemplatePreview(schema: ctrl.schema)
          : const SizedBox.shrink(),
    );
  }
}

// ─── Save bar ─────────────────────────────────────────────────────────────────

/// Always in reach on a long form, like the web's sticky action bar.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.dirty,
    required this.submitting,
    required this.label,
    required this.permission,
    required this.user,
    required this.onSubmit,
  });

  final bool dirty, submitting;
  final String label, permission;
  final User? user;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Material(
      color: theme.panel,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.borderSubtle)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dirty ? 'Хадгалагдаагүй өөрчлөлт байна' : '',
                  style: context.textStyles.caption.copyWith(
                    color: theme.mutedText3,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => AppNav.back(),
                child: const Text('Буцах'),
              ),
              const SizedBox(width: 8),
              PermissionGate(
                permission: permission,
                user: user,
                child: FilledButton(
                  key: const ValueKey('template_submit'),
                  onPressed: submitting ? null : onSubmit,
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
