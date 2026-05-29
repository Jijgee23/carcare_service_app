import 'package:flutter/material.dart';
import '../models/models.dart';

// ─────────────────────────────────────────
//  INSPECTION LIST PROVIDER
// ─────────────────────────────────────────
class InspectionProvider extends ChangeNotifier {
  List<InspectionRecord> _records = SampleData.sampleRecords;
  CheckStatus? _filterStatus;
  int _currentTab = 0; // 0=Бүгд, 1=Хэвийн, 2=Анхаарах, 3=Засвар

  List<InspectionRecord> get records => _records;
  int get currentTab => _currentTab;
  CheckStatus? get filterStatus => _filterStatus;

  List<InspectionRecord> get filteredRecords {
    if (_filterStatus == null) return _records;
    return _records.where((r) => r.overallStatus == _filterStatus).toList();
  }

  int get todayCount =>
      _records.where((r) => _isToday(r.date)).length;

  int get totalToday => 12; // demo

  void setTab(int tab) {
    _currentTab = tab;
    switch (tab) {
      case 0:
        _filterStatus = null;
        break;
      case 1:
        _filterStatus = CheckStatus.good;
        break;
      case 2:
        _filterStatus = CheckStatus.warning;
        break;
      case 3:
        _filterStatus = CheckStatus.danger;
        break;
    }
    notifyListeners();
  }

  void addRecord(InspectionRecord record) {
    _records = [record, ..._records];
    notifyListeners();
  }

  void deleteRecord(String id) {
    _records = _records.where((r) => r.id != id).toList();
    notifyListeners();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  // Analytics data
  Map<String, int> get weeklyStats {
    return {
      '05/14': 8,
      '05/15': 12,
      '05/16': 6,
      '05/17': 15,
      '05/18': 9,
      '05/19': 18,
      '05/20': 16,
    };
  }

  int get totalGood =>
      _records.fold(0, (s, r) => s + r.goodCount);
  int get totalWarning =>
      _records.fold(0, (s, r) => s + r.warningCount);
  int get totalDanger =>
      _records.fold(0, (s, r) => s + r.dangerCount);
}

// ─────────────────────────────────────────
//  NEW INSPECTION PROVIDER
// ─────────────────────────────────────────
class NewInspectionProvider extends ChangeNotifier {
  // General info
  DateTime _date = DateTime.now();
  String _plateNumber = '';
  String _make = '';
  String _model = '';
  int _year = 2020;
  String _vin = '';
  InspectionType _type = InspectionType.technical;
  int _mileage = 0;

  // Sections
  late List<InspectionSection> _sections;
  int _currentSection = 0;

  // Media
  List<String> _photoUrls = [];
  String _comment = '';
  String _recommendation = '';
  String _severity = 'Анхаарах';

  NewInspectionProvider() {
    _sections = SampleData.defaultSections
        .map((s) => InspectionSection(
              id: s.id,
              title: s.title,
              items: s.items.map((i) => CheckItem(id: i.id, name: i.name)).toList(),
            ))
        .toList();
  }

  // Getters
  DateTime get date => _date;
  String get plateNumber => _plateNumber;
  String get make => _make;
  String get model => _model;
  int get year => _year;
  String get vin => _vin;
  InspectionType get type => _type;
  int get mileage => _mileage;
  List<InspectionSection> get sections => _sections;
  int get currentSection => _currentSection;
  List<String> get photoUrls => _photoUrls;
  String get comment => _comment;
  String get recommendation => _recommendation;
  String get severity => _severity;

  int get totalGood => _sections.fold(0, (s, sec) => s + sec.goodCount);
  int get totalWarning => _sections.fold(0, (s, sec) => s + sec.warningCount);
  int get totalDanger => _sections.fold(0, (s, sec) => s + sec.dangerCount);

  bool get canGoNext => _currentSection < _sections.length - 1;
  bool get canGoPrev => _currentSection > 0;

  InspectionSection get currentSectionData => _sections[_currentSection];

  // Setters
  void setDate(DateTime d) { _date = d; notifyListeners(); }
  void setPlateNumber(String v) { _plateNumber = v; notifyListeners(); }
  void setMake(String v) { _make = v; notifyListeners(); }
  void setModel(String v) { _model = v; notifyListeners(); }
  void setYear(int v) { _year = v; notifyListeners(); }
  void setVin(String v) { _vin = v; notifyListeners(); }
  void setType(InspectionType t) { _type = t; notifyListeners(); }
  void setMileage(int v) { _mileage = v; notifyListeners(); }
  void setComment(String v) { _comment = v; notifyListeners(); }
  void setRecommendation(String v) { _recommendation = v; notifyListeners(); }
  void setSeverity(String v) { _severity = v; notifyListeners(); }

  void nextSection() {
    if (canGoNext) { _currentSection++; notifyListeners(); }
  }

  void prevSection() {
    if (canGoPrev) { _currentSection--; notifyListeners(); }
  }

  void updateItemStatus(String sectionId, String itemId, CheckStatus status) {
    final secIdx = _sections.indexWhere((s) => s.id == sectionId);
    if (secIdx == -1) return;
    final itemIdx = _sections[secIdx].items.indexWhere((i) => i.id == itemId);
    if (itemIdx == -1) return;
    _sections[secIdx].items[itemIdx] =
        _sections[secIdx].items[itemIdx].copyWith(status: status);
    notifyListeners();
  }

  void addPhoto(String url) {
    _photoUrls = [..._photoUrls, url];
    notifyListeners();
  }

  InspectionRecord buildRecord() => InspectionRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: _date,
        plateNumber: _plateNumber,
        vehicleName: '$_make $_model $_year',
        type: _type,
        mileage: _mileage,
        sections: _sections,
        photoUrls: _photoUrls,
        comment: _comment.isNotEmpty ? _comment : null,
        recommendation: _recommendation.isNotEmpty ? _recommendation : null,
      );

  void reset() {
    _plateNumber = '';
    _make = '';
    _model = '';
    _vin = '';
    _mileage = 0;
    _comment = '';
    _recommendation = '';
    _currentSection = 0;
    _photoUrls = [];
    _sections = SampleData.defaultSections
        .map((s) => InspectionSection(
              id: s.id,
              title: s.title,
              items: s.items.map((i) => CheckItem(id: i.id, name: i.name)).toList(),
            ))
        .toList();
    notifyListeners();
  }
}

// ─────────────────────────────────────────
//  BOTTOM NAV PROVIDER
// ─────────────────────────────────────────
class BottomNavProvider extends ChangeNotifier {
  int _index = 0;
  int get index => _index;

  void setIndex(int i) {
    _index = i;
    notifyListeners();
  }
}
