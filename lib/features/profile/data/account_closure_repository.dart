import 'package:carservice_business/core/errors/app_error.dart';
import 'package:carservice_business/core/network/api_client.dart';
import 'package:carservice_business/core/network/dio_error_mapper.dart';
import 'package:carservice_business/core/utils/result.dart';
import 'package:dio/dio.dart';

/// Self-service account deactivate/delete — Task 8. Scope is the staff
/// user's own `User` only (D1); tenant/org data is untouched.
///
/// Deactivation has no expiry — logging back in reactivates the account
/// (D3/D4). Delete forever anonymizes the account's PII immediately and
/// cannot be undone (D2); business records stay, linked to the tombstone.
/// Both actions require an OTP sent to the account's phone (D4).
///
/// Uses a direct `Dio` request + `mapDioException`, mirroring
/// `RemoteAccountRepository`'s style rather than the `api()` toast helper:
/// the caller needs a typed [Result] so it can distinguish `422 OTP_INVALID`
/// and `409 LAST_OWNER` from a generic failure — `api()` swallows the error
/// body into a toast and returns `null`, which loses that distinction.
abstract interface class AccountClosureRepository {
  /// `POST /api/v1/me/close/request-otp` — `{}`, or `{purpose: "delete"}`
  /// when [forDelete]. Sends a code to the account's phone and returns the
  /// masked phone number on success. With [forDelete] the server refuses
  /// up front with `409 OPEN_ORDERS` (before any SMS) if the user still has
  /// scheduled/in-progress orders assigned.
  Future<Result<String>> requestOtp({bool forDelete = false});

  /// `POST /api/v1/me/deactivate` — `{code}`. Never sets `isActive=false`
  /// (that flag stays reserved for an admin block); the account simply stops
  /// showing up until the user logs in again. Fails `409 LAST_OWNER` if the
  /// caller is the tenant's last active owner.
  Future<Result<void>> deactivate(String code);

  /// `POST /api/v1/me/delete` — `{code}`. Anonymizes PII immediately and
  /// sets `isActive=false` as a belt-and-braces measure; cannot be undone.
  /// Fails `409 LAST_OWNER` if the caller is the tenant's last active owner.
  Future<Result<void>> delete(String code);
}

class RemoteAccountClosureRepository implements AccountClosureRepository {
  RemoteAccountClosureRepository({Dio? dio}) : _dio = dio ?? ApiService.instance.dio;

  final Dio _dio;

  Future<Response<dynamic>> _post(String path, [Object? body]) async {
    try {
      return await _dio.request(
        path,
        data: body,
        options: Options(method: 'POST'),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<Result<String>> requestOtp({bool forDelete = false}) async {
    try {
      final res = await _post(
        'me/close/request-otp',
        forDelete ? const {'purpose': 'delete'} : const <String, dynamic>{},
      );
      final data = res.data;
      final masked = data is Map ? data['maskedPhone'] : null;
      if (masked is! String) {
        return const Err(
          AppError(ErrorKind.unknown, 'Код илгээж чадсангүй'),
        );
      }
      return Ok(masked);
    } catch (error) {
      return Err(_error(error, 'Код илгээж чадсангүй'));
    }
  }

  @override
  Future<Result<void>> deactivate(String code) => _submit('me/deactivate', code);

  @override
  Future<Result<void>> delete(String code) => _submit('me/delete', code);

  Future<Result<void>> _submit(String path, String code) async {
    try {
      await _post(path, {'code': code});
      return const Ok(null);
    } catch (error) {
      return Err(_error(error, 'Хүсэлт биелэхгүй байна'));
    }
  }
}

AppError _error(Object error, String fallback) =>
    error is AppError ? error : AppError(ErrorKind.unknown, fallback);
