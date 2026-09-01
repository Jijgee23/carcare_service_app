// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

enum ServiceKind {
  LABOR,
  GOODS,
  DIAGNOSTIC;

  String get label {
    switch (this) {
      case LABOR:
        return 'Ажил';
      case GOODS:
        return 'Сэлбэг/Бараа';
      case DIAGNOSTIC:
        return 'Оношилгоо';
    }
  }

  Color get color {
    switch (this) {
      case LABOR:
        return const Color(0xFF3B6FF5);
      case GOODS:
        return const Color(0xFF10B981);
      case DIAGNOSTIC:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData get icon {
    switch (this) {
      case LABOR:
        return Icons.build_outlined;
      case GOODS:
        return Icons.inventory_2_outlined;
      case DIAGNOSTIC:
        return Icons.troubleshoot_outlined;
    }
  }
}

class ServiceUnit {
  final String id;
  final String name;
  final String? code;
  final bool isActive;
  ServiceUnit({required this.id, required this.name, this.code, this.isActive = true});

  factory ServiceUnit.fromJson(Map<String, dynamic> j) => ServiceUnit(
        id: j['id'] as String,
        name: j['name'] as String,
        code: j['code'] as String?,
        isActive: j['isActive'] as bool? ?? true,
      );

  String get display => code != null && code!.isNotEmpty ? '$name ($code)' : name;
}

class LaborCategory {
  final String id;
  final String name;
  final String? description;
  final bool isActive;
  LaborCategory({required this.id, required this.name, this.description, this.isActive = true});

  factory LaborCategory.fromJson(Map<String, dynamic> j) => LaborCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        isActive: j['isActive'] as bool? ?? true,
      );
}

class CatalogService {
  final String id;
  final ServiceKind type;
  final String name;
  final String? code;
  final double price;
  final double? costPrice;
  final double? stock;
  final String? description;
  final bool isActive;
  final double? durationValue;
  final ServiceUnit? unit;
  final ServiceUnit? durationUnit;
  final LaborCategory? laborCategory;
  final int? usageCount;

  CatalogService({
    required this.id,
    required this.type,
    required this.name,
    this.code,
    required this.price,
    this.costPrice,
    this.stock,
    this.description,
    required this.isActive,
    this.durationValue,
    this.unit,
    this.durationUnit,
    this.laborCategory,
    this.usageCount,
  });

  factory CatalogService.fromJson(Map<String, dynamic> j) {
    return CatalogService(
      id: j['id'] as String,
      type: ServiceKind.values.firstWhere(
        (k) => k.name == j['type'],
        orElse: () => ServiceKind.LABOR,
      ),
      name: j['name'] as String,
      code: j['code'] as String?,
      price: _d(j['price']),
      costPrice: j['costPrice'] != null ? _d(j['costPrice']) : null,
      stock: j['stock'] != null ? _d(j['stock']) : null,
      description: j['description'] as String?,
      isActive: j['isActive'] as bool? ?? true,
      durationValue: j['durationValue'] != null ? _d(j['durationValue']) : null,
      unit: j['unit'] != null
          ? ServiceUnit.fromJson(j['unit'] as Map<String, dynamic>)
          : null,
      durationUnit: j['durationUnit'] != null
          ? ServiceUnit.fromJson(j['durationUnit'] as Map<String, dynamic>)
          : null,
      laborCategory: j['laborCategory'] != null
          ? LaborCategory.fromJson(j['laborCategory'] as Map<String, dynamic>)
          : null,
      usageCount:
          (j['_count'] as Map<String, dynamic>?)?['items'] as int?,
    );
  }

  static double _d(dynamic v) => double.tryParse(v.toString()) ?? 0;

  StockLevel get stockLevel {
    if (type != ServiceKind.GOODS) return StockLevel.ok;
    final s = stock ?? 0;
    if (s <= 0) return StockLevel.out;
    if (s < 5) return StockLevel.low;
    return StockLevel.ok;
  }

  String get durationDisplay {
    if (durationValue == null) return '—';
    final v = durationValue!;
    final n = v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
    return durationUnit != null ? '$n ${durationUnit!.display}' : n;
  }

  String get stockDisplay {
    final s = stock ?? 0;
    final n = s == s.truncateToDouble() ? s.toInt().toString() : s.toStringAsFixed(3);
    return unit != null ? '$n ${unit!.display}' : n;
  }
}

enum DiagnosticType {
  INTAKE,
  POST_SERVICE,
  ROUTINE,
  DAMAGE_REPORT;

  String get label {
    switch (this) {
      case INTAKE:
        return 'Хүлээж авах';
      case POST_SERVICE:
        return 'Үйлчилгээний дараа';
      case ROUTINE:
        return 'Тогтмол үзлэг';
      case DAMAGE_REPORT:
        return 'Гэмтлийн тайлан';
    }
  }

  Color get color {
    switch (this) {
      case INTAKE:
        return const Color(0xFF8B5CF6);
      case POST_SERVICE:
        return const Color(0xFF10B981);
      case ROUTINE:
        return const Color(0xFF3B6FF5);
      case DAMAGE_REPORT:
        return const Color(0xFFF59E0B);
    }
  }
}

class DiagnosticTemplateSummary {
  final String id;
  final String name;
  final String? description;
  final DiagnosticType type;
  final int version;
  final bool isActive;
  final double? price;
  final int? durationMin;

  DiagnosticTemplateSummary({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    required this.version,
    required this.isActive,
    this.price,
    this.durationMin,
  });

  factory DiagnosticTemplateSummary.fromJson(Map<String, dynamic> j) =>
      DiagnosticTemplateSummary(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        type: DiagnosticType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => DiagnosticType.ROUTINE,
        ),
        version: j['version'] as int? ?? 1,
        isActive: j['isActive'] as bool? ?? true,
        price: j['price'] != null ? double.tryParse(j['price'].toString()) : null,
        durationMin: j['durationMin'] as int?,
      );

  String get durationDisplay {
    if (durationMin == null) return '—';
    if (durationMin! < 60) return '$durationMin мин';
    final h = durationMin! ~/ 60;
    final m = durationMin! % 60;
    return m == 0 ? '$h цаг' : '$h ц $m мин';
  }
}

enum StockLevel { out, low, ok }

extension StockLevelExt on StockLevel {
  String get label {
    switch (this) {
      case StockLevel.out:
        return 'Дууссан';
      case StockLevel.low:
        return 'Бага үлдэгдэл';
      case StockLevel.ok:
        return 'Хүрэлцээтэй';
    }
  }

  Color get color {
    switch (this) {
      case StockLevel.out:
        return const Color(0xFFEF4444);
      case StockLevel.low:
        return const Color(0xFFF59E0B);
      case StockLevel.ok:
        return const Color(0xFF22C55E);
    }
  }

  Color get bgColor {
    switch (this) {
      case StockLevel.out:
        return const Color(0xFFFEE2E2);
      case StockLevel.low:
        return const Color(0xFFFEF3C7);
      case StockLevel.ok:
        return const Color(0xFFDCFCE7);
    }
  }
}
