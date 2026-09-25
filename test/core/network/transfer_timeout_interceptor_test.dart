import 'package:carcare_service/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Capture extends RequestInterceptorHandler {
  RequestOptions? passed;
  @override
  void next(RequestOptions requestOptions) => passed = requestOptions;
}

RequestOptions _run(RequestOptions options) {
  final handler = _Capture();
  const TransferTimeoutInterceptor().onRequest(options, handler);
  return handler.passed!;
}

void main() {
  const long = TransferTimeoutInterceptor.transferTimeout;

  test('multipart uploads get the long send + receive timeout', () {
    final o = _run(
      RequestOptions(path: 'diagnostics/reports', data: FormData()),
    );
    expect(o.sendTimeout, long);
    expect(o.receiveTimeout, long);
  });

  test('byte downloads (PDF / Excel) get the long receive timeout', () {
    final o = _run(
      RequestOptions(path: 'reports/export', responseType: ResponseType.bytes),
    );
    expect(o.receiveTimeout, long);
  });

  test('ordinary JSON calls keep the client defaults', () {
    final o = _run(RequestOptions(path: 'orders', data: {'a': 1}));
    expect(o.sendTimeout, isNull);
    expect(o.receiveTimeout, isNull);
  });
}
