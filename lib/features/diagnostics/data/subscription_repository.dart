import 'package:carservice_business/core/domain/subscription.dart';
import 'package:carservice_business/core/errors/app_error.dart';
import 'package:carservice_business/core/network/api_client.dart';
import 'package:carservice_business/core/utils/result.dart';

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
