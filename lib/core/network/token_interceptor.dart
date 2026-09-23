import 'dart:async';

import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:dio/dio.dart';

class TokenInterceptor extends Interceptor {
  final Dio dio;
  final Dio _refreshDio;

  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  TokenInterceptor(this.dio)
    : _refreshDio = Dio(
        BaseOptions(
          baseUrl: dio.options.baseUrl,
          headers: {'Content-Type': 'application/json'},
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final user = Authenticator.user;
    if (user != null) {
      options.headers['Authorization'] = 'Bearer ${user.accessToken}';
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    final path = err.requestOptions.path;
    if (path == 'auth/refresh' || path == 'auth/login') {
      await _forceLogout();
      return handler.reject(err);
    }

    if (Authenticator.user == null) {
      return handler.reject(err);
    }

    try {
      final bool refreshed;
      if (_isRefreshing) {
        refreshed = await _refreshCompleter!.future;
      } else {
        refreshed = await _doRefresh();
      }

      if (!refreshed) {
        await _forceLogout();
        return handler.reject(err);
      }

      final response = await _retry(err.requestOptions);
      return handler.resolve(response);
    } catch (_) {
      await _forceLogout();
      return handler.reject(err);
    }
  }

  Future<bool> _doRefresh() async {
    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      final user = Authenticator.user;
      if (user == null) {
        _refreshCompleter!.complete(false);
        return false;
      }

      final res = await _refreshDio.post('auth/refresh', data: {'refreshToken': user.refreshToken});

      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        Authenticator.user = User(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
          id: user.id,
          email: user.email,
          firstName: user.firstName,
          lastName: user.lastName,
          phone: user.phone,
          isOwner: user.isOwner,
          branchId: user.branchId,
          role: user.role,
          tenant: user.tenant,
        );
        _refreshCompleter!.complete(true);
        return true;
      }

      _refreshCompleter!.complete(false);
      return false;
    } catch (_) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Response> _retry(RequestOptions req) {
    final user = Authenticator.user;
    return dio.request(
      req.path,
      data: req.data,
      queryParameters: req.queryParameters,
      options: Options(
        method: req.method,
        headers: {...req.headers, 'Authorization': 'Bearer ${user?.accessToken}'},
      ),
    );
  }

  Future<void> _forceLogout() async {
    await Authenticator.clear();
    Authenticator.onUnauthorized?.call();
  }
}
