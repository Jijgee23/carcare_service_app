import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/widgets/adaptive/permission_gate.dart';
import 'package:flutter_test/flutter_test.dart';

User _user(List<String> permissions) => User(
  accessToken: 'token',
  refreshToken: 'refresh',
  id: 'user',
  email: 'user@example.test',
  firstName: 'Test',
  lastName: 'User',
  phone: '99001122',
  isOwner: false,
  role: UserRole('role', 'Role', permissions),
  tenant: UserTenant('tenant', 'Tenant'),
);

void main() {
  test('orders.viewOwn exposes only the Orders view affordance', () {
    final own = _user(const ['orders.viewOwn']);

    expect(canSeeView(own, 'orders'), isTrue);
    expect(canSeeView(own, 'orders.view'), isFalse);
    expect(canSeeView(own, 'appointments'), isFalse);
  });

  test('orders.view retains full-view behavior', () {
    final full = _user(const ['orders.view']);

    expect(canSeeView(full, 'orders'), isTrue);
    expect(canSeeView(full, 'orders.view'), isTrue);
    expect(canSeeView(full, 'customers'), isFalse);
  });
}
