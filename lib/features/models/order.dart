import 'package:flutter/material.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/models/diagnostic.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum OrderStatus {
  SCHEDULED,
  IN_PROGRESS,
  WAITING_PARTS,
  COMPLETED,
  CANCELLED;

  static OrderStatus fromString(String s) =>
      values.firstWhere((e) => e.name == s, orElse: () => OrderStatus.SCHEDULED);

  String get label {
    switch (this) {
      case SCHEDULED:
        return 'Товлогдсон';
      case IN_PROGRESS:
        return 'Хийгдэж байна';
      case WAITING_PARTS:
        return 'Сэлбэг хүлээж буй';
      case COMPLETED:
        return 'Дууссан';
      case CANCELLED:
        return 'Цуцлагдсан';
    }
  }

  Color get color {
    switch (this) {
      case SCHEDULED:
        return const Color(0xFFF59E0B);
      case IN_PROGRESS:
        return const Color(0xFF3B82F6);
      case WAITING_PARTS:
        return const Color(0xFFA78BFA);
      case COMPLETED:
        return AppColors.good;
      case CANCELLED:
        return AppColors.danger;
    }
  }

  Color get bgColor => color.withOpacity(0.12);

  List<OrderStatus> get nextStatuses {
    switch (this) {
      case SCHEDULED:
        return [IN_PROGRESS, CANCELLED];
      case IN_PROGRESS:
        return [WAITING_PARTS, COMPLETED, CANCELLED];
      case WAITING_PARTS:
        return [IN_PROGRESS, CANCELLED];
      default:
        return [];
    }
  }

  bool get canAddItems => this != COMPLETED && this != CANCELLED;
  bool get isLocked => this == COMPLETED || this == CANCELLED;
  bool get isActive => this == SCHEDULED || this == IN_PROGRESS || this == WAITING_PARTS;
}

enum PaymentStatus {
  UNPAID,
  PARTIAL,
  PAID;

  static PaymentStatus fromString(String s) =>
      values.firstWhere((e) => e.name == s, orElse: () => PaymentStatus.UNPAID);

  String get label {
    switch (this) {
      case UNPAID:
        return 'Төлөгдөөгүй';
      case PARTIAL:
        return 'Хагас төлөгдсөн';
      case PAID:
        return 'Төлөгдсөн';
    }
  }

  Color get color {
    switch (this) {
      case UNPAID:
        return AppColors.danger;
      case PARTIAL:
        return const Color(0xFFF59E0B);
      case PAID:
        return AppColors.good;
    }
  }

  Color get bgColor => color.withOpacity(0.12);
}

enum ItemKind {
  LABOR,
  DIAGNOSTIC,
  PART,
  FEE;

  static ItemKind fromString(String s) =>
      values.firstWhere((e) => e.name == s, orElse: () => ItemKind.LABOR);

  String get label {
    switch (this) {
      case LABOR:
        return 'Ажил';
      case DIAGNOSTIC:
        return 'Оношилгоо';
      case PART:
        return 'Сэлбэг';
      case FEE:
        return 'Хураамж';
    }
  }

