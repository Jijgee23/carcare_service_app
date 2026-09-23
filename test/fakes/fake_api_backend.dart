import 'package:dio/dio.dart';

/// Fakes the network boundary for [ApiService]'s singleton `Dio` instance.
///
/// Several dependencies in this app are true singletons with no constructor
/// injection seam: `SubscriptionService.instance`, `DeviceService.instance`,
/// `ApiService.instance` itself, and every screen/controller that falls back
/// to a default `XRepository()` (e.g. `AppShell`'s
/// `NotificationController()..load()`, `ProfileScreen`'s
/// `MeRepository()`). None of that can be faked by constructor injection
/// without a production-code change, which this slice is not allowed to
/// make (see the P0-F4 report for the full list of call sites this covers).
///
/// [FakeApiBackend] intercepts Dio itself instead:
///
/// - A registered script ([on] / [onJson]) answers a specific method+path
///   with a canned response — used when a test's assertion depends on the
///   parsed result (e.g. the subscription-locked router test needs
///   `GET subscription` to actually return `locked: true`).
/// - Anything unscripted is rejected immediately with a `connectionError`,
///   the same shape a real offline device would produce. Every repository
///   in this app already turns that into a safe `AppError`/`null` — this
///   only prevents an unmocked request from hitting a real socket and
///   hanging the test on its 5s connect/receive timeout.
///
/// Installed once by `flutter_test_config.dart`. Call [reset] in a test's
/// `setUp` (not just when a test needs a script) — the underlying
/// `ApiService.instance` is a genuine process-wide singleton shared by every
/// test in the same file, so a script or logged request from one test would
/// otherwise leak into the next.
class FakeApiBackend extends Interceptor {
  FakeApiBackend._();

  static final FakeApiBackend instance = FakeApiBackend._();

  final _scripts = <_Script>[];

  /// Every request this backend has seen since the last [reset], in order.
  final List<RequestOptions> requests = [];

  /// Answers the first request whose method matches [method] and whose path
  /// contains [pathContains] (a substring match — repositories append query
  /// strings this helper shouldn't need to replicate exactly) with whatever
  /// [respond] returns.
  void on(
    String method,
    String pathContains,
    Response Function(RequestOptions options) respond,
  ) {
    _scripts.add(_Script(method.toUpperCase(), pathContains, respond));
  }

  /// Convenience for the common case of a canned JSON body.
  void onJson(
    String method,
    String pathContains,
    Map<String, dynamic> data, {
    int statusCode = 200,
  }) {
    on(
      method,
      pathContains,
      (options) => Response(requestOptions: options, statusCode: statusCode, data: data),
    );
  }

  void reset() {
    _scripts.clear();
    requests.clear();
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    final method = options.method.toUpperCase();
    for (final script in _scripts) {
      if (script.method == method && options.path.contains(script.pathContains)) {
        handler.resolve(script.respond(options));
        return;
      }
    }
    // Default-deny: fail fast (no real socket, no timeout) instead of
    // silently trying — and possibly succeeding against — a real backend.
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error:
            'FakeApiBackend: no script registered for $method ${options.path}. '
            'Tests have no real network by default — call '
            'FakeApiBackend.instance.on(...)/.onJson(...) if this endpoint '
            'needs to succeed for this test.',
      ),
    );
  }
}

class _Script {
  final String method;
  final String pathContains;
  final Response Function(RequestOptions options) respond;
  const _Script(this.method, this.pathContains, this.respond);
}
