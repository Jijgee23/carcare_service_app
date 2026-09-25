class DiagnosticParseException implements Exception {
  const DiagnosticParseException(this.message);
  final String message;
  @override
  String toString() => 'DiagnosticParseException: $message';
}

enum DiagnosticType {
  INTAKE,
  POST_SERVICE,
  ROUTINE,
  DAMAGE_REPORT,
  unknown;

  static DiagnosticType fromJson(Object? value) {
    for (final item in values) {
      if (item.name == value) return item;
    }
    return DiagnosticType.unknown;
  }

  String get label => switch (this) {
    INTAKE => 'Хүлээж авах',
    POST_SERVICE => 'Үйлчилгээний дараа',
    ROUTINE => 'Тогтмол үзлэг',
    DAMAGE_REPORT => 'Гэмтлийн тайлан',
    unknown => 'Тодорхойгүй',
  };
}

enum ItemType {
  check,
  text,
  number,
  photo,
  signature,
  unknown;

  static ItemType fromJson(Object? value) {
    for (final item in values) {
      if (item.name == value) return item;
    }
    return ItemType.unknown;
  }

  static ItemType fromString(String value) => fromJson(value);
}

class PositionDef {
  const PositionDef({required this.code, required this.label});
  final String code, label;
}

enum PositionSetKey {
  LR,
  FB,
  CORNERS;

  List<PositionDef> get positions => switch (this) {
    LR => const [
      PositionDef(code: 'L', label: 'Зүүн'),
      PositionDef(code: 'R', label: 'Баруун'),
    ],
    FB => const [
      PositionDef(code: 'F', label: 'Урд'),
      PositionDef(code: 'B', label: 'Хойд'),
    ],
    CORNERS => const [
      PositionDef(code: 'FL', label: 'Урд зүүн'),
      PositionDef(code: 'FR', label: 'Урд баруун'),
      PositionDef(code: 'RL', label: 'Хойд зүүн'),
      PositionDef(code: 'RR', label: 'Хойд баруун'),
    ],
  };
  static PositionSetKey? fromJson(Object? value) {
    for (final item in values) {
      if (item.name == value) return item;
    }
    return null;
  }
}

enum CheckStatus { good, warning, danger }

String positionedKey(String itemId, String code) => '$itemId@$code';

class ShowWhen {
  const ShowWhen({required this.itemId, required this.values});
  final String itemId;
  final List<String> values;
}

class TemplateItem {
  const TemplateItem({
    required this.id,
    required this.label,
    required this.type,
    required this.required,
    this.options,
    this.showWhen,
    this.positionSet,
  });
  final String id, label;
  final ItemType type;
  final bool required;
  final List<String>? options;
  final ShowWhen? showWhen;
  final PositionSetKey? positionSet;
  List<String> get effectiveOptions => options?.isNotEmpty == true
      ? options!
      : const ['OK', 'Анхаарах', 'Засах'];
}

class TemplateSection {
  const TemplateSection({
    required this.id,
    required this.title,
    required this.items,
  });
  final String id, title;
  final List<TemplateItem> items;
}

class TemplateSchema {
  const TemplateSchema({required this.sections});
  final List<TemplateSection> sections;
}

class DiagnosticTemplateSummary {
  const DiagnosticTemplateSummary({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    required this.version,
    required this.isActive,
    required this.isSystemDefault,
    this.price,
    this.durationMin,
    this.updatedAt,
    this.categoryId,
  });
  final String id, name;
  final String? description;

  /// Tenant `Category` the template is filed under — required by the server
  /// on create/update (`Ангилал сонгоно уу.`).
  final String? categoryId;
  final DiagnosticType type;
  final int version;
  final bool isActive, isSystemDefault;
  final double? price;
  final int? durationMin;
  final DateTime? updatedAt;
  String get durationDisplay {
    if (durationMin == null) return '';
    final h = durationMin! ~/ 60, m = durationMin! % 60;
    if (h == 0) return '$mмин';
    if (m == 0) return '$hц';
    return '$hц $mмин';
  }
}

