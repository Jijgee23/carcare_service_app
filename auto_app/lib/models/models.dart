import 'package:flutter/material.dart';

// ─────────────────────────────────────────
//  ENUMS
// ─────────────────────────────────────────
enum CheckStatus { good, warning, danger }

enum InspectionType { technical, routine, repair }

extension CheckStatusExt on CheckStatus {
  String get label {
    switch (this) {
      case CheckStatus.good:
        return 'Хэвийн';
      case CheckStatus.warning:
        return 'Анхаарах';
      case CheckStatus.danger:
        return 'Засвар шаарддагатай';
    }
  }

  Color get color {
    switch (this) {
      case CheckStatus.good:
        return const Color(0xFF22C55E);
      case CheckStatus.warning:
        return const Color(0xFFF59E0B);
      case CheckStatus.danger:
        return const Color(0xFFEF4444);
    }
  }

  Color get bgColor {
    switch (this) {
      case CheckStatus.good:
        return const Color(0xFFDCFCE7);
      case CheckStatus.warning:
        return const Color(0xFFFEF3C7);
      case CheckStatus.danger:
        return const Color(0xFFFEE2E2);
    }
  }

  IconData get icon {
    switch (this) {
      case CheckStatus.good:
        return Icons.check_circle;
      case CheckStatus.warning:
        return Icons.warning_amber_rounded;
      case CheckStatus.danger:
        return Icons.cancel;
    }
  }
}

extension InspectionTypeExt on InspectionType {
  String get label {
    switch (this) {
      case InspectionType.technical:
        return 'Техникийн оношилгоо';
      case InspectionType.routine:
        return 'Ердийн үзлэг';
      case InspectionType.repair:
        return 'Засварын дараах';
    }
  }
}

// ─────────────────────────────────────────
//  CHECK ITEM
// ─────────────────────────────────────────
class CheckItem {
  final String id;
  final String name;
  CheckStatus status;
  String? note;

  CheckItem({
    required this.id,
    required this.name,
    this.status = CheckStatus.good,
    this.note,
  });

  CheckItem copyWith({CheckStatus? status, String? note}) => CheckItem(
        id: id,
        name: name,
        status: status ?? this.status,
        note: note ?? this.note,
      );
}

// ─────────────────────────────────────────
//  INSPECTION SECTION
// ─────────────────────────────────────────
class InspectionSection {
  final String id;
  final String title;
  final List<CheckItem> items;

  InspectionSection({
    required this.id,
    required this.title,
    required this.items,
  });

  int get goodCount => items.where((i) => i.status == CheckStatus.good).length;
  int get warningCount => items.where((i) => i.status == CheckStatus.warning).length;
  int get dangerCount => items.where((i) => i.status == CheckStatus.danger).length;
}

// ─────────────────────────────────────────
//  VEHICLE
// ─────────────────────────────────────────
class Vehicle {
  final String id;
  final String plateNumber;
  final String make;
  final String model;
  final int year;
  final String? vin;

  const Vehicle({
    required this.id,
    required this.plateNumber,
    required this.make,
    required this.model,
    required this.year,
    this.vin,
  });

  String get displayName => '$make $model $year';
}

// ─────────────────────────────────────────
//  INSPECTION RECORD
// ─────────────────────────────────────────
class InspectionRecord {
  final String id;
  final DateTime date;
  final String plateNumber;
  final String vehicleName;
  final InspectionType type;
  final int mileage;
  final List<InspectionSection> sections;
  final List<String> photoUrls;
  final String? comment;
  final String? recommendation;

  InspectionRecord({
    required this.id,
    required this.date,
    required this.plateNumber,
    required this.vehicleName,
    required this.type,
    required this.mileage,
    required this.sections,
    this.photoUrls = const [],
    this.comment,
    this.recommendation,
  });

  int get goodCount => sections.fold(0, (s, sec) => s + sec.goodCount);
  int get warningCount => sections.fold(0, (s, sec) => s + sec.warningCount);
  int get dangerCount => sections.fold(0, (s, sec) => s + sec.dangerCount);
  int get totalCount => goodCount + warningCount + dangerCount;

  CheckStatus get overallStatus {
    if (dangerCount > 0) return CheckStatus.danger;
    if (warningCount > 0) return CheckStatus.warning;
    return CheckStatus.good;
  }
}

