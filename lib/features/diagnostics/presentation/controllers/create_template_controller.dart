import 'dart:async';

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
      options.isNotEmpty ? options : const ['OK', 'Анхаарах', 'Засах'];

  TemplateItemDraft({
    required this.id,
    this.label = '',
    this.type = ItemType.check,
    this.isRequired = false,
    List<String>? options,
    this.positionSet,
    this.showWhen,
  }) : options = options ?? ['OK', 'Анхаарах', 'Засах'];

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'type': type.name,
    'required': isRequired,
    if (type == ItemType.check && options.isNotEmpty) 'options': options,
    if (positionSet != null) 'positionSet': positionSet!.name,
    if (showWhen != null)
      'showWhen': {'itemId': showWhen!.itemId, 'values': showWhen!.values},
  };
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
}

// ─── Controller ────────────────────────────────────────────────────────────────

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
  int _counter = 0;
  String _uid(String prefix) => '${prefix}_${++_counter}';

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
  int? version;

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

  void setCategory(String? id) {
    categoryId = id;
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

  List<TemplateSectionDraft> sections = [];

  bool get canSubmit =>
      !submitting &&
      nameCtrl.text.trim().isNotEmpty &&
      categoryId != null &&
      sections.isNotEmpty &&
      sections.every(
        (s) => s.titleCtrl.text.trim().isNotEmpty && s.items.isNotEmpty,
      ) &&
      sections.every((s) => s.items.every((i) => i.label.trim().isNotEmpty));

  bool get hasValidShowWhen {
    final seen = <String, List<String>>{};
    for (final section in sections) {
      for (final item in section.items) {
        final dependency = item.showWhen;
        if (dependency != null) {
          final allowed = seen[dependency.itemId];
          if (allowed == null ||
              dependency.values.isEmpty ||
              dependency.values.any((value) => !allowed.contains(value))) {
            return false;
          }
        }
        if (item.type == ItemType.check && item.positionSet == null) {
          seen[item.id] = item.effectiveOptions
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();
        }
      }
    }
    return true;
  }

  Future<void> init() async {
    nameCtrl.addListener(notifyListeners);
    unawaited(loadCategories());
    if (templateId == null) {
      addSection();
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
    notifyListeners();
  }

  void _loadTemplate(DiagnosticTemplateDetail template) {
    nameCtrl.text = template.name;
    descCtrl.text = template.description ?? '';
    priceCtrl.text = template.price?.toString() ?? '';
    durationCtrl.text = template.durationMin?.toString() ?? '';
    type = template.type;
    isActive = template.isActive;
    isSystemDefault = template.isSystemDefault;
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
          )..titleCtrl.addListener(notifyListeners),
        )
        .toList();
  }

  @override
  void dispose() {
    nameCtrl.removeListener(notifyListeners);
    nameCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    durationCtrl.dispose();
    for (final s in sections) {
      s.dispose();
    }
    super.dispose();
  }

  // ─── Type / Active ─────────────────────────────────────────────────────────

  void setType(DiagnosticType t) {
    type = t;
    notifyListeners();
  }

  void setIsActive(bool v) {
    isActive = v;
    notifyListeners();
  }

  // ─── Section ops ───────────────────────────────────────────────────────────

  void addSection() {
    final s = TemplateSectionDraft(id: _uid('sec'));
    s.titleCtrl.addListener(notifyListeners);
    sections.add(s);
    notifyListeners();
  }

  void removeSection(String id) {
    final idx = sections.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    sections[idx].dispose();
    sections.removeAt(idx);
    notifyListeners();
  }

  void moveSectionUp(String id) {
    final idx = sections.indexWhere((s) => s.id == id);
    if (idx <= 0) return;
    final tmp = sections[idx];
    sections[idx] = sections[idx - 1];
    sections[idx - 1] = tmp;
    notifyListeners();
  }

  void moveSectionDown(String id) {
    final idx = sections.indexWhere((s) => s.id == id);
    if (idx < 0 || idx >= sections.length - 1) return;
    final tmp = sections[idx];
    sections[idx] = sections[idx + 1];
    sections[idx + 1] = tmp;
    notifyListeners();
  }

  // ─── Item ops ──────────────────────────────────────────────────────────────

  TemplateItemDraft newItem() => TemplateItemDraft(id: _uid('item'));

  List<TemplateItemDraft> priorCheckItems(String sectionId, String itemId) {
    final sectionIndex = sections.indexWhere((s) => s.id == sectionId);
    if (sectionIndex < 0) return const [];
    final result = <TemplateItemDraft>[];
    for (var index = 0; index <= sectionIndex; index++) {
      final section = sections[index];
      for (final item in section.items) {
        if (index == sectionIndex && item.id == itemId) return result;
        if (item.type == ItemType.check && item.positionSet == null) {
          result.add(item);
        }
      }
    }
    return result;
  }

  void addItem(String sectionId, TemplateItemDraft item) {
    final s = sections.firstWhere((s) => s.id == sectionId);
    s.items.add(item);
    notifyListeners();
  }

  void updateItem(String sectionId, TemplateItemDraft updated) {
    final s = sections.firstWhere((s) => s.id == sectionId);
    final idx = s.items.indexWhere((i) => i.id == updated.id);
    if (idx < 0) return;
    s.items[idx] = updated;
    final validIds = priorCheckItems(
      sectionId,
      updated.id,
    ).map((item) => item.id).toSet();
    if (updated.showWhen != null &&
        !validIds.contains(updated.showWhen!.itemId)) {
      s.items[idx] = updated.copyWith(clearShowWhen: true);
    }
    notifyListeners();
  }

  void removeItem(String sectionId, String itemId) {
    final s = sections.firstWhere((s) => s.id == sectionId);
    s.items.removeWhere((i) => i.id == itemId);
    notifyListeners();
  }

  void moveItemUp(String sectionId, String itemId) {
    final s = sections.firstWhere((s) => s.id == sectionId);
    final idx = s.items.indexWhere((i) => i.id == itemId);
    if (idx <= 0) return;
    final tmp = s.items[idx];
    s.items[idx] = s.items[idx - 1];
    s.items[idx - 1] = tmp;
    notifyListeners();
  }

  void moveItemDown(String sectionId, String itemId) {
    final s = sections.firstWhere((s) => s.id == sectionId);
    final idx = s.items.indexWhere((i) => i.id == itemId);
    if (idx < 0 || idx >= s.items.length - 1) return;
    final tmp = s.items[idx];
    s.items[idx] = s.items[idx + 1];
    s.items[idx + 1] = tmp;
    notifyListeners();
  }

  // ─── Submit ────────────────────────────────────────────────────────────────

  Future<DiagnosticTemplateSummary?> submit() async {
    if (loading || isSystemDefault) return null;
    if (!hasValidShowWhen) {
      messageError(
        'Асуултын хамаарал буруу байна. Өмнөх сонголтуудыг шалгана уу.',
      );
      return null;
    }
    submitting = true;
    notifyListeners();

    final body = {
      'name': nameCtrl.text.trim(),
      'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      'type': type.name,
      'categoryId': categoryId,
      'isActive': isActive,
      'price': double.tryParse(priceCtrl.text.trim()),
      'durationMin': int.tryParse(durationCtrl.text.trim()),
      'schema': {'sections': sections.map((s) => s.toJson()).toList()},
    };
    final result = templateId == null
        ? await _repo.createTemplate(body)
        : await _repo.updateTemplate(templateId!, body);

    submitting = false;
    notifyListeners();

    switch (result) {
      case Ok(:final value):
        return value;
      case Err(:final error):
        // A 422 carries the real reason in fieldErrors (e.g. categoryId);
        // the generic display text alone ("Хүсэлт буруу.") hides it.
        final fieldMessage = error.fieldErrors?.values.firstOrNull;
        messageError(fieldMessage ?? error.display);
        return null;
    }
  }
}
