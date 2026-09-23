import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'completer_queue.dart';

/// A minimal loader with a correct request-generation guard — i.e. what
/// `NotificationController.load()` (or `OrderController.loadOrders()`, etc.)
/// should look like once guarded. This class lives only in this test file:
/// it is NOT a port of any `lib/` controller, just a small, honest
/// demonstration that [CompleterQueue] can prove a guard actually works, not
/// only that it can prove one is missing (see
/// `notification_controller_race_test.dart` for the latter, against real
/// production code).
class _GuardedLoader {
  int _requestId = 0;
  List<String>? value;

  _GuardedLoader(this._load);
  final Future<List<String>> Function() _load;

  Future<void> load() async {
    final requestId = ++_requestId;
    final result = await _load();
    if (requestId != _requestId) return; // a newer load() started meanwhile
    value = result;
  }
}

void main() {
  group('CompleterQueue', () {
    test('records calls in call order and resolves them independently', () async {
      final queue = CompleterQueue<int>();

      final first = queue.next();
      final second = queue.next();
      expect(queue.callCount, 2);

      // Resolve out of order: second before first.
      queue.resolve(1, 20);
      queue.resolve(0, 10);

      expect(await second, 20);
      expect(await first, 10);
    });

    test('resolveError delivers an error to the pending future', () async {
      final queue = CompleterQueue<int>();
      final call = queue.next();

      queue.resolveError(0, StateError('boom'));

      await expectLater(call, throwsA(isA<StateError>()));
    });
  });

  group('worked example: request-generation guard', () {
    test('a guarded loader keeps the newer result when the stale one '
        'resolves late', () async {
      final queue = CompleterQueue<List<String>>();
      final loader = _GuardedLoader(queue.next);

      unawaited(loader.load()); // call #0 — slow
      final second = loader.load(); // call #1 — fast
      expect(queue.callCount, 2);

      queue.resolve(1, ['newer']);
      await second;
      queue.resolve(0, ['older']);
      await Future<void>.delayed(Duration.zero);

      expect(loader.value, ['newer']);
    });

    test('an UNGUARDED loader is vulnerable to the same race (sanity check '
        'that the assertion above is meaningful, not just always true)', () async {
      final queue = CompleterQueue<List<String>>();
      String? last;
      Future<void> load() async => last = (await queue.next()).single;

      unawaited(load());
      final second = load();
      queue.resolve(1, ['newer']);
      await second;
      queue.resolve(0, ['older']);
      await Future<void>.delayed(Duration.zero);

      // Without a guard, whichever resolves LAST wins outright — here
      // that's the stale call, so `last` ends up wrong.
      expect(last, 'older');
    });
  });
}
