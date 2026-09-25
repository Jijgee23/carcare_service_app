import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/profile/data/account_data_source.dart';
import 'package:carcare_service/features/profile/data/account_dto.dart';
import 'package:carcare_service/features/profile/domain/account_repository.dart'
    as domain;
import 'package:carcare_service/features/profile/domain/account_session.dart';

/// Remote adapter for [domain.AccountRepository] — P8-F1. JSON and Dio stay
/// below the repository contract, matching every other Phase 6/7/8
/// repository.
class RemoteAccountRepository implements domain.AccountRepository {
  RemoteAccountRepository({AccountDataSource? dataSource})
    : _dataSource = dataSource ?? RemoteAccountDataSource();

  final AccountDataSource _dataSource;

  @override
  Future<Result<User>> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) async {
    try {
      final current = Authenticator.user;
      if (current == null) {
        return const Err(
          AppError(ErrorKind.unauthorized, 'Нэвтрэх шаардлагатай'),
        );
      }
      final dto = MeProfileDto.fromJson(
        await _dataSource.updateProfile({
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'phone': phone,
        }),
      );
      // Re-read after the await — see MeRepository.refresh: the stored
      // tokens may have been rotated while this request was in flight.
      final latest = Authenticator.user;
      if (latest == null) {
        return const Err(
          AppError(ErrorKind.unauthorized, 'Нэвтрэх шаардлагатай'),
        );
      }
      final updated = User(
        accessToken: latest.accessToken,
        refreshToken: latest.refreshToken,
        id: dto.id ?? latest.id,
        email: dto.email ?? latest.email,
        firstName: dto.firstName ?? latest.firstName,
        lastName: dto.lastName ?? latest.lastName,
        phone: dto.phone ?? latest.phone,
        isOwner: dto.isOwner ?? latest.isOwner,
        branchId: dto.branchId,
        role: dto.role != null
            ? UserRole(dto.role!.id, dto.role!.name, dto.role!.permissions)
            : latest.role,
        tenant: dto.tenant != null
            ? UserTenant(dto.tenant!.id, dto.tenant!.name)
            : latest.tenant,
      );
      Authenticator.user = updated;
      return Ok(updated);
    } catch (error) {
      return Err(_error(error, 'Профайл шинэчилж чадсангүй'));
    }
  }

  @override
  Future<Result<domain.PasswordChangeResult>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      return Ok(
        PasswordChangeResultDto.fromJson(
          await _dataSource.changePassword({
            'currentPassword': currentPassword,
            'newPassword': newPassword,
            'confirmPassword': confirmPassword,
          }),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Нууц үг солиход алдаа гарлаа'));
    }
  }

  @override
  Future<Result<domain.AccountSessionsPage>> getSessions({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      return Ok(
        AccountSessionsPageDto.fromJson(
          await _dataSource.getSessions({'page': page, 'pageSize': pageSize}),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Session жагсаалт ачаалж чадсангүй'));
    }
  }

  @override
  Future<Result<domain.RevokeSessionResult>> revokeSession(
    String id, {
    required AccountSessionSource source,
    bool isCurrent = false,
  }) async {
    try {
      RevokeSessionAckDto.fromJson(
        await _dataSource.revokeSession(
          id,
          source: source == AccountSessionSource.web ? 'web' : 'mobile',
        ),
      );
      return Ok(domain.RevokeSessionResult(loggedOut: isCurrent));
    } catch (error) {
      return Err(_error(error, 'Session цуцлаж чадсангүй'));
    }
  }

  @override
  Future<Result<domain.RevokeOtherSessionsResult>> revokeOtherSessions() async {
    try {
      return Ok(
        RevokeOtherSessionsResultDto.fromJson(
          await _dataSource.revokeOtherSessions(),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Бусад session цуцлаж чадсангүй'));
    }
  }
}

AppError _error(Object error, String fallback) => switch (error) {
  AppError value => value,
  AccountParseException value => AppError(ErrorKind.unknown, value.message),
  _ => AppError(ErrorKind.unknown, fallback),
};
