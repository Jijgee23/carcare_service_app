import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/models/diagnostic.dart';
import 'package:carcare_service/features/presentation/data/repository/diagnostic_repository.dart';
import 'package:carcare_service/shared/widgets/dialogs/message.dart';
import 'package:flutter/material.dart';

// ─── Draft models ──────────────────────────────────────────────────────────────

class TemplateItemDraft {
  final String id;
  String label;
  ItemType type;
  bool isRequired;
  List<String> options;
  PositionSetKey? positionSet;

  TemplateItemDraft({
    required this.id,
    this.label = '',
    this.type = ItemType.check,
    this.isRequired = false,
    List<String>? options,
    this.positionSet,
  }) : options = options ?? ['OK', 'Анхаарах', 'Засах'];

  TemplateItemDraft copyWith({
    String? label,
    ItemType? type,
    bool? isRequired,
    List<String>? options,
    PositionSetKey? positionSet,
    bool clearPositionSet = false,
  }) => TemplateItemDraft(
    id: id,
    label: label ?? this.label,
    type: type ?? this.type,
    isRequired: isRequired ?? this.isRequired,
    options: options ?? List.of(this.options),
    positionSet: clearPositionSet ? null : (positionSet ?? this.positionSet),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'type': type.name,
    'required': isRequired,
    if (type == ItemType.check && options.isNotEmpty) 'options': options,
    if (positionSet != null) 'positionSet': positionSet!.name,
  };
}

class TemplateSectionDraft {
  final String id;
  final TextEditingController titleCtrl;
  List<TemplateItemDraft> items;

  TemplateSectionDraft({required this.id, String title = '', List<TemplateItemDraft>? items})
    : titleCtrl = TextEditingController(text: title),
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
  final _repo = DiagnosticRepository();
  int _counter = 0;
  String _uid(String prefix) => '${prefix}_${++_counter}';

  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final durationCtrl = TextEditingController();

  DiagnosticType type = DiagnosticType.INTAKE;
  bool isActive = true;
  bool submitting = false;

  List<TemplateSectionDraft> sections = [];

  bool get canSubmit =>
      !submitting &&
      nameCtrl.text.trim().isNotEmpty &&
      sections.isNotEmpty &&
      sections.every((s) => s.titleCtrl.text.trim().isNotEmpty && s.items.isNotEmpty) &&
      sections.every((s) => s.items.every((i) => i.label.trim().isNotEmpty));

  void init() {
    nameCtrl.addListener(notifyListeners);
    addSection();
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
    submitting = true;
    notifyListeners();

    final result = await _repo.createTemplate(
      name: nameCtrl.text.trim(),
      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      type: type,
      isActive: isActive,
      price: double.tryParse(priceCtrl.text.trim()),
      durationMin: int.tryParse(durationCtrl.text.trim()),
      sections: sections.map((s) => s.toJson()).toList(),
    );

    submitting = false;
    notifyListeners();

    switch (result) {
      case Ok(:final value):
        return value;
      case Err(:final error):
        messageError(error.display);
        return null;
    }
  }
}
