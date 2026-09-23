import 'dart:async';

import 'package:carcare_service/core/network/api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_backend.dart';

/// Runs once per test FILE (each is its own isolate), before that file's
/// `main()`. Its job is to make the handful of eager, non-injectable
/// singletons `main.dart` normally initialises safe to touch by accident —
/// mirroring why `carcare_customer_mobile/test/flutter_test_config.dart`
/// exists there, but for this app's hazards specifically:
///
/// 1. `ApiService._internal()` reads `dotenv.env['BASE_URL']!` — a
///    non-null assertion that throws the moment anything (a repository's
///    default constructor, a screen's `context.read<XController>()`) first
///    touches `ApiService.instance`, unless dotenv has already loaded
///    something. `dotenv.loadFromString` gives it a harmless value
///    synchronously (no real file I/O) so the singleton can construct.
/// 2. Once `ApiService` can construct, its `Dio` would otherwise attempt a
///    REAL network request to that harmless URL and hang until its 5s
///    timeout — this app's equivalent of the customer app's
///    `MissingPluginException`-that-looks-like-success hazard, just at the
///    network layer instead of a plugin channel. [FakeApiBackend] is
///    installed as an interceptor so every unscripted request fails fast
///    with a `connectionError` instead (which every repository already
///    handles as a safe `AppError`/`null`).
///
/// `Authenticator.user` (`lib/core/services/auth_storage.dart`) has an
/// analogous hazard — it reads `Hive.box<User>('auth')` with no guard — but
/// deliberately is NOT made safe here. A Hive box opened in this function's
/// prefix (before any test/testWidgets is registered) was observed, in this
/// environment, to silently stop being open by the time an individual test
/// body ran, even though the same `Hive` singleton object (same
/// `identityHashCode`) still had its type-adapter registration intact —
/// only the box registration was lost. A box opened from a test file's own
/// `setUpAll` does not have this problem. See
/// `test/support/hive_test_setup.dart`'s `openTestHiveBoxes()` (call it from
/// `setUpAll` in any test that touches `Authenticator`/`AppShell`) and the
/// P0-F4 report for the full diagnostic — this is a real, reported finding,
/// not a silently-worked-around gap.
///
/// `Hive.init(...)` (a real file-backed directory, giving every
/// `Hive.openBox(...)` call a valid home even without pre-opening a box —
/// which would fix `test/app/theme_test.dart`'s current `HiveError: You need
/// to initialize Hive` failures, see the P0-F4 report) was tried here and
/// deliberately REMOVED: it made two of that file's tests hang until
/// timeout instead of failing fast (real file-backed Hive box contention
/// under this sandbox, reproduced in isolation). A fast, clear failure in
/// someone else's owned test file is a smaller problem than this file
/// silently making a DIFFERENT file's tests hang — this file is shared
/// config, so the safer failure mode wins. Not this slice's file to fix
/// (`test/app/theme_test.dart` and `lib/app/theme/**` are P0-F3's).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  dotenv.loadFromString(envString: 'BASE_URL=http://fake-api-backend.test/api/v1/');

  ApiService.instance.dio.interceptors.insert(0, FakeApiBackend.instance);

  await testMain();
}
