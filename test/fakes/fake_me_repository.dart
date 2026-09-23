import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/features/profile/data/me_repository.dart';

/// Hand-written fake for [MeRepository] (concrete class, no abstract
/// interface — see `fake_order_repository.dart` for why this extends rather
/// than implements).
///
/// The real `refresh()` reads/writes `Authenticator.user` (a Hive-backed
/// static), which is exactly the kind of global mutable state a fake should
/// avoid touching. This override ignores that entirely and returns a fixed
/// [user] instead — it exercises callers of `MeRepository` (there is
/// currently no constructor-injection seam for it; `ProfileScreen` hardcodes
/// `MeRepository()` — see the P0-F4 report) without any Hive dependency.
class FakeMeRepository extends MeRepository {
  FakeMeRepository({User? user}) : _user = user ?? _defaultUser();

  /// Simulates the real repository's "no session" outcome (`refresh()`
  /// returns `null` when there is no signed-in user to refresh).
  FakeMeRepository.noSession() : _user = null;

  final User? _user;

  static User _defaultUser() => User(
        accessToken: 'fake-access-token',
        refreshToken: 'fake-refresh-token',
        id: 'user-1',
        email: 'staff@carcare.mn',
        firstName: 'Бат',
        lastName: 'Болд',
        phone: '99001122',
        isOwner: false,
        branchId: 'branch-1',
        role: UserRole('role-1', 'Ажилтан', const ['orders.read']),
        tenant: UserTenant('tenant-1', 'CarCare засвар'),
      );

  @override
  Future<User?> refresh() async => _user;
}
