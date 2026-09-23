/// Envelope parsing for Customers — P3-F1.
///
/// Field-level defensive tolerance lives on the domain models themselves
/// (`customer.dart`'s `fromJson` factories never throw for an optional
/// field). This file only unwraps the top-level response envelopes
/// (`{customers:[...], pagination}`, `{customer:{...}}`,
/// `{customer, vehicles}`, `{orders, meta}`, `{recipientCount}`,
/// `{notified}`, `{ok, id, fullName}`) and enforces the handful of fields
/// the contract treats as structurally required for a response to be usable
/// at all.
///
/// Mirrors `features/appointments/data/appointment_dto.dart` one-for-one,
/// including its pagination validation — the customers routes build their
/// meta with the very same `buildMeta` helper.
library;

import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/features/customers/domain/customer.dart';

typedef JsonMap = Map<String, dynamic>;

JsonMap _map(Object? value, String label) {
  if (value is! Map) throw CustomerParseException('$label буруу байна.');
  return Map<String, dynamic>.from(value);
}

int _requiredInt(JsonMap json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw CustomerParseException('$key буруу байна.');
}

bool _requiredBool(JsonMap json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw CustomerParseException('$key буруу байна.');
}

/// `buildMeta` in `carcare.mn/lib/pagination.ts` — always all six fields,
/// `totalPages` clamped to at least 1.
PaginationMeta _pagination(Object? raw, String label) {
  final json = _map(raw, label);
  final page = _requiredInt(json, 'page');
  final pageSize = _requiredInt(json, 'pageSize');
  final total = _requiredInt(json, 'total');
  final totalPages = _requiredInt(json, 'totalPages');
  if (page < 1 || pageSize < 1 || total < 0 || totalPages < 0) {
    throw const CustomerParseException('Хуудаслалтын мэдээлэл буруу байна.');
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

/// Rows that are not maps, or whose `id` is structurally missing, are
/// skipped — one malformed row must never blank an otherwise usable page.
/// This is the same tolerance `AppointmentPageDto` applies via
/// `whereType<Map>()`, extended to the id case because a customer row's only
/// hard requirement is its id.
List<T> _rows<T>(Object? list, String label, T Function(JsonMap) parse) {
  if (list is! List) throw CustomerParseException('$label буруу байна.');
  final parsed = <T>[];
  for (final item in list) {
    if (item is! Map) continue;
    try {
      parsed.add(parse(Map<String, dynamic>.from(item)));
    } on CustomerParseException {
      continue;
    }
  }
  return List<T>.unmodifiable(parsed);
}

/// `GET /api/v1/customers` — `{customers:[...], pagination}`.
class CustomerPageDto {
  const CustomerPageDto(this.items, this.pagination);
  final List<Customer> items;
  final PaginationMeta pagination;

  factory CustomerPageDto.fromJson(Object? raw) {
    final json = _map(raw, 'customers response');
    return CustomerPageDto(
      _rows(json['customers'], 'customers', Customer.fromJson),
      _pagination(json['pagination'], 'pagination'),
    );
  }
}

/// `POST /api/v1/customers` and `PATCH /api/v1/customers/[id]` —
/// `{customer:{...}}`.
class CustomerEnvelopeDto {
  const CustomerEnvelopeDto(this.value);
  final Customer value;

  factory CustomerEnvelopeDto.fromJson(Object? raw) {
    final json = _map(raw, 'customer response');
    return CustomerEnvelopeDto(
      Customer.fromJson(_map(json['customer'], 'customer')),
    );
  }
}

/// `GET /api/v1/customers/[id]` — `{customer, vehicles}`.
///
/// A missing or malformed `vehicles` degrades to an empty list: the customer
/// is the point of the request, and a vehicle list this client cannot read
/// is not a reason to fail the whole detail screen.
class CustomerDetailDto {
  const CustomerDetailDto(this.value);
  final CustomerDetail value;

  factory CustomerDetailDto.fromJson(Object? raw) {
    final json = _map(raw, 'customer detail response');
    final rawVehicles = json['vehicles'];
    return CustomerDetailDto(
      CustomerDetail(
        customer: Customer.fromJson(_map(json['customer'], 'customer')),
        vehicles: rawVehicles is List
            ? _rows(rawVehicles, 'vehicles', CustomerVehicleLink.fromJson)
            : const [],
      ),
    );
  }
}

/// `DELETE /api/v1/customers/[id]` — `{ok, id, fullName}`.
///
/// `id` is echoed by the route, but the caller already knows it; a response
/// that omits it falls back to the requested id rather than throwing.
class CustomerDeleteResultDto {
  const CustomerDeleteResultDto(this.value);
  final CustomerDeleteResult value;

  factory CustomerDeleteResultDto.fromJson(
    Object? raw, {
    required String requestedId,
  }) {
    final json = _map(raw, 'delete response');
    final id = json['id'];
    final fullName = json['fullName'];
    return CustomerDeleteResultDto(
      CustomerDeleteResult(
        id: id is String && id.trim().isNotEmpty ? id.trim() : requestedId,
        fullName: fullName is String && fullName.trim().isNotEmpty
            ? fullName.trim()
            : null,
        ok: json['ok'] != false,
      ),
    );
  }
}

/// `GET /api/v1/customers/[id]/history` — `{orders, meta}`.
///
/// Note the envelope key: `meta`, not `pagination`. The list route and the
/// history route genuinely differ here.
class CustomerHistoryPageDto {
  const CustomerHistoryPageDto(this.items, this.pagination);
  final List<CustomerHistoryOrder> items;
  final PaginationMeta pagination;

  factory CustomerHistoryPageDto.fromJson(Object? raw) {
    final json = _map(raw, 'customer history response');
    return CustomerHistoryPageDto(
      _rows(json['orders'], 'orders', CustomerHistoryOrder.fromJson),
      _pagination(json['meta'], 'meta'),
    );
  }
}

/// `GET /api/v1/customers/notify` — `{recipientCount}`.
class BroadcastRecipientCountDto {
  const BroadcastRecipientCountDto(this.value);
  final int value;

  factory BroadcastRecipientCountDto.fromJson(Object? raw) {
    final json = _map(raw, 'recipient count response');
    return BroadcastRecipientCountDto(_requiredInt(json, 'recipientCount'));
  }
}

/// `POST /api/v1/customers/notify` — `{notified}`.
class CustomerBroadcastResultDto {
  const CustomerBroadcastResultDto(this.value);
  final CustomerBroadcastResult value;

  factory CustomerBroadcastResultDto.fromJson(Object? raw) {
    final json = _map(raw, 'broadcast response');
    return CustomerBroadcastResultDto(
      CustomerBroadcastResult(notified: _requiredInt(json, 'notified')),
    );
  }
}
