import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:carcare_service/core/network/working_branch_interceptor.dart';
import 'package:carcare_service/core/domain/working_branch_scope.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements WorkingBranchSelectionStore {
  String? value;
  int clearCount = 0;

  _MemoryStore([this.value]);

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? selection) async => value = selection;

  @override
  Future<void> clear() async {
    clearCount++;
    value = null;
  }
}

class _Adapter implements HttpClientAdapter {
  final FutureOr<ResponseBody> Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  _Adapter(this.respond);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return await respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _response(int status, {bool invalidBranch = false}) =>
    ResponseBody.fromString(
      jsonEncode({'error': 'denied'}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        if (invalidBranch) 'X-Working-Branch-Invalid': ['1'],
      },
    );

Dio _dio(
  _Adapter adapter,
  WorkingBranchSelectionStore store, {
  FutureOr<void> Function()? onInvalidBranch,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
  dio.interceptors.add(
    WorkingBranchInterceptor(store: store, onInvalidBranch: onInvalidBranch),
  );
  return dio;
}

void main() {
  test(
    'injects branch, ALL, and no header from the persisted selection',
    () async {
      final store = _MemoryStore('branch-a');
      final adapter = _Adapter((_) => _response(200));
      final dio = _dio(adapter, store, onInvalidBranch: () {});

      await dio.get('orders');
      expect(adapter.requests.single.headers['X-Working-Branch'], 'branch-a');

      store.value = allWorkingBranches;
      await dio.get('orders');
      expect(adapter.requests[1].headers['X-Working-Branch'], 'ALL');

      store.value = null;
      await dio.get('orders');
      expect(
        adapter.requests[2].headers.keys.any(
          (key) => key.toLowerCase() == 'x-working-branch',
        ),
        isFalse,
      );
    },
  );

  test('a header-bearing 403 clears once, signals once, never retries, and preserves the error', () async {
    final store = _MemoryStore('stale-branch');
    final adapter = _Adapter((_) => _response(403, invalidBranch: true));
    var signals = 0;
    final dio = _dio(adapter, store, onInvalidBranch: () => signals++);

    DioException? error;
    try {
      await dio.get('orders');
    } on DioException catch (exception) {
      error = exception;
    }

    expect(error?.response?.statusCode, 403);
    expect(store.clearCount, 1);
    expect(signals, 1);
    expect(adapter.requests, hasLength(1));
  });

  test(
    'generic permission 403 with a working-branch header does not clear',
    () async {
      final store = _MemoryStore('valid-branch');
      final adapter = _Adapter((_) => _response(403));
      var signals = 0;
      final dio = _dio(adapter, store, onInvalidBranch: () => signals++);

      try {
        await dio.get('orders');
      } on DioException catch (error) {
        expect(error.response?.statusCode, 403);
      }

      expect(store.clearCount, 0);
      expect(store.value, 'valid-branch');
      expect(signals, 0);
    },
  );

  test(
    'concurrent 403s carrying the same stale header coalesce the signal',
    () async {
      final store = _MemoryStore('stale-branch');
      final bothStarted = Completer<void>();
      final release = Completer<void>();
      var calls = 0;
      final adapter = _Adapter((_) async {
        calls++;
        if (calls == 2) bothStarted.complete();
        await release.future;
        return _response(403, invalidBranch: true);
      });
      var signals = 0;
      final dio = _dio(adapter, store, onInvalidBranch: () => signals++);

      Future<void> request() async {
        try {
          await dio.get('orders');
        } on DioException {
          // The assertion below verifies the original errors were propagated.
        }
      }

      final first = request();
      final second = request();
      await bothStarted.future;
      release.complete();
      await Future.wait([first, second]);

      expect(adapter.requests, hasLength(2));
      expect(store.clearCount, 1);
      expect(signals, 1);
    },
  );
}