// ─────────────────────────────────────────
//  SAMPLE DATA FACTORY
// ─────────────────────────────────────────
class SampleData {
  static List<InspectionSection> get defaultSections => [
        InspectionSection(
          id: 'lights',
          title: 'Гэрэл, дохио',
          items: [
            CheckItem(id: 'front_big', name: 'Урд их гэрэл', status: CheckStatus.good),
            CheckItem(id: 'front_small', name: 'Урд бага гэрэл', status: CheckStatus.good),
            CheckItem(id: 'rear', name: 'Арын гэрэл', status: CheckStatus.good),
            CheckItem(id: 'turn', name: 'Мурийлтын гэрэл', status: CheckStatus.warning),
            CheckItem(id: 'brake_light', name: 'Тормосны гэрэл', status: CheckStatus.good),
            CheckItem(id: 'left_door', name: 'Эргэх дохио (зүүн)', status: CheckStatus.good),
            CheckItem(id: 'right_door', name: 'Эргэх дохио (баруун)', status: CheckStatus.good),
            CheckItem(id: 'safe', name: 'Аюулгүйн гэрэл', status: CheckStatus.good),
          ],
        ),
        InspectionSection(
          id: 'brake',
          title: 'Тормос',
          items: [
            CheckItem(id: 'service_brake', name: 'Үйлчилгээний тормос', status: CheckStatus.good),
            CheckItem(id: 'hand_brake', name: 'Гар тормос', status: CheckStatus.warning),
            CheckItem(
                id: 'brake_hose',
                name: 'Тормосны шингэн',
                status: CheckStatus.danger,
                note: 'Засвар шаарддагатай'),
            CheckItem(id: 'brake_disc', name: 'Тормосны диск', status: CheckStatus.warning),
            CheckItem(id: 'brake_pad', name: 'Тормосны наклад', status: CheckStatus.warning),
          ],
        ),
        InspectionSection(
          id: 'chassis',
          title: 'Ходоо',
          items: [
            CheckItem(id: 'steering', name: 'Жолооны механизм', status: CheckStatus.good),
            CheckItem(id: 'front_axle', name: 'Урд тэнхлэг', status: CheckStatus.warning),
            CheckItem(id: 'rear_axle', name: 'Арын тэнхлэг', status: CheckStatus.good),
            CheckItem(id: 'shock', name: 'Амортизатор', status: CheckStatus.warning),
            CheckItem(id: 'spring', name: 'Пүрш', status: CheckStatus.good),
            CheckItem(id: 'tire', name: 'Дугуй', status: CheckStatus.warning),
          ],
        ),
      ];

  static List<InspectionRecord> get sampleRecords => [
        InspectionRecord(
          id: '1',
          date: DateTime(2024, 5, 20, 14, 30),
          plateNumber: 'УБ 1234 АБА',
          vehicleName: 'Toyota Prius 2016',
          type: InspectionType.technical,
          mileage: 125430,
          sections: defaultSections,
          comment: 'Баруун урд тормосны дискний элэгдэл их. Тормосны шингэнийг солих шаарддагатай.',
          recommendation: 'Тормосны диск, наклад солих.\nТормосны шингэнийг солих.',
        ),
        InspectionRecord(
          id: '2',
          date: DateTime(2024, 5, 20, 11, 15),
          plateNumber: 'УБ 5678 СВА',
          vehicleName: 'Lexus RX350 2015',
          type: InspectionType.routine,
          mileage: 98200,
          sections: [
            InspectionSection(
              id: 'lights',
              title: 'Гэрэл, дохио',
              items: List.generate(8, (i) => CheckItem(id: 'l$i', name: 'Item $i')),
            ),
          ],
        ),
        InspectionRecord(
          id: '3',
          date: DateTime(2024, 5, 19, 16, 45),
          plateNumber: 'УБ 9012 DCD',
          vehicleName: 'Hyundai Sonata 2017',
          type: InspectionType.repair,
          mileage: 74500,
          sections: defaultSections,
          comment: 'Засвар хийгдсэн.',
        ),
        InspectionRecord(
          id: '4',
          date: DateTime(2024, 6, 19, 10, 30),
          plateNumber: 'УБ 3456 EFG',
          vehicleName: 'Kia Sorento 2014',
          type: InspectionType.technical,
          mileage: 112000,
          sections: defaultSections,
        ),
        InspectionRecord(
          id: '5',
          date: DateTime(2024, 5, 18, 15, 33),
          plateNumber: 'УБ 7890 HIJ',
          vehicleName: 'Nissan X-Trail 2016',
          type: InspectionType.routine,
          mileage: 89000,
          sections: defaultSections,
        ),
      ];
}
