import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/keys/keys.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/services/notification_router.dart';
import 'package:carcare_service/core/services/subscription_service.dart';
import 'package:carcare_service/features/controllers.dart';
import 'package:carcare_service/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_api_backend.dart';
import '../../support/app_harness.dart';
import '../../support/hive_test_setup.dart';

void main() {
  setUpAll(openTestHiveBoxes);

  setUp(() {
    FakeApiBackend.instance.reset();
    SubscriptionService.instance.invalidate();
  });

  testWidgets(
    'authenticated order notification reaches the routed detail screen',
    (tester) async {
      Authenticator.user = User(
        accessToken: 'test-token',
        refreshToken: 'test-refresh',
        id: 'test-user',
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        phone: '',
        isOwner: false,
        role: UserRole('test-role', 'Test role', const ['orders.view']),
        tenant: UserTenant('test-tenant', 'Test tenant'),
      );
      addTearDown(() => Authenticator.user = null);

      final harness = RouterHarness();
      addTearDown(harness.dispose);
      addTearDown(() {
        if (identical(GlobalKeys.router, harness.router)) GlobalKeys.router = null;
      });
      harness.authController.setAuthState(AuthState.authorized);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      NotificationRouter.route({'orderId': 'order-1'});
      await tester.pump();
      await tester.pumpAndSettle();

      expect(harness.location, '/orders/order-1');
      expect(find.byType(OrderDetailScreen), findsOneWidget);
    },
  );
}
