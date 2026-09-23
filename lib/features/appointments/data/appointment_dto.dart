/// Envelope parsing for Appointments — P2-F1.
///
/// Field-level defensive tolerance lives on the domain models themselves
/// (`appointment.dart`'s `fromJson` factories never throw for an optional
/// field). This file only unwraps the top-level response envelopes
/// (`{appointments:[...], pagination}`, `{appointment:{...}}`, bulk
/// `{succeeded, failed}`, …) and enforces the handful of fields the contract
/// treats as structurally required for a response to be usable at all
/// (pagination integers, a bulk failure's `appointmentId`/`code`/`message`).
library;

import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/features/appointments/domain/appointment.dart';

typedef JsonMap = Map<String, dynamic>;

JsonMap _map(Object? value, String label) {
  if (value is! Map) throw AppointmentParseException('$label буруу байна.');
  return Map<String, dynamic>.from(value);
}

int _requiredInt(JsonMap json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw AppointmentParseException('$key буруу байна.');
}

bool _requiredBool(JsonMap json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw AppointmentParseException('$key buruu байна.');
}

String _requiredString(JsonMap json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw AppointmentParseException('$key талбар буруу байна.');
  }
  return value.trim();
}

PaginationMeta _pagination(Object? raw) {
  final json = _map(raw, 'pagination');
  final page = _requiredInt(json, 'page');
  final pageSize = _requiredInt(json, 'pageSize');
  final total = _requiredInt(json, 'total');
  final totalPages = _requiredInt(json, 'totalPages');
  if (page < 1 || pageSize < 1 || total < 0 || totalPages < 0) {
    throw const AppointmentParseException('Хуудаслалтын мэдээлэл буруу байна.');
  }
  return PaginationMeta(
    page: page,
    pageSize: pageSize,
    total: total,
    totalPages: totalPages,
    hasPrev: _requiredBool(json, 'hasPrev'),
    hasNext: _requiredBool(json, 'hasNext'),
  );
}

/// `GET /api/v1/appointments` — `{appointments:[...], pagination}`.
class AppointmentPageDto {
  const AppointmentPageDto(this.items, this.pagination);
  final List<AppointmentSummary> items;
  final PaginationMeta pagination;

  factory AppointmentPageDto.fromJson(Object? raw) {
    final json = _map(raw, 'appointments response');
    final list = json['appointments'];
    if (list is! List) {
      throw const AppointmentParseException(
        'Цаг захиалгын жагсаалт буруу байна.',
      );
    }
    return AppointmentPageDto(
      list
          .whereType<Map>()
          .map(
            (item) =>
                AppointmentSummary.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      _pagination(json['pagination']),
    );
  }
}

/// `GET /api/v1/appointments?month=YYYY-MM` — `{dates: string[]}`, one
/// `YYYY-MM-DD` entry per appointment that month (P2-F1b).
///
/// Defensive per the `P2-F1` convention: only a structurally missing/non-list
/// `dates` field throws. Each entry is otherwise best-effort — a non-string
/// entry or an unparseable date string is skipped rather than throwing, so
/// one bad row can never crash the calendar. Aggregation rule: the parsed
/// map counts occurrences per date-only `DateTime` (year/month/day, no
/// time), so N appointments on the same day become `{that day: N}` and a day
/// with zero appointments is absent from the map entirely.
class AppointmentMonthCountsDto {
  const AppointmentMonthCountsDto(this.counts);
  final Map<DateTime, int> counts;

  factory AppointmentMonthCountsDto.fromJson(Object? raw) {
    final json = _map(raw, 'month counts response');
    final list = json['dates'];
    if (list is! List) {
      throw const AppointmentParseException(
        'Сарын өдрийн жагсаалт буруу байна.',
      );
    }
    final counts = <DateTime, int>{};
    for (final entry in list) {
      if (entry is! String) continue;
      final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(entry);
      if (match == null) continue;
      final year = int.tryParse(match.group(1)!);
      final month = int.tryParse(match.group(2)!);
      final day = int.tryParse(match.group(3)!);
      if (year == null || month == null || day == null) continue;
      if (month < 1 || month > 12 || day < 1 || day > 31) continue;
      final key = DateTime(year, month, day);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return AppointmentMonthCountsDto(counts);
  }
}

/// `POST /api/v1/appointments` and `PATCH /api/v1/appointments/[id]` —
/// `{appointment:{...}}`.
class AppointmentSummaryDto {
  const AppointmentSummaryDto(this.value);
  final AppointmentSummary value;

  factory AppointmentSummaryDto.fromJson(Object? raw) {
    final json = _map(raw, 'appointment response');
    return AppointmentSummaryDto(
      AppointmentSummary.fromJson(_map(json['appointment'], 'appointment')),
    );
  }
}

/// `{ok, appointmentId, status?}` shared shape for confirm/reject/no-show;
/// `{ok, appointmentId, arrived}` for the arrived route.
class AppointmentLifecycleResultDto {
  const AppointmentLifecycleResultDto(this.value);
  final AppointmentLifecycleResult value;