class DiagnosticTemplateDetail extends DiagnosticTemplateSummary {
  const DiagnosticTemplateDetail({
    required super.id,
    required super.name,
    super.description,
    required super.type,
    required super.version,
    required super.isActive,
    required super.isSystemDefault,
    super.price,
    super.durationMin,
    super.updatedAt,
    super.categoryId,
    required this.schema,
  });
  final TemplateSchema schema;
}

class CustomerSummary {
  const CustomerSummary({
    required this.id,
    this.fullName,
    required this.phone,
    this.email,
  });
  final String id, phone;
  final String? fullName, email;
  String get displayName =>
      fullName?.trim().isNotEmpty == true ? fullName!.trim() : phone;
}

class VehicleSummary {
  const VehicleSummary({
    required this.id,
    required this.plate,
    this.vin,
    required this.make,
    required this.model,
    this.year,
    this.mileage,
    this.customerId,
    this.customer,
  });
  final String id, plate, make, model;
  final String? vin, customerId;
  final int? year, mileage;
  final CustomerSummary? customer;
  String get displayName => '$make $model${year == null ? '' : ' $year'}';
}

class BranchSummary {
  const BranchSummary({required this.id, required this.name, this.address});
  final String id, name;
  final String? address;
}

class UserSummary {
  const UserSummary({
    required this.id,
    required this.firstName,
    required this.lastName,
  });
  final String id, firstName, lastName;
  String get fullName => '$firstName $lastName';
}

class ReportTemplateSummary {
  const ReportTemplateSummary({
    required this.id,
    required this.name,
    required this.type,
  });
  final String id, name;
  final DiagnosticType type;
}

class DiagnosticReportSummary {
  const DiagnosticReportSummary({
    required this.id,
    this.maxSeverity,
    this.filledById,
    this.createdAt,
    required this.templateVersion,
    this.mileageAtReport,
    this.orderId,
    required this.template,
    required this.customer,
    required this.vehicle,
    required this.branch,
    this.filledBy,
  });
  final String id;
  final String? maxSeverity;
  final String? filledById;
  final DateTime? createdAt;
  final int templateVersion;
  final int? mileageAtReport;
  final String? orderId;
  final ReportTemplateSummary template;
  final CustomerSummary customer;
  final VehicleSummary vehicle;
  final BranchSummary branch;
  final UserSummary? filledBy;
}

class ReportEntry {
  const ReportEntry({this.value, this.photos, this.note});
  final Object? value;
  final List<String>? photos;
  final String? note;
  CheckStatus get checkStatus => switch (value?.toString()) {
    'Засах' => CheckStatus.danger,
    'Анхаарах' => CheckStatus.warning,
    _ => CheckStatus.good,
  };
}

class DiagnosticReportDetail {
  const DiagnosticReportDetail({
    required this.id,
    this.filledById,
    this.createdAt,
    required this.templateVersion,
    this.maxSeverity,
    this.mileageAtReport,
    this.notes,
    this.signatureUrl,
    this.orderId,
    required this.data,
    required this.template,
    required this.customer,
    required this.vehicle,
    required this.branch,
    this.filledBy,
  });
  final String id;
  final String? filledById;
  final DateTime? createdAt;
  final int templateVersion;
  final String? maxSeverity;
  final int? mileageAtReport;
  final String? notes, signatureUrl, orderId;
  final Map<String, ReportEntry> data;
  final DiagnosticTemplateDetail template;
  final CustomerSummary customer;
  final VehicleSummary vehicle;
  final BranchSummary branch;
  final UserSummary? filledBy;
  CheckStatus get overallStatus {
    if (data.values.any(
      (e) => e.value is String && e.checkStatus == CheckStatus.danger,
    )) {
      return CheckStatus.danger;
    }
    if (data.values.any(
      (e) => e.value is String && e.checkStatus == CheckStatus.warning,
    )) {
      return CheckStatus.warning;
    }
    return CheckStatus.good;
  }

  int get dangerCount => data.values
      .where((e) => e.value is String && e.checkStatus == CheckStatus.danger)
      .length;
  int get warningCount => data.values
      .where((e) => e.value is String && e.checkStatus == CheckStatus.warning)
      .length;
  int get goodCount => data.values
      .where((e) => e.value is String && e.checkStatus == CheckStatus.good)
      .length;
}
