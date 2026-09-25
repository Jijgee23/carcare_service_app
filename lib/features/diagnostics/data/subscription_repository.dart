import 'package:carcare_service/core/domain/subscription.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/utils/result.dart';

class SubscriptionRepository {
  Future<Result<SubscriptionStatus>> getStatus() async {
    try {
      final res = await apiOrThrow(Api.get, 'subscription');
      return Ok(SubscriptionStatus.fromJson(res.data as Map<String, dynamic>));
    } on AppError catch (e) {
      return Err(e);
    }
  }
}
