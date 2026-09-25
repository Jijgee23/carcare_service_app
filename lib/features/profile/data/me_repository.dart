import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/domain/user.dart';

/// Refreshes the current staff profile from `GET /api/v1/me`.
///
/// The login response is decoded once at sign-in; role, branch or tenant name
/// can change server-side afterwards. This re-reads the authoritative profile
/// and merges it into the stored [User], preserving the local tokens (which
/// `/me` does not return). Best-effort: returns `null` on failure and leaves
/// the stored user untouched.
class MeRepository {
  Future<User?> refresh() async {
    if (Authenticator.user == null) return null;

    final res = await api(Api.get, 'me');
    final u = res?.data;
    if (u is! Map<String, dynamic>) return null;

    // Re-read AFTER the await: the token interceptor may have rotated the
    // tokens while `/me` was in flight. Writing back the pre-request copy
    // would store an already-rotated refresh token, and the server treats
    // reusing it as theft — revoking every session on every device.
    final latest = Authenticator.user;
    if (latest == null) return null; // signed out meanwhile — don't resurrect

    final r = u['role'] as Map<String, dynamic>?;
    final t = u['tenant'] as Map<String, dynamic>?;
    final b = u['branch'] as Map<String, dynamic>?;

    final updated = User(
      accessToken: latest.accessToken,
      refreshToken: latest.refreshToken,
      id: u['id'] as String? ?? latest.id,
      email: u['email'] as String? ?? latest.email,
      firstName: u['firstName'] as String? ?? latest.firstName,
      lastName: u['lastName'] as String? ?? latest.lastName,
      phone: u['phone']?.toString() ?? latest.phone,
      isOwner: u['isOwner'] as bool? ?? latest.isOwner,
      branchId: b?['id'] as String?,
      role: r != null
          ? UserRole(
              r['id'] as String,
              r['name'] as String,
              List<String>.from((r['permissions'] as List?) ?? const []),
            )
          : null,
      tenant: t != null
          ? UserTenant(t['id'] as String, t['name'] as String)
          : latest.tenant,
    );

    Authenticator.user = updated;
    return updated;
  }
}
