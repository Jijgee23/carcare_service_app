import 'dart:async';

import 'package:carservice_business/core/domain/diagnostic.dart'
    show CustomerSummary;
import 'package:carservice_business/core/errors/app_error.dart';
import 'package:carservice_business/core/utils/result.dart';
import 'package:carservice_business/features/vehicles/domain/vehicle.dart';
import 'package:carservice_business/features/vehicles/domain/vehicle_lookup.dart';
import 'package:carservice_business/features/vehicles/domain/vehicles_repository.dart';

/// Fake for [VehicleLookupRepository] — records calls, returns whatever the
/// test configures. Defaults to "not found" so a plate that triggers a lookup
/// falls through to manual entry.
class FakeVehicleLookupRepository implements VehicleLookupRepository {
  FakeVehicleLookupRepository({this.vehicles});

  /// Delegate used by [createVehicleFromLookup] so the saved row is visible
  /// through the same fake the screen's normal create path uses.
  final VehiclesRepository? vehicles;

  Result<VehicleLookup> lookupResult = const Err(
    AppError(ErrorKind.notFound, 'Олдсонгүй', statusCode: 404),
  );
  Result<CustomerSummary> ownerResult = const Err(
    AppError(ErrorKind.notFound, 'Олдсонгүй', statusCode: 404),
  );

  /// When set, the call waits on it (holds the request in flight).
  Completer<Result<VehicleLookup>>? lookupGate;
  Completer<Result<CustomerSummary>>? ownerGate;

  /// When set, [createVehicleFromLookup] returns it instead of delegating.
  Result<Vehicle>? fromLookupError;

  final List<String> lookupPlates = [];
  final List<String> ownerPlates = [];
  final List<Map<String, Object?>> fromLookupCreates = [];

  @override
  Future<Result<VehicleLookup>> lookupVehicle(String plate) async {
    lookupPlates.add(plate);
    final gate = lookupGate;
    return gate != null ? gate.future : lookupResult;
  }

  @override
  Future<Result<CustomerSummary>> registerOwnerFromPlate(String plate) async {
    ownerPlates.add(plate);
    final gate = ownerGate;
    return gate != null ? gate.future : ownerResult;
  }

  @override
  Future<Result<Vehicle>> createVehicleFromLookup({
    required String plate,
    required String make,
    required String model,
    String? vin,
    int? year,
    int? mileage,
    String? customerId,
  }) async {
    fromLookupCreates.add({
      'plate': plate,
      'make': make,
      'model': model,
      'vin': vin,
      'year': year,
      'mileage': mileage,
      'customerId': customerId,
    });
    if (fromLookupError != null) return fromLookupError!;
    return vehicles!.createVehicle(
      plate: plate,
      make: make,
      model: model,
      vin: vin,
      year: year,
      mileage: mileage,
      customerId: customerId,
    );
  }
}
