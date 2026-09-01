import 'package:flutter/material.dart';
import 'package:carcare_service/core/theme/app_theme.dart';

// ─── Status ──────────────────────────────────────────────────────────────────

enum AppointmentStatus {
  PENDING,
  CONFIRMED,
  REJECTED,
  CANCELLED,
  NO_SHOW;

  static AppointmentStatus fromString(String s) =>
      values.firstWhere((e) => e.name == s, orElse: () => AppointmentStatus.PENDING);

  String get label => switch (this) {
        PENDING => 'Хүлээгдэж буй',
        CONFIRMED => 'Баталгаажсан',
        REJECTED => 'Татгалзсан',
        CANCELLED => 'Цуцлагдсан',
        NO_SHOW => 'Ирээгүй',
      };

  Color get color => switch (this) {
        PENDING => const Color(0xFFF59E0B),
        CONFIRMED => AppColors.good,
        REJECTED => AppColors.danger,
        CANCELLED => const Color(0xFF94A3B8),
        NO_SHOW => const Color(0xFFA78BFA),
      };

  Color get bgColor => color.withOpacity(0.12);

  // Backend APPOINTMENT_STATUS_TRANSITIONS-тай яг таарна
  List<AppointmentStatus> get nextStatuses => switch (this) {
        PENDING => [CONFIRMED, REJECTED],
        CONFIRMED => [NO_SHOW, CANCELLED],
        _ => [],
      };

  bool get isTerminal =>
      this == REJECTED || this == CANCELLED || this == NO_SHOW;
}

// ─── Ref types ────────────────────────────────────────────────────────────────

class ApptBranchRef {
  final String id;
  final String name;
  const ApptBranchRef({required this.id, required this.name});
  factory ApptBranchRef.fromJson(Map<String, dynamic> j) =>
      ApptBranchRef(id: j['id'] as String, name: j['name'] as String);
}

class ApptAccountRef {
  final String? name;
  final String phone;
  const ApptAccountRef({required this.name, required this.phone});
  factory ApptAccountRef.fromJson(Map<String, dynamic> j) =>
      ApptAccountRef(
        name: j['name'] as String?,
        phone: j['phone'] as String,
      );
  String get displayName => name?.isNotEmpty == true ? name! : phone;
}

class ApptCustomerRef {
  final String id;
  final String fullName;
  final String phone;
  const ApptCustomerRef(
      {required this.id, required this.fullName, required this.phone});
  factory ApptCustomerRef.fromJson(Map<String, dynamic> j) => ApptCustomerRef(
        id: j['id'] as String,
        fullName: j['fullName'] as String,
        phone: j['phone'] as String,
      );
}

class ApptVehicleRef {
  final String? id;
  final String plate;
  final String make;
  final String model;
  const ApptVehicleRef(
      {this.id, required this.plate, required this.make, required this.model});
  factory ApptVehicleRef.fromJson(Map<String, dynamic> j) => ApptVehicleRef(
        id: j['id'] as String?,
        plate: j['plate'] as String,
        make: j['make'] as String,
        model: j['model'] as String,
      );
  String get displayName => '$make $model'.trim();
}

class ApptOrderRef {
  final String id;
  final int number;
  const ApptOrderRef({required this.id, required this.number});
  factory ApptOrderRef.fromJson(Map<String, dynamic> j) =>
      ApptOrderRef(id: j['id'] as String, number: j['number'] as int);
}

// ─── Main model ───────────────────────────────────────────────────────────────

class AppointmentSummary {
  final String id;
  final AppointmentStatus status;
  final DateTime requestedAt;
  final String? note;
  final DateTime createdAt;
  final ApptBranchRef branch;
  final ApptAccountRef? account;
  final ApptCustomerRef? customer;
  final ApptVehicleRef? accountVehicle;
  final ApptVehicleRef? vehicle;
  final ApptOrderRef? serviceOrder;

  const AppointmentSummary({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.note,
    required this.createdAt,
    required this.branch,
    this.account,
    this.customer,
    this.accountVehicle,
    this.vehicle,
    this.serviceOrder,
  });

  factory AppointmentSummary.fromJson(Map<String, dynamic> j) =>
      AppointmentSummary(
        id: j['id'] as String,
        status: AppointmentStatus.fromString(j['status'] as String),
        requestedAt: DateTime.parse(j['requestedAt'] as String),
        note: j['note'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        branch: ApptBranchRef.fromJson(j['branch'] as Map<String, dynamic>),
        account: j['account'] != null
            ? ApptAccountRef.fromJson(j['account'] as Map<String, dynamic>)
            : null,
        customer: j['customer'] != null
            ? ApptCustomerRef.fromJson(j['customer'] as Map<String, dynamic>)
            : null,
        accountVehicle: j['accountVehicle'] != null
            ? ApptVehicleRef.fromJson(
                j['accountVehicle'] as Map<String, dynamic>)
            : null,
        vehicle: j['vehicle'] != null
            ? ApptVehicleRef.fromJson(j['vehicle'] as Map<String, dynamic>)
            : null,
        serviceOrder: j['serviceOrder'] != null
            ? ApptOrderRef.fromJson(j['serviceOrder'] as Map<String, dynamic>)
            : null,
      );

  // Харуулах нэр: resolve хийгдсэн Customer → Account → fallback
  String get displayName =>
      customer?.fullName ?? account?.displayName ?? 'Нэргүй';

  String get displayPhone => customer?.phone ?? account?.phone ?? '—';

  // Харуулах машин: snapshot хийгдсэн Vehicle → consumer AccountVehicle
  ApptVehicleRef? get displayVehicle => vehicle ?? accountVehicle;
}
