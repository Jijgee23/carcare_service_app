import 'package:carcare_service/app/router.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/services/subscription_service.dart';
import 'package:carcare_service/features/controllers.dart';
import 'package:carcare_service/features/profile/presentation/screens/change_password_screen.dart';
import 'package:carcare_service/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:carcare_service/features/profile/presentation/screens/sessions_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_api_backend.dart';
import '../support/app_harness.dart';
import '../support/hive_test_setup.dart';

/// `P8-F3` — the three account-management `GoRoute`s (`/profile/edit`,
/// `/profile/password`, `/profile/sessions`) through the REAL
/// `buildRouter`, the same way `test/app/insight_router_test.dart`
/// exercises `/reports`/`/audit`/`/feedback`. None of these screens gates
/// on a permission — they act on `auth.user.id` only, matching the P8
/// invariant.
void main() {
  setUpAll(openTestHiveBoxes);

  setUp(() {
    FakeApiBackend.instance.reset();
    SubscriptionService.instance.invalidate();
  });

  User signedInUser() => User(
    accessToken: 'test-token',
    refreshToken: 'test-refresh',
    id: 'test-user',
    email: 'test@example.com',
    firstName: 'Test',
    lastName: 'User',
    phone: '',
    isOwner: true,
    tenant: UserTenant('test-tenant', 'Test tenant'),
  );

  Future<RouterHarness> boot(WidgetTester tester) async {
    Authenticator.user = signedInUser();
    addTearDown(() => Authenticator.user = null);
    final harness = RouterHarness();
    addTearDown(harness.dispose);
    harness.authController.setAuthState(AuthState.authorized);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    return harness;
  }

  testWidgets('/profile/edit resolves to the edit-profile screen', (tester) async {
    final harness = await boot(tester);

    harness.router.go(AppRoutes.profileEdit);
    await tester.pumpAndSettle();

    expect(harness.location, AppRoutes.profileEdit);
    expect(find.byType(EditProfileScreen), findsOneWidget);
  });

  testWidgets('/profile/password resolves to the change-password screen', (tester) async {
    final harness = await boot(tester);

    harness.router.go(AppRoutes.profilePassword);
    await tester.pumpAndSettle();

    expect(harness.location, AppRoutes.profilePassword);
    expect(find.byType(ChangePasswordScreen), findsOneWidget);
  });

  testWidgets('/profile/sessions resolves to the sessions screen', (tester) async {
    final harness = await boot(tester);

    harness.router.go(AppRoutes.profileSessions);
    await tester.pumpAndSettle();

    expect(harness.location, AppRoutes.profileSessions);
    expect(find.byType(SessionsScreen), findsOneWidget);
  });

  testWidgets('all three routes are distinct AppRoutes constants', (tester) async {
    expect(
      {AppRoutes.profileEdit, AppRoutes.profilePassword, AppRoutes.profileSessions},
      hasLength(3),
    );
    expect(AppRoutes.profileEdit, '/profile/edit');
    expect(AppRoutes.profilePassword, '/profile/password');
    expect(AppRoutes.profileSessions, '/profile/sessions');
  });
}