  factory AppointmentLifecycleResultDto.fromJson(
    Object? raw, {
    AppointmentStatus? fallbackStatus,
  }) {
    final json = _map(raw, 'lifecycle response');
    return AppointmentLifecycleResultDto(
      AppointmentLifecycleResult(
        appointmentId: _requiredString(json, 'appointmentId'),
        status: json['status'] == null
            ? fallbackStatus
            : AppointmentStatus.fromJson(json['status']),
        arrived: json['arrived'] is bool ? json['arrived'] as bool : null,
      ),
    );
  }
}

/// `{ok, appointmentId, orderId, linked, requestedAt}`.
class AppointmentRescheduleResultDto {
  const AppointmentRescheduleResultDto(this.value);
  final AppointmentRescheduleResult value;

  factory AppointmentRescheduleResultDto.fromJson(Object? raw) {
    final json = _map(raw, 'reschedule response');
    final requestedAtRaw = json['requestedAt'];
    final requestedAt = requestedAtRaw is String
        ? DateTime.tryParse(requestedAtRaw)?.toLocal()
        : null;
    if (requestedAt == null) {
      throw const AppointmentParseException('requestedAt буруу байна.');
    }
    return AppointmentRescheduleResultDto(
      AppointmentRescheduleResult(
        appointmentId: _requiredString(json, 'appointmentId'),
        orderId: json['orderId'] is String ? json['orderId'] as String : null,
        linked: json['linked'] == true,
        requestedAt: requestedAt,
      ),
    );
  }
}

/// `POST /appointments/bulk/category` — `{succeeded:[...], failed:[...]}`.
class AppointmentBulkResultDto {
  const AppointmentBulkResultDto(this.value);
  final AppointmentBulkResult value;

  factory AppointmentBulkResultDto.fromJson(Object? raw) {
    final json = _map(raw, 'bulk response');
    final succeeded = json['succeeded'];
    final failed = json['failed'];
    if (succeeded is! List || failed is! List) {
      throw const AppointmentParseException(
        'Бөөн өөрчлөлтийн хариу буруу байна.',
      );
    }
    return AppointmentBulkResultDto(
      AppointmentBulkResult(
        succeeded: succeeded
            .map((id) {
              if (id is! String || id.trim().isEmpty) {
                throw const AppointmentParseException('succeeded буруу байна.');
              }
              return id;
            })
            .toList(growable: false),
        failed: failed
            .map((item) {
              final value = _map(item, 'bulk failure');
              return AppointmentBulkFailure(
                appointmentId: _requiredString(value, 'appointmentId'),
                code: _requiredString(value, 'code'),
                message: _requiredString(value, 'message'),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

/// `POST /appointments/[id]/payment` — `{ok, paid, message?, underpaidAmount?}`.
class AppointmentPaymentCheckResultDto {
  const AppointmentPaymentCheckResultDto(this.value);
  final AppointmentPaymentCheckResult value;

  factory AppointmentPaymentCheckResultDto.fromJson(Object? raw) {
    final json = _map(raw, 'payment check response');
    final underpaid = json['underpaidAmount'];
    return AppointmentPaymentCheckResultDto(
      AppointmentPaymentCheckResult(
        ok: json['ok'] == true,
        paid: json['paid'] == true,
        message: json['message'] is String ? json['message'] as String : null,
        underpaidAmount: underpaid is num ? underpaid.toDouble() : null,
      ),
    );
  }
}

/// `POST /appointments/[id]/payment/retry` — `{ok, required}`.
class AppointmentPaymentRetryResultDto {
  const AppointmentPaymentRetryResultDto(this.value);
  final AppointmentPaymentRetryResult value;

  factory AppointmentPaymentRetryResultDto.fromJson(Object? raw) {
    final json = _map(raw, 'payment retry response');
    return AppointmentPaymentRetryResultDto(
      AppointmentPaymentRetryResult(
        ok: json['ok'] == true,
        required: json['required'] == true,
      ),
    );
  }
}

/// `POST /appointments/[id]/payment/refund` —
/// `{ok, paymentId, refundedVia, amount, currency}`.
class AppointmentRefundResultDto {
  const AppointmentRefundResultDto(this.value);
  final AppointmentRefundResult value;

  factory AppointmentRefundResultDto.fromJson(Object? raw) {
    final json = _map(raw, 'refund response');
    return AppointmentRefundResultDto(
      AppointmentRefundResult(
        paymentId: _requiredString(json, 'paymentId'),
        refundedVia: _requiredString(json, 'refundedVia'),
        amount: _requiredString(json, 'amount'),
        currency: _requiredString(json, 'currency'),
      ),
    );
  }
}
