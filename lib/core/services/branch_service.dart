import 'package:carcare_service/core/api/api_client.dart';
import 'package:carcare_service/features/models/branch.dart';

class BranchService {
  BranchService._();
  static final BranchService instance = BranchService._();

  List<Branch>? _cache;

  Future<List<Branch>> getBranches() async {
    if (_cache != null) return _cache!;
    try {
      final res = await apiOrThrow(Api.get, 'branches?pageSize=100');
      _cache = (res.data['branches'] as List)
          .map((e) => Branch.fromJson(e as Map<String, dynamic>))
          .toList();
      return _cache!;
    } catch (_) {
      return [];
    }
  }

  void invalidate() => _cache = null;
}
