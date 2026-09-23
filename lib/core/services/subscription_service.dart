import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/domain/subscription.dart';

/// Fetches the tenant subscription status (`GET /api/v1/subscription`).
///
/// Best-effort: uses [api] so a network/permission failure returns `null`
/// (and never blocks a screen). Result is cached for the session; call
/// [invalidate] after a payment or on logout.
class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  SubscriptionStatus? _cache;

  SubscriptionStatus? get cached => _cache;

  Future<SubscriptionStatus?> getStatus({bool force = false}) async {
    if (_cache != null && !force) return _cache;
    final res = await api(Api.get, 'subscription');
    final data = res?.data;
    if (data is! Map<String, dynamic>) return null;
    _cache = SubscriptionStatus.fromJson(data);
    return _cache;
  }

  void invalidate() => _cache = null;
}
