import 'dart:typed_data';

import 'package:carcare_service/core/domain/user.dart';
import 'package:hive/hive.dart';

/// Opens the Hive boxes `Authenticator`/`DeviceService` read (`auth`,
/// `device`) against Hive's in-memory backend, so `Authenticator.user` and
/// friends are safe to touch by accident — default state is "no session" /
/// "no device id" instead of a `HiveError: Box not found`.
///
/// Call this from a test file's own `setUpAll(openTestHiveBoxes)` — NOT from
/// `flutter_test_config.dart`. A box opened in `flutter_test_config.dart`'s
/// `testExecutable` prefix (i.e. before any `test()`/`testWidgets()` is
/// registered) was observed, in this environment, to report
/// `Hive.isBoxOpen(...) == true` immediately after opening there, then
/// `false` again by the time any individual test body ran — same `Hive`
/// singleton object, confirmed via `identityHashCode`, and adapter
/// registration on that same object survived while the box registration did
/// not. Root cause not fully identified (suspected: something about how
/// `package:test`'s registration phase — `main()`'s synchronous prefix —
/// versus its later per-test execution phase treats state opened before any
/// test exists). A box opened from `setUpAll`, which runs within the normal
/// test-registration/execution flow rather than before it, does not have
/// this problem, verified across multiple tests and through
/// `pumpAndSettle` — see the P0-F4 report for the full diagnostic.
///
/// Idempotent: safe to call from multiple `setUpAll`s / already-open boxes.
Future<void> openTestHiveBoxes() async {
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(UserAdapter());
  }
  if (!Hive.isBoxOpen('auth')) {
    await Hive.openBox<User>('auth', bytes: Uint8List(0));
  }
  if (!Hive.isBoxOpen('device')) {
    await Hive.openBox('device', bytes: Uint8List(0));
  }
}
