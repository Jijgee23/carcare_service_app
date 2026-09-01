import 'package:carcare_service/features/presentation/data/repository/diagnostic_repository.dart';
import 'package:carcare_service/features/models/diagnostic.dart';
import 'package:carcare_service/shared/widgets/dialogs/message.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class NewInspectionController extends ChangeNotifier {
  NewInspectionController({DiagnosticRepository? repo}) : _repo = repo ?? DiagnosticRepository();

  final DiagnosticRepository _repo;

  // Templates
  List<DiagnosticTemplateSummary> _templates = [];
  bool _loadingTemplates = false;

  // Selected template (with full schema)
  DiagnosticTemplateDetail? _template;
  bool _loadingTemplate = false;

  // Linked order (optional — set when creating inspection from order detail)
  String? _orderId;

  // Vehicle & Customer
  VehicleSummary? _vehicle;
  CustomerSummary? _customer;

  // Checklist navigation
  int _currentSection = 0;

  // Form values
  int _mileage = 0;
  String _generalNote = '';

  // Answers: { itemId: value }
  final Map<String, String> _answers = {};
  // Notes per item: { itemId: note }
  final Map<String, String> _notes = {};
  // Photo file paths per item: { itemId: [path, ...] }
  final Map<String, List<String>> _photos = {};

  // Submission state
  bool _submitting = false;

  // ─── Getters ───────────────────────────────────────────────────────────────

  List<DiagnosticTemplateSummary> get templates => _templates;
  bool get loadingTemplates => _loadingTemplates;
  DiagnosticTemplateDetail? get template => _template;
  bool get loadingTemplate => _loadingTemplate;
  VehicleSummary? get vehicle => _vehicle;
  CustomerSummary? get customer => _customer;
  int get currentSection => _currentSection;
  int get mileage => _mileage;
  String get generalNote => _generalNote;
  bool get submitting => _submitting;

  List<TemplateSection> get sections => _template?.schema.sections ?? [];
  TemplateSection? get currentSectionData => sections.isNotEmpty ? sections[_currentSection] : null;
  bool get canGoNext => _currentSection < sections.length - 1;
  bool get canGoPrev => _currentSection > 0;

  bool isItemVisible(TemplateItem item) {
    if (item.showWhen == null) return true;
    final dep = _answers[item.showWhen!.itemId];
    return item.showWhen!.values.contains(dep);
  }

  String? getAnswer(String itemId) => _answers[itemId];
  String? getNote(String itemId) => _notes[itemId];
  List<String> getPhotos(String itemId) => _photos[itemId] ?? [];

  int get totalCheckItems => sections.fold(
    0,
    (s, sec) =>
        s +
        sec.items
            .where((i) => i.type == ItemType.check)
            .fold<int>(0, (sum, i) => sum + (i.positionSet?.positions.length ?? 1)),
  );
  int get answeredDanger => _answers.values.where((v) => v == 'Засах').length;
  int get answeredWarning => _answers.values.where((v) => v == 'Анхаарах').length;
  int get answeredGood => _answers.values.where((v) => v == 'OK').length;

  // ─── Actions ───────────────────────────────────────────────────────────────

  Future<void> loadTemplates() async {
    if (_loadingTemplates || _templates.isNotEmpty) return;
    _loadingTemplates = true;
    notifyListeners();
    _templates = await _repo.getTemplates();
    _loadingTemplates = false;
    notifyListeners();
  }

  Future<void> selectTemplate(String id) async {
    _loadingTemplate = true;
    _template = null;
    _currentSection = 0;
    _answers.clear();
    _notes.clear();
    notifyListeners();
    _template = await _repo.getTemplateDetail(id);
    _loadingTemplate = false;
    notifyListeners();
  }

  void setOrderId(String? id) => _orderId = id;

  void setVehicle(VehicleSummary v, {CustomerSummary? customer}) {
    _vehicle = v;
    _customer = customer ?? v.customer;
    notifyListeners();
  }

  void setCustomer(CustomerSummary c) {
    _customer = c;
    notifyListeners();
  }

  void setMileage(int v) {
    _mileage = v;
    notifyListeners();
  }

  void setGeneralNote(String v) {
    _generalNote = v;
    notifyListeners();
  }

  void setAnswer(String itemId, String value) {
    _answers[itemId] = value;
    notifyListeners();
  }

  void setNote(String itemId, String note) {
    if (note.isEmpty) {
      _notes.remove(itemId);
    } else {
      _notes[itemId] = note;
    }
    notifyListeners();
  }

  void addPhoto(String itemId, String path) {
    _photos.putIfAbsent(itemId, () => []).add(path);
    notifyListeners();
  }

  void removePhoto(String itemId, int index) {
    _photos[itemId]?.removeAt(index);
    notifyListeners();
  }

  void nextSection() {
    if (canGoNext) {
      _currentSection++;
      notifyListeners();
    }
  }

  void prevSection() {
    if (canGoPrev) {
      _currentSection--;
      notifyListeners();
    }
  }

  Future<FormData> _buildFormData(String branchId) async {
    final fields = <MapEntry<String, String>>[];
    final files = <MapEntry<String, MultipartFile>>[];

    fields.add(MapEntry('templateId', _template!.id));
    fields.add(MapEntry('branchId', branchId));
    if (_orderId != null) fields.add(MapEntry('orderId', _orderId!));
    if (_vehicle != null) fields.add(MapEntry('vehicleId', _vehicle!.id));
    if (_customer != null) fields.add(MapEntry('customerId', _customer!.id));
    if (_mileage > 0) fields.add(MapEntry('mileageAtReport', _mileage.toString()));
    if (_generalNote.isNotEmpty) fields.add(MapEntry('notes', _generalNote));

    for (final section in sections) {
      for (final item in section.items) {
        if (!isItemVisible(item)) continue;

        final positions = item.positionSet?.positions;
        if (positions != null) {
          for (final pos in positions) {
            final key = positionedKey(item.id, pos.code);
            final val = _answers[key];
            if (val != null && val.isNotEmpty) {
              fields.add(MapEntry('data[$key][value]', val));
            }
            final note = _notes[key];
            if (note != null && note.isNotEmpty) {
              fields.add(MapEntry('data[$key][note]', note));
            }
            final paths = _photos[key];
            if (paths != null) {
              for (final path in paths) {
                files.add(MapEntry('photos[$key]', await MultipartFile.fromFile(path)));
              }
            }
          }
        } else {
          final val = _answers[item.id];
          if (val != null && val.isNotEmpty) {
            fields.add(MapEntry('data[${item.id}][value]', val));
          }
          final note = _notes[item.id];
          if (note != null && note.isNotEmpty) {
            fields.add(MapEntry('data[${item.id}][note]', note));
          }
          final paths = _photos[item.id];
          if (paths != null) {
            for (final path in paths) {
              files.add(MapEntry('photos[${item.id}]', await MultipartFile.fromFile(path)));
            }
          }
        }
      }
    }

    final formData = FormData()..fields.addAll(fields);
    formData.files.addAll(files);
    return formData;
  }

  Future<String?> submit(String branchId) async {
    if (_template == null || _vehicle == null || _customer == null) {
      messageError('Загвар болон машины мэдээлэл шаардлагатай.');
      return null;
    }
    _submitting = true;
    notifyListeners();
    try {
      final formData = await _buildFormData(branchId);
      final id = await _repo.submitReport(formData);
      if (id != null) messageComplete('Тайлан амжилттай илгээгдлээ!');
      return id;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  void reset() {
    _template = null;
    _orderId = null;
    _vehicle = null;
    _customer = null;
    _currentSection = 0;
    _mileage = 0;
    _generalNote = '';
    _answers.clear();
    _notes.clear();
    _photos.clear();
    _submitting = false;
    notifyListeners();
  }
}
