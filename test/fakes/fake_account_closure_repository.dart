import 'dart:async';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/profile/data/account_closure_repository.dart';

/// Hand-written fake for [AccountClosureRepository] — Task 8, matching
/// `FakeAccountRepository`'s convention (`test/features/profile/data/`):
/// a simple in-memory recorder rather than a Dio/Hive stand-in.
class FakeAccountClosureRepository implements AccountClosureRepository {
  /// Set to fail the next matching call with this server `code`
  /// (`'LAST_OWNER'` → 409, anything else → 422, matching the real API).
  String? failWith;

  String maskedPhoneToReturn = '9911**22';

  final List<String> calls = [];

  /// When set, `deactivate`/`delete` await this before resolving — lets a
  /// test simulate the backend's `account_closed` push arriving before the
  /// closure HTTP response returns (the response only "arrives" once this
  /// completes).
  Completer<void>? closureGate;

  AppError? _errorFor(String code) => AppError(
    ErrorKind.unknown,
    'Алдаа гарлаа',
    statusCode: code == 'LAST_OWNER' || code == 'OPEN_ORDERS' ? 409 : 422,
    code: code,
  );

  @override
  Future<Result<String>> requestOtp({bool forDelete = false}) async {
    calls.add(forDelete ? 'requestOtp:delete' : 'requestOtp');
    final code = failWith;
    if (code != null) return Err(_errorFor(code)!);
    return Ok(maskedPhoneToReturn);
  }

  @override
  Future<Result<void>> deactivate(String code) async {
    calls.add('deactivate:$code');
    await closureGate?.future;
    final failCode = failWith;
    if (failCode != null) return Err(_errorFor(failCode)!);
    return const Ok(null);
  }

  @override
  Future<Result<void>> delete(String code) async {
    calls.add('delete:$code');
    await closureGate?.future;
    final failCode = failWith;
    if (failCode != null) return Err(_errorFor(failCode)!);
    return const Ok(null);
  }
}
