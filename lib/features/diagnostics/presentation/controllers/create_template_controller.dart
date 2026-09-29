import 'dart:async';

import 'package:carcare_service/core/utils/price_input.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostic.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carcare_service/features/diagnostics/data/diagnostics_repository.dart';
import 'package:carcare_service/features/services/data/service_repository.dart';
import 'package:carcare_service/features/services/domain/service.dart';
import 'package:carcare_service/features/services/domain/services_repository.dart';
import 'package:carcare_service/features/diagnostics/data/diagnostics_data_source.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:flutter/material.dart';

// ─── Draft models ──────────────────────────────────────────────────────────────

class TemplateItemDraft {
  final String id;
  String label;
  ItemType type;
  bool isRequired;
  List<String> options;
  PositionSetKey? positionSet;
  ShowWhen? showWhen;
  List<String> get effectiveOptions =>
      options.isNotEmpty ? options : defaultCheckOptions;

  TemplateItemDraft({
    required this.id,
    this.label = '',
    this.type = ItemType.check,
    this.isRequired = false,
    List<String>? options,
    this.positionSet,
    this.showWhen,
  }) : options = options ?? List.of(defaultCheckOptions);

  TemplateItemDraft copyWith({
    String? label,
    ItemType? type,
    bool? isRequired,
    List<String>? options,
    PositionSetKey? positionSet,
    bool clearPositionSet = false,
    ShowWhen? showWhen,
    bool clearShowWhen = false,
  }) => TemplateItemDraft(
    id: id,
    label: label ?? this.label,
    type: type ?? this.type,
    isRequired: isRequired ?? this.isRequired,
    options: options ?? List.of(this.options),
    positionSet: clearPositionSet ? null : (positionSet ?? this.positionSet),
    showWhen: clearShowWhen ? null : (showWhen ?? this.showWhen),
  );

  /// A check question with a position set has one answer per position, so
  /// it cannot drive another question's `showWhen`.
  bool get canDriveShowWhen => type == ItemType.check && positionSet == null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label.trim(),
    'type': type.name,
    'required': isRequired,
    if (type == ItemType.check) 'options': effectiveOptions,
    if (positionSet != null) 'positionSet': positionSet!.name,
    if (showWhen != null)
      'showWhen': {'itemId': showWhen!.itemId, 'values': showWhen!.values},
  };

  TemplateItem toItem() => TemplateItem(
    id: id,
    label: label.trim(),
    type: type,
    required: isRequired,
    options: type == ItemType.check ? effectiveOptions : null,
    showWhen: showWhen,
    positionSet: positionSet,
  );
}

class TemplateSectionDraft {
  final String id;
  final TextEditingController titleCtrl;
  List<TemplateItemDraft> items;

  TemplateSectionDraft({
    required this.id,
    String title = '',
    List<TemplateItemDraft>? items,
  }) : titleCtrl = TextEditingController(text: title),
       items = items ?? [];

  void dispose() => titleCtrl.dispose();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': titleCtrl.text.trim(),
    'items': items.map((i) => i.toJson()).toList(),
  };

  TemplateSection toSection() => TemplateSection(
    id: id,
    title: titleCtrl.text.trim(),
    items: items.map((i) => i.toItem()).toList(growable: false),
  );
}

// ─── Controller ────────────────────────────────────────────────────────────────

/// The diagnostic-service editor, after the web's `TemplateEditor`
/// (`carcare.mn/app/dashboard/diagnostics/templates/template-editor.tsx`):
/// basic details (name, category, price, duration, description, type,
/// active), the page structure (sections of questions, each with a type,
/// position set, required flag, options and `showWhen` dependency), and a
/// live preview. Validation mirrors the server's, so its messages show next
/// to the fields before a round trip.
class CreateTemplateController extends ChangeNotifier {
  CreateTemplateController({
    DiagnosticTemplateRepository? repo,
    ServicesRepository? categoriesRepo,
    this.templateId,
  }) : _repo = repo ?? DiagnosticsRepositoryImpl(RemoteDiagnosticsDataSource()),
       _categoriesRepo = categoriesRepo ?? RemoteServicesRepository();
  final DiagnosticTemplateRepository _repo;

