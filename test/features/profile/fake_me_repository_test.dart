import 'package:carcare_service/core/domain/user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_me_repository.dart';

void main() {
  test('refresh returns the default fake user', () async {
    final repo = FakeMeRepository();

    final user = await repo.refresh();

    expect(user, isNotNull);
    expect(user!.email, 'staff@carcare.mn');
    expect(user.tenant.name, 'CarCare засвар');
  });

  test('refresh returns whatever user was supplied', () async {
    final custom = User(
      accessToken: 'a',
      refreshToken: 'b',
      id: 'u2',
      email: 'owner@carcare.mn',
      firstName: 'Оюун',
      lastName: 'Эрдэнэ',
      phone: '99887766',
      isOwner: true,
      tenant: UserTenant('t2', 'Хоёрдугаар байгууллага'),
    );
    final repo = FakeMeRepository(user: custom);

    expect((await repo.refresh())?.id, 'u2');
  });

  test('refresh can simulate the "no session" case', () async {
    final repo = FakeMeRepository.noSession();

    expect(await repo.refresh(), isNull);
  });
}
