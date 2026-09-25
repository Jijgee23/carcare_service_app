import 'dart:convert';
import 'dart:typed_data';

import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/network/token_interceptor.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/hive_test_setup.dart';

/// Answers each request from a per-path script and records what was sent.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.script);

  /// path → list of (status, body) replies, consumed in order.
  final Map<String, List<(int, Object?)>> script;
  final requests = <RequestOptions>[];
  final sentBodies = <String>[];

  /// Throw a connection error for this path instead of answering.
  final failPaths = <String>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      sentBodies.add(utf8.decode(bytes, allowMalformed: true));
    }
    if (failPaths.contains(options.path)) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    final queue = script[options.path];
    if (queue == null || queue.isEmpty) {
      throw StateError('No scripted reply for ${options.path}');
    }
    final (status, body) = queue.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  List<String> get paths => requests.map((r) => r.path).toList();

  String? authOf(int i) => requests[i].headers['Authorization'] as String?;
}

User _user({String access = 'access-1', String refresh = 'refresh-1'}) => User(
  accessToken: access,
  refreshToken: refresh,
  id: 'u-1',
  email: 'a@b.mn',
  firstName: 'Бат',
  lastName: 'Болд',
  phone: '99112233',
  isOwner: false,
  tenant: UserTenant('t-1', 'Карком'),
);

void main() {
  setUpAll(openTestHiveBoxes);

  late _ScriptedAdapter adapter;
  late Dio dio;
  late int forcedLogouts;

  const refreshed = {'accessToken': 'access-2', 'refreshToken': 'refresh-2'};

  setUp(() async {
    Authenticator.user = _user();
    forcedLogouts = 0;
    Authenticator.onUnauthorized = () => forcedLogouts++;
    adapter = _ScriptedAdapter({});
    dio = Dio(BaseOptions(baseUrl: 'https://api.test/'))
      ..httpClientAdapter = adapter;
    final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.test/'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(TokenInterceptor(dio, refreshDio: refreshDio));
  });

  tearDown(() async {
    Authenticator.onUnauthorized = null;
    await Authenticator.clear();
  });

  test(
    '401 → refresh → replay with the new token, rotated tokens stored',
    () async {
      adapter.script
        ..['orders'] = [
          (401, {'error': 'expired'}),
          (200, {'ok': true}),
        ]
        ..['auth/refresh'] = [(200, refreshed)];

      final res = await dio.get<dynamic>('orders');

      expect(res.data, {'ok': true});
      expect(adapter.paths, ['orders', 'auth/refresh', 'orders']);
      expect(adapter.authOf(0), 'Bearer access-1');
      expect(adapter.authOf(2), 'Bearer access-2');
      expect(Authenticator.user!.refreshToken, 'refresh-2');
      expect(forcedLogouts, 0);
    },
  );

  test('a replay that fails with 422 is passed through — no logout', () async {
    adapter.script
      ..['orders'] = [
        (401, {'error': 'expired'}),
        (
          422,
          {
            'error': 'Буруу',
            'fieldErrors': {'x': 'y'},
          },
        ),
      ]
      ..['auth/refresh'] = [(200, refreshed)];

    final error = await dio
        .post<dynamic>('orders', data: {'a': 1})
        .then<DioException?>(
          (_) => null,
          onError: (Object e) => e as DioException,
        );

    expect(error?.response?.statusCode, 422);
    expect(error?.response?.data, containsPair('error', 'Буруу'));
    expect(forcedLogouts, 0);
    expect(Authenticator.user, isNotNull);
  });

  test('refresh rejected (401) is the only thing that logs out', () async {
    adapter.script
      ..['orders'] = [
        (401, {'error': 'expired'}),
      ]
      ..['auth/refresh'] = [
        (401, {'error': 'reused', 'reason': 'reused'}),
      ];

    await expectLater(dio.get<dynamic>('orders'), throwsA(isA<DioException>()));
    expect(forcedLogouts, 1);
    expect(Authenticator.user, isNull);
  });

  test('refresh network failure keeps the session', () async {
    adapter.script['orders'] = [
      (401, {'error': 'expired'}),
    ];
    adapter.failPaths.add('auth/refresh');

    await expectLater(dio.get<dynamic>('orders'), throwsA(isA<DioException>()));
    expect(forcedLogouts, 0);
    expect(Authenticator.user?.refreshToken, 'refresh-1');
  });

  test('refresh 429 (per-IP limit) keeps the session', () async {
    adapter.script
      ..['orders'] = [
        (401, {'error': 'expired'}),
      ]
      ..['auth/refresh'] = [
        (429, {'error': 'Хэт олон хүсэлт'}),
      ];

    await expectLater(dio.get<dynamic>('orders'), throwsA(isA<DioException>()));
    expect(forcedLogouts, 0);
    expect(Authenticator.user, isNotNull);
  });

  test('concurrent 401s share one refresh', () async {
    adapter.script
      ..['a'] = [
        (401, {}),
        (200, {'n': 'a'}),
      ]
      ..['b'] = [
        (401, {}),
        (200, {'n': 'b'}),
      ]
      ..['auth/refresh'] = [(200, refreshed)];

    final results = await Future.wait([
      dio.get<dynamic>('a'),
      dio.get<dynamic>('b'),
    ]);

    expect(results.map((r) => r.data['n']), ['a', 'b']);
    expect(adapter.paths.where((p) => p == 'auth/refresh').length, 1);
  });

  test(
    'replay keeps responseType (PDF bytes) and re-sends multipart',
    () async {
      adapter.script
        ..['diagnostics/reports'] = [
          (401, {}),
          (200, {'id': 'r-1'}),
        ]
        ..['auth/refresh'] = [(200, refreshed)];

      final form = FormData.fromMap({
        'note': 'hello',
        'photo': MultipartFile.fromBytes([1, 2, 3], filename: 'a.jpg'),
      });
      final res = await dio.post<dynamic>(
        'diagnostics/reports',
        data: form,
        options: Options(responseType: ResponseType.bytes),
      );

      expect(res.statusCode, 200);
      expect(res.data, isA<List<int>>()); // responseType survived the replay
      final multipartBodies = adapter.sentBodies.where(
        (b) => b.contains('hello'),
      );
      expect(multipartBodies.length, 2); // original + fresh replay copy
    },
  );

  test('a replay that 401s again is not refreshed twice', () async {
    adapter.script
      ..['orders'] = [(401, {}), (401, {})]
      ..['auth/refresh'] = [(200, refreshed)];

    await expectLater(dio.get<dynamic>('orders'), throwsA(isA<DioException>()));
    expect(adapter.paths, ['orders', 'auth/refresh', 'orders']);
    expect(forcedLogouts, 0);
  });

  test('no stored user: 401 passes straight through', () async {
    await Authenticator.clear();
    adapter.script['me'] = [(401, {})];
    await expectLater(dio.get<dynamic>('me'), throwsA(isA<DioException>()));
    expect(adapter.paths, ['me']);
  });
}
