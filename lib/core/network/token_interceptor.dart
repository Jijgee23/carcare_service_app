import 'dart:async';

import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:dio/dio.dart';

/// How a refresh attempt ended. Only [rejected] ends the session — a network
/// blip, a 429 from the per-IP refresh limit or a 5xx must never sign staff
/// out, because their refresh token is still perfectly valid.
enum RefreshOutcome { refreshed, rejected, transient }

/// Adds the bearer token and, on a 401, refreshes once (single-flight) and
/// replays the request.
///
/// Rules, each of which used to be a way to get logged out for nothing:
/// - the user is signed out only when `auth/refresh` itself rejects the
///   refresh token (401/403);
/// - an error from the *replayed* request (422, 404, timeout, …) is passed to
///   the caller as-is — it says nothing about the session;
/// - the replay keeps every request option (responseType for PDFs,
///   contentType, timeouts, extra) and re-sends a fresh copy of multipart
///   bodies, which Dio cannot send twice;
/// - a replayed request that 401s again is not refreshed a second time.
class TokenInterceptor extends Interceptor {
  TokenInterceptor(this.dio, {Dio? refreshDio})
    : _refreshDio =
          refreshDio ??
          Dio(
            BaseOptions(
              baseUrl: dio.options.baseUrl,
              headers: {'Content-Type': 'application/json'},
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  final Dio dio;
  final Dio _refreshDio;

  static const _retriedKey = 'token_interceptor_retried';

  Future<RefreshOutcome>? _inFlight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final user = Authenticator.user;
    if (user != null) {
      options.headers['Authorization'] = 'Bearer ${user.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        req.path == 'auth/refresh' ||
        req.extra[_retriedKey] == true ||
        Authenticator.user == null) {
      return handler.next(err);
    }

    final outcome = await (_inFlight ??= _refresh().whenComplete(
      () => _inFlight = null,
    ));

    switch (outcome) {
      case RefreshOutcome.rejected:
        await _forceLogout();
        return handler.next(err);
      case RefreshOutcome.transient:
        // Session kept; the caller sees the original 401 and can retry.
        return handler.next(err);
      case RefreshOutcome.refreshed:
        try {
          return handler.resolve(await dio.fetch<dynamic>(_replayOf(req)));
        } on DioException catch (retryError) {
          return handler.next(retryError);
        }
    }
  }

  RequestOptions _replayOf(RequestOptions req) {
    final data = req.data;
    return req.copyWith(
      data: data is FormData ? data.clone() : data,
      headers: {
        ...req.headers,
        'Authorization': 'Bearer ${Authenticator.user?.accessToken}',
      },
      extra: {...req.extra, _retriedKey: true},
    );
  }

  Future<RefreshOutcome> _refresh() async {
    final user = Authenticator.user;
    if (user == null) return RefreshOutcome.rejected;

    final Response<dynamic> res;
    try {
      res = await _refreshDio.post<dynamic>(
        'auth/refresh',
        data: {'refreshToken': user.refreshToken},
        options: Options(validateStatus: (_) => true),
      );
    } on DioException {
      return RefreshOutcome.transient;
    }

    final status = res.statusCode ?? 0;
    final data = res.data;
    if (status == 200 &&
        data is Map &&
        data['accessToken'] is String &&
        data['refreshToken'] is String) {
      // Re-read after the await so a profile update that landed meanwhile
      // is not overwritten with the pre-refresh copy.
      final latest = Authenticator.user;
      if (latest == null) return RefreshOutcome.rejected;
      Authenticator.user = User(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        id: latest.id,
        email: latest.email,
        firstName: latest.firstName,
        lastName: latest.lastName,
        phone: latest.phone,
        isOwner: latest.isOwner,
        branchId: latest.branchId,
        role: latest.role,
        tenant: latest.tenant,
      );
      return RefreshOutcome.refreshed;
    }
    // 401 (invalid/expired/reused) and 403 (tenant suspended) are the server
    // saying this session is over; anything else is worth another try later.
    if (status == 401 || status == 403) return RefreshOutcome.rejected;
    return RefreshOutcome.transient;
  }

  Future<void> _forceLogout() async {
    await Authenticator.clear();
    Authenticator.onUnauthorized?.call();
  }
}