  Color get color {
    switch (this) {
      case LABOR:
        return const Color(0xFF3B82F6);
      case DIAGNOSTIC:
        return AppColors.accent;
      case PART:
        return const Color(0xFFF59E0B);
      case FEE:
        return const Color(0xFF8B5CF6);
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

double? _parseDecimal(dynamic v) {
  if (v == null) return null;
  return double.tryParse(v.toString());
}

double _parseDecimalRequired(dynamic v) => _parseDecimal(v) ?? 0.0;

// ─── OrderPayment ─────────────────────────────────────────────────────────────

class QPayBankUrl {
  final String name;
  final String nameMn;
  final String logo;
  final String description;
  final String link;

  const QPayBankUrl({
    required this.name,
    required this.nameMn,
    required this.logo,
    required this.description,
    required this.link,
  });

  factory QPayBankUrl.fromJson(Map<String, dynamic> j) => QPayBankUrl(
    name: j['name'] as String? ?? '',
    nameMn: j['name_mn'] as String? ?? j['name'] as String? ?? '',
    logo: j['logo'] as String? ?? '',
    description: j['description'] as String? ?? '',
    link: j['link'] as String? ?? '',
  );
}

class OrderPayment {
  final String id;
  final String? qrImage;
  final String? qrText;
  final double amount;
  final List<QPayBankUrl> urls;

  const OrderPayment({
    required this.id,
    this.qrImage,
    this.qrText,
    required this.amount,
    this.urls = const [],
  });

  factory OrderPayment.fromJson(Map<String, dynamic> j) => OrderPayment(
    id: j['id'] as String,
    qrImage: j['qrImage'] as String?,
    qrText: j['qrText'] as String?,
    amount: _parseDecimalRequired(j['amount']),
    urls: (j['urls'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(QPayBankUrl.fromJson)
        .toList(),
  );
}

// ─── ServiceItem ──────────────────────────────────────────────────────────────

class ServiceItem {
  final String id;
  final ItemKind kind;
  final String description;
  final double quantity;
  final double unitPrice;
  final double total;
  final String? serviceId;

  const ServiceItem({
    required this.id,
    required this.kind,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.serviceId,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> j) => ServiceItem(
    id: j['id'] as String,
    kind: ItemKind.fromString(j['kind'] as String),
    description: j['description'] as String,
    quantity: _parseDecimalRequired(j['quantity']),
    unitPrice: _parseDecimalRequired(j['unitPrice']),
    total: _parseDecimalRequired(j['total']),
    serviceId: j['serviceId'] as String?,
  );
}

// ─── OrderReportSummary ────────────────────────────────────────────────────────

class OrderReportSummary {
  final String id;
  final DateTime createdAt;
  final ReportTemplateSummary template;

  const OrderReportSummary({required this.id, required this.createdAt, required this.template});

  factory OrderReportSummary.fromJson(Map<String, dynamic> j) => OrderReportSummary(
    id: j['id'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    template: ReportTemplateSummary.fromJson(j['template'] as Map<String, dynamic>),
  );
}

// ─── ServiceOrderSummary ──────────────────────────────────────────────────────

class ServiceOrderSummary {
  final String id;
  final String number;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final double? totalAmount;
  final double? paidAmount;
  final String? notes;
  final DateTime createdAt;
  final CustomerSummary customer;
  final VehicleSummary vehicle;
  final BranchSummary branch;
  final UserSummary? assignedTo;

  const ServiceOrderSummary({
    required this.id,
    required this.number,
    required this.status,
    required this.paymentStatus,
    this.scheduledAt,
    this.startedAt,
    this.completedAt,
    this.totalAmount,
    this.paidAmount,
    this.notes,
    required this.createdAt,
    required this.customer,
    required this.vehicle,
    required this.branch,
    this.assignedTo,
  });

  factory ServiceOrderSummary.fromJson(Map<String, dynamic> j) => ServiceOrderSummary(
    id: j['id'] as String,
    number: j['number'] as String,
    status: OrderStatus.fromString(j['status'] as String),
    paymentStatus: PaymentStatus.fromString(j['paymentStatus'] as String),
    scheduledAt: j['scheduledAt'] != null ? DateTime.parse(j['scheduledAt'] as String) : null,
    startedAt: j['startedAt'] != null ? DateTime.parse(j['startedAt'] as String) : null,
    completedAt: j['completedAt'] != null ? DateTime.parse(j['completedAt'] as String) : null,
    totalAmount: _parseDecimal(j['totalAmount']),
    paidAmount: _parseDecimal(j['paidAmount']),
    notes: j['notes'] as String?,
    createdAt: DateTime.parse(j['createdAt'] as String),
    customer: CustomerSummary.fromJson(j['customer'] as Map<String, dynamic>),
    vehicle: VehicleSummary.fromJson(j['vehicle'] as Map<String, dynamic>),
    branch: BranchSummary.fromJson(j['branch'] as Map<String, dynamic>),
    assignedTo: j['assignedTo'] != null
        ? UserSummary.fromJson(j['assignedTo'] as Map<String, dynamic>)
        : null,
  );
}

// ─── ServiceOrderDetail ───────────────────────────────────────────────────────

class ServiceOrderDetail extends ServiceOrderSummary {
  final List<ServiceItem> items;
  final List<OrderReportSummary> reports;
  final DateTime? paidAt;
  final DateTime? updatedAt;

  const ServiceOrderDetail({
    required super.id,
    required super.number,
    required super.status,
    required super.paymentStatus,
    super.scheduledAt,
    super.startedAt,
    super.completedAt,
    super.totalAmount,
    super.paidAmount,
    super.notes,
    required super.createdAt,
    required super.customer,
    required super.vehicle,
    required super.branch,
    super.assignedTo,
    required this.items,
    required this.reports,
    this.paidAt,
    this.updatedAt,
  });

  factory ServiceOrderDetail.fromJson(Map<String, dynamic> j) {
    final base = ServiceOrderSummary.fromJson(j);
    return ServiceOrderDetail(
      id: base.id,
      number: base.number,
      status: base.status,
      paymentStatus: base.paymentStatus,
      scheduledAt: base.scheduledAt,
      startedAt: base.startedAt,
      completedAt: base.completedAt,
      totalAmount: base.totalAmount,
      paidAmount: base.paidAmount,
      notes: base.notes,
      createdAt: base.createdAt,
      customer: base.customer,
      vehicle: base.vehicle,
      branch: base.branch,
      assignedTo: base.assignedTo,
      items: (j['items'] as List? ?? [])
          .map((e) => ServiceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      reports: (j['reports'] as List? ?? [])
          .map((e) => OrderReportSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      paidAt: j['paidAt'] != null ? DateTime.parse(j['paidAt'] as String) : null,
      updatedAt: j['updatedAt'] != null ? DateTime.parse(j['updatedAt'] as String) : null,
    );
  }
}
