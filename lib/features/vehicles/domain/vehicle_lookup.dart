import 'package:carservice_business/core/domain/diagnostic.dart'
    show CustomerSummary;
import 'package:carservice_business/core/utils/result.dart';
import 'package:carservice_business/features/vehicles/domain/vehicle.dart';

/// Owner block of `GET /api/v1/hur/vehicle`. The phone is **masked**
/// server-side (`99••••82`); it is for display only and must never be used to
/// match or create a customer — the server resolves the real owner itself.
class LookupOwner {
  const LookupOwner({this.firstName, this.lastName, this.phone, this.kind});

  final String? firstName;
  final String? lastName;
  final String? phone;

  /// `Байгууллага` / `Хувь хүн` / null.
  final String? kind;

  bool get hasPhone => (phone ?? '').trim().isNotEmpty;

  String get displayName {
    final n = [
      lastName,
      firstName,
    ].where((s) => s != null && s.trim().isNotEmpty).join(' ');
    return n.isEmpty ? '—' : n;
  }

  factory LookupOwner.fromJson(Map<String, dynamic> j) => LookupOwner(
    firstName: _s(j['firstName']),
    lastName: _s(j['lastName']),
    phone: _s(j['phone']),
    kind: _s(j['kind']),
  );
}

/// Parsed `GET /api/v1/hur/vehicle?plate=` response.
class VehicleLookup {
  const VehicleLookup({
    this.plate,
    this.make,
    this.model,
    this.year,
    this.vin,
    this.color,
    this.country,
    this.fuelType,
    this.capacity,
    this.className,
    this.importDate,
    this.wheelPosition,
    this.purpose,
    this.owner,
    this.source = 'hur',
    this.registered = false,
    this.matchedCustomerId,
  });

  final String? plate;
  final String? make;
  final String? model;
  final int? year;
  final String? vin;
  final String? color;
  final String? country;
  final String? fuelType;
  final int? capacity;
  final String? className;
  final String? importDate;
  final String? wheelPosition;
  final String? purpose;
  final LookupOwner? owner;

  /// `global` (already in the system) or `hur`.
  final String source;

  /// True when this tenant already has a vehicle with the same plate.
  final bool registered;
  final String? matchedCustomerId;

  bool get isGlobal => source == 'global';

  /// Make and model both present — the lookup alone is enough to register.
  bool get isComplete =>
      (make ?? '').trim().isNotEmpty && (model ?? '').trim().isNotEmpty;

  factory VehicleLookup.fromJson(Object? raw) {
    final root = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final v = root['vehicle'] is Map
        ? Map<String, dynamic>.from(root['vehicle'] as Map)
        : <String, dynamic>{};
    final owner = v['owner'];
    final matched = root['matchedCustomerId'];
    return VehicleLookup(
      plate: _s(v['plate']),
      make: _s(v['make'] ?? v['mark']),
      model: _s(v['model']),
      year: _i(v['year']),
      vin: _s(v['vin']),
      color: _s(v['color']),
      country: _s(v['country']),
      fuelType: _s(v['fuelType']),
      capacity: _i(v['capacity']),
      className: _s(v['className']),
      importDate: _s(v['importDate']),
      wheelPosition: _s(v['wheelPosition']),
      purpose: _s(v['purpose']),
      owner: owner is Map
          ? LookupOwner.fromJson(Map<String, dynamic>.from(owner))
          : null,
      source: root['source'] == 'global' ? 'global' : 'hur',
      registered: root['registered'] == true,
      matchedCustomerId: matched is String && matched.isNotEmpty
          ? matched
          : null,
    );
  }
}

String? _s(Object? v) {
  if (v == null) return null;
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}

int? _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v');

/// Staff-API calls that back the vehicle-create form's plate lookup. Kept
/// apart from `VehiclesRepository`/`CustomersRepository` so those frozen
/// contracts (and their many fakes) stay untouched.
abstract interface class VehicleLookupRepository {
  /// `GET /api/v1/hur/vehicle?plate=`. Errors: 429 (rate limited), 502
  /// (HUR upstream), 404/400.
  Future<Result<VehicleLookup>> lookupVehicle(String plate);

  /// `POST /api/v1/customers/from-plate` — the server resolves the owner from
  /// the plate and creates the customer. Needs `customers.create`. Errors:
  /// 422 (`fieldErrors.plate`), 404 `OWNER_NOT_FOUND`, 429, 502.
  Future<Result<CustomerSummary>> registerOwnerFromPlate(String plate);

  /// `POST /api/v1/vehicles` with `fromLookup: true` (server resolves the
  /// owner regnum). Same body otherwise as `VehiclesRepository.createVehicle`.
  Future<Result<Vehicle>> createVehicleFromLookup({
    required String plate,
    required String make,
    required String model,
    String? vin,
    int? year,
    int? mileage,
    String? customerId,
  });
}