  /// Source of the tenant's categories (`GET labor-categories?all=true`) —
  /// the same list service forms pick from.
  final ServicesRepository _categoriesRepo;
  final String? templateId;
  bool get isEditing => templateId != null;

  int _counter = 0;
  String _uid(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${++_counter}';

  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final durationCtrl = TextEditingController();

  DiagnosticType type = DiagnosticType.INTAKE;
  bool isActive = true;
  bool submitting = false;
  bool loading = false;
  String? loadError;
  bool isSystemDefault = false;
  bool isShared = false;
  int? version;

  /// System templates are shown as a preview only; duplicate one to edit.
  bool get readOnly => isSystemDefault || isShared;

  /// Something changed since the template was loaded or last saved.
  bool dirty = false;

  /// Per-field messages (`name`, `categoryId`, `price`, `durationMin`,
  /// `type`), from [validate] or the server's 422.
  Map<String, String> fieldErrors = const {};

  /// Why the page structure is invalid, if it is.
  String? schemaError;

  /// A failure not tied to one field.
  String? formError;

  /// Selected category — the server rejects create/update without one.
  String? categoryId;
  List<Category> categories = const [];
  bool categoriesLoading = false;
  String? categoriesError;

  /// Categories offered in the picker: active ones, plus the template's
  /// current one even if it has since been deactivated (so editing never
  /// silently changes it).
  List<Category> get selectableCategories => categories
      .where((c) => c.isActive || c.id == categoryId)
      .toList(growable: false);

  List<TemplateSectionDraft> sections = [];

  bool get canSubmit => !submitting && !loading && !readOnly;

  /// The schema as it stands, for the preview.
  TemplateSchema get schema => TemplateSchema(
    sections: sections.map((s) => s.toSection()).toList(growable: false),
  );

  Future<void> init() async {
    unawaited(loadCategories());
    if (templateId == null) {
      _seedDefaultSchema();
      _listen();
      return;
    }
    loading = true;
    notifyListeners();
    final result = await _repo.getTemplate(templateId!);
    switch (result) {
      case Ok(:final value):
        _loadTemplate(value);
      case Err(:final error):
        loadError = error.display;
    }
    loading = false;
    _listen();
    notifyListeners();
  }

  Future<void> loadCategories() async {
    categoriesLoading = true;
    categoriesError = null;
    notifyListeners();
    final result = await _categoriesRepo.getCategories();
    switch (result) {
      case Ok(:final value):
        categories = value;
      case Err(:final error):
        categoriesError = error.display;
    }
    categoriesLoading = false;
    notifyListeners();
  }

  /// A new template starts the way the web's does: one section with one
  /// required check question.
  void _seedDefaultSchema() {
    sections = [
      TemplateSectionDraft(
        id: _uid('sec'),
        title: 'Үндсэн үзлэг',
        items: [
          TemplateItemDraft(
            id: _uid('item'),
            label: 'Кузовын байдал',
            isRequired: true,
          ),
        ],
      ),
    ];
  }

  void _loadTemplate(DiagnosticTemplateDetail template) {
    nameCtrl.text = template.name;
    descCtrl.text = template.description ?? '';
    priceCtrl.text = template.price == null
        ? ''
        : formatPriceInput('${template.price}');
    durationCtrl.text = template.durationMin?.toString() ?? '';
    type = template.type == DiagnosticType.unknown
        ? DiagnosticType.INTAKE
        : template.type;
    isActive = template.isActive;
    isSystemDefault = template.isSystemDefault;
    isShared = template.isShared;
    version = template.version;
    categoryId = template.categoryId;
    sections = template.schema.sections
        .map(
          (section) => TemplateSectionDraft(
            id: section.id,
            title: section.title,
            items: section.items
                .map(
                  (item) => TemplateItemDraft(
                    id: item.id,
                    label: item.label,
                    type: item.type,
                    isRequired: item.required,
                    options: item.options == null
                        ? <String>[]
                        : List.of(item.options!),
                    positionSet: item.positionSet,
                    showWhen: item.showWhen == null
                        ? null
                        : ShowWhen(
                            itemId: item.showWhen!.itemId,
                            values: List.of(item.showWhen!.values),
                          ),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  /// Text edits mark the form dirty; attached once the fields hold their
  /// loaded values, so loading itself does not.
  void _listen() {
    for (final ctrl in [nameCtrl, descCtrl, priceCtrl, durationCtrl]) {
      ctrl.addListener(_onTextChanged);
    }
    for (final s in sections) {
      s.titleCtrl.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() => _changed();

  void _changed() {
    dirty = true;
    notifyListeners();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    durationCtrl.dispose();
    for (final s in sections) {
      s.dispose();
    }
    super.dispose();
  }

  // ─── Basic details ─────────────────────────────────────────────────────────

  void setType(DiagnosticType t) {
    type = t;
    _changed();
  }

  void setIsActive(bool v) {
    isActive = v;
    _changed();
  }

  void setCategory(String? id) {
    categoryId = id;
    _changed();
  }

  // ─── Section ops ───────────────────────────────────────────────────────────

  void addSection() {
    final s = TemplateSectionDraft(id: _uid('sec'), title: 'Шинэ хэсэг');
    s.titleCtrl.addListener(_onTextChanged);
    sections.add(s);
    _changed();
  }

  void removeSection(String id) {
    final idx = sections.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    sections.removeAt(idx).dispose();
    _changed();
  }

  void moveSectionUp(String id) => _moveSection(id, -1);
  void moveSectionDown(String id) => _moveSection(id, 1);

  void _moveSection(String id, int by) {
    final idx = sections.indexWhere((s) => s.id == id);
    final to = idx + by;
    if (idx < 0 || to < 0 || to >= sections.length) return;
    sections.insert(to, sections.removeAt(idx));
    _changed();
  }

  // ─── Item ops ──────────────────────────────────────────────────────────────

  /// The web's "+ Асуулт нэмэх" question.
  TemplateItemDraft newItem() =>
      TemplateItemDraft(id: _uid('item'), label: 'Шинэ асуулт');

  /// The check questions above [itemId], across sections, that it may
  /// depend on.
  List<TemplateItemDraft> priorCheckItems(String sectionId, String itemId) {
    final result = <TemplateItemDraft>[];
    for (final section in sections) {
      for (final item in section.items) {
        if (item.id == itemId) return result;
        if (item.canDriveShowWhen) result.add(item);
      }
      if (section.id == sectionId) break;
    }
    return result;
  }

  /// The question [item] depends on, or null when it has no dependency or
  /// the one it names is no longer an earlier check question.
  TemplateItemDraft? dependencyOf(String sectionId, TemplateItemDraft item) {
    final id = item.showWhen?.itemId;
    if (id == null) return null;
    for (final prior in priorCheckItems(sectionId, item.id)) {
      if (prior.id == id) return prior;
    }
    return null;
  }

  void addItem(String sectionId, TemplateItemDraft item) {
    _section(sectionId).items.add(item);
    _changed();
  }

  /// Replaces the question, applying the web's type rules: a check question
  /// always has options (the defaults when it had none), other types none.
  void updateItem(String sectionId, TemplateItemDraft updated) {
    final items = _section(sectionId).items;
    final idx = items.indexWhere((i) => i.id == updated.id);
    if (idx < 0) return;
    if (updated.type != ItemType.check) {
      updated.options = [];
    } else if (updated.options.isEmpty) {
      updated.options = List.of(defaultCheckOptions);
    }
    items[idx] = updated;
    _changed();
  }

  void removeItem(String sectionId, String itemId) {
    _section(sectionId).items.removeWhere((i) => i.id == itemId);
    _changed();
  }

  void moveItemUp(String sectionId, String itemId) =>
      _moveItem(sectionId, itemId, -1);
  void moveItemDown(String sectionId, String itemId) =>
      _moveItem(sectionId, itemId, 1);

  void _moveItem(String sectionId, String itemId, int by) {
    final items = _section(sectionId).items;
    final idx = items.indexWhere((i) => i.id == itemId);
    final to = idx + by;
    if (idx < 0 || to < 0 || to >= items.length) return;
    items.insert(to, items.removeAt(idx));
    _changed();
  }

  TemplateSectionDraft _section(String id) =>
      sections.firstWhere((s) => s.id == id);

  // ─── Validation ────────────────────────────────────────────────────────────

  /// The server's `validateSchema` rules and messages, so an invalid
  /// structure is explained without a round trip. Null when valid.
  String? get schemaProblem {
    if (sections.isEmpty) return 'Хуудсанд дор хаяж нэг хэсэг байх ёстой.';
    final checkOptions = <String, List<String>>{};
    for (final (sIdx, section) in sections.indexed) {
      final title = section.titleCtrl.text.trim();
      if (title.isEmpty) return '${sIdx + 1} дэх хэсгийн нэр хоосон байна.';
      if (section.items.isEmpty) {
        return '"$title" хэсэгт дор хаяж нэг асуулт хэрэгтэй.';
      }
      for (final (iIdx, item) in section.items.indexed) {
        final label = item.label.trim();
        if (label.isEmpty) {
          return '"$title" хэсгийн ${iIdx + 1}-р асуулт хоосон.';
        }
        final dependency = item.showWhen;
        if (dependency != null) {
          final allowed = checkOptions[dependency.itemId];
          if (allowed == null || dependency.values.isEmpty) {
            return '"$label" асуултын хамаарал буруу: өмнөх check төрлийн '
                'асуултаас сонгоно уу.';
          }
          for (final value in dependency.values) {
            if (!allowed.contains(value)) {
              return '"$label" асуултын хамаарлын "$value" утга өмнөх '
                  'асуултын сонголтод алга.';
            }
          }
        }
        if (item.canDriveShowWhen) {
          checkOptions[item.id] = item.effectiveOptions;
        }
      }
    }
    return null;
  }

  bool get hasValidShowWhen => schemaProblem == null;

  /// Fills [fieldErrors] and [schemaError] the way the server would; true
  /// when there is nothing to report.
  bool validate() {
    final errors = <String, String>{};
    if (nameCtrl.text.trim().isEmpty) {
      errors['name'] = 'Хуудасны нэрээ оруулна уу.';
    }
    if (categoryId == null) errors['categoryId'] = 'Ангилал сонгоно уу.';
    final price = priceCtrl.text.trim();
    if (price.isNotEmpty && (parsePriceInput(price) ?? -1) < 0) {
      errors['price'] = 'Үнэ буруу.';
    }
    final duration = durationCtrl.text.trim();
    if (duration.isNotEmpty && (int.tryParse(duration) ?? -1) < 0) {
      errors['durationMin'] = 'Хугацаа буруу.';
    }
    fieldErrors = errors;
    schemaError = schemaProblem;
    formError = null;
    notifyListeners();
    return errors.isEmpty && schemaError == null;
  }

  // ─── Submit ────────────────────────────────────────────────────────────────

  Future<DiagnosticTemplateSummary?> submit() async {
    if (!canSubmit) return null;
    if (!validate()) {
      messageError(fieldErrors.values.firstOrNull ?? schemaError!);
      return null;
    }
    submitting = true;
    notifyListeners();

    final description = descCtrl.text.trim();
    final body = {
      'name': nameCtrl.text.trim(),
      'description': description.isEmpty ? null : description,
      'type': type.name,
      'categoryId': categoryId,
      'isActive': isActive,
      'price': parsePriceInput(priceCtrl.text),
      'durationMin': int.tryParse(durationCtrl.text.trim()),
      'schema': {'sections': sections.map((s) => s.toJson()).toList()},
    };
    final result = isEditing
        ? await _repo.updateTemplate(templateId!, body)
        : await _repo.createTemplate(body);

    submitting = false;
    switch (result) {
      case Ok(:final value):
        dirty = false;
        notifyListeners();
        return value;
      case Err(:final error):
        // A 422 carries the real reasons in fieldErrors; the generic display
        // text alone ("Хүсэлт буруу.") hides them.
        final errors = Map.of(error.fieldErrors ?? const <String, String>{});
        schemaError = errors.remove('schema');
        fieldErrors = errors;
        formError = errors.isEmpty && schemaError == null
            ? error.display
            : null;
        notifyListeners();
        messageError(errors.values.firstOrNull ?? schemaError ?? error.display);
        return null;
    }
  }
}
