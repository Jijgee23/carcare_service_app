import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/domain/diagnostic.dart';

// Олон feature-д хуваалцдаг lookup operations.
// Diagnostic-specific (templates, reports) → DiagnosticRepository
class DiagnosticService {
  // ─── Vehicles ──────────────────────────────────────────────────────────────

  static Future<List<VehicleSummary>> searchVehicles(String q) async {
    final encoded = Uri.encodeQueryComponent(q);
    final res = await api(Api.get, 'vehicles?q=$encoded&limit=20');
    if (res == null) return [];
    final list = res.data['vehicles'] as List;
    return list.map((e) => VehicleSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<VehicleSummary?> createVehicle({
    required String plate,
    required String make,
    required String model,
    String? vin,
    int? year,
    int? mileage,
    String? customerId,
  }) async {
    final res = await api(
      Api.post,
      'vehicles',
      body: {
        'plate': plate,
        'make': make,
        'model': model,
        if (vin != null && vin.isNotEmpty) 'vin': vin,
        'year': ?year,
        'mileage': ?mileage,
        if (customerId != null && customerId.isNotEmpty) 'customerId': customerId,
      },
    );
    if (res == null) return null;
    return VehicleSummary.fromJson(res.data['vehicle'] as Map<String, dynamic>);
  }

  // ─── Customers ─────────────────────────────────────────────────────────────

  static Future<List<CustomerSummary>> searchCustomers(String q) async {
    final encoded = Uri.encodeQueryComponent(q);
    final res = await api(Api.get, 'customers?q=$encoded&limit=20');
    if (res == null) return [];
    final list = res.data['customers'] as List;
    return list.map((e) => CustomerSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<CustomerSummary?> createCustomer({
    required String fullName,
    required String phone,
    String? email,
  }) async {
    final res = await api(
      Api.post,
      'customers',
      body: {
        'fullName': fullName,
        'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    if (res == null) return null;
    return CustomerSummary.fromJson(res.data['customer'] as Map<String, dynamic>);
  }

  // ─── HUR ───────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> lookupHurVehicle(String plate) async {
    final encoded = Uri.encodeQueryComponent(plate);
    final res = await api(Api.get, 'hur/vehicle?plate=$encoded');
    if (res == null) return null;
    return res.data['vehicle'] as Map<String, dynamic>?;
  }

  // ─── Branches ──────────────────────────────────────────────────────────────

  static Future<List<BranchSummary>> getBranches() async {
    final res = await api(Api.get, 'branches');
    if (res == null) return [];
    final list = res.data['branches'] as List;
    return list.map((e) => BranchSummary.fromJson(e as Map<String, dynamic>)).toList();
  }
}
