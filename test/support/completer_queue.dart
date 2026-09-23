import 'dart:async';

/// Lets a test control the order in which a sequence of overlapping async
/// calls resolves — the pattern needed to reproduce "a stale response
/// arrives after a newer one" races, the exact bug class a
/// request-generation guard (`_loadRequestId` and friends) exists to
/// prevent. Ported from the ad hoc `_RaceNotificationsRepository` /
/// `_CountingXRepository` classes `carcare_customer_mobile` rewrote per
/// controller — extracted here as one reusable piece so later slices
/// (P0-F7 and onward) don't reinvent it.
///
/// A fake repository method that should behave asynchronously under test
/// control calls [next] instead of returning real data immediately; [next]
/// hands back a `Future` the test resolves explicitly, in whatever order it
/// wants, via [resolve] / [resolveError]. Calls are recorded in [pending] in
/// the order they were MADE (not the order they resolve), so a test can
/// target "the first call" or "the second call" by index regardless of
/// which one finishes first.
///
/// Usage — reproduce "a slower first load loses to a faster second load":
/// ```dart
/// class _RaceRepository extends SomeRepository {
///   final queue = CompleterQueue<List<Foo>>();
///   @override
///   Future<List<Foo>> getFoos() => queue.next();
/// }
///
/// final repo = _RaceRepository();
/// final controller = SomeController(repo: repo);
///
/// unawaited(controller.load());        // call #0 — starts first, slow
/// final second = controller.load();    // call #1 — starts second, fast
/// expect(repo.queue.callCount, 2);
///
/// repo.queue.resolve(1, [newerFoo]);   // #1 (newer) resolves FIRST
/// await second;
/// repo.queue.resolve(0, [olderFoo]);   // #0 (stale) resolves LATE
/// await Future<void>.delayed(Duration.zero); // let the stale .then run
///
/// // A correctly-guarded controller keeps the newer result:
/// expect(controller.items.single, newerFoo);
/// ```
///
/// If the controller under test has no request-generation guard, the stale
/// call (#0) clobbers the newer one and this assertion fails — which is the
/// whole point: the helper must be able to demonstrate the bug, not just
/// the fix.
class CompleterQueue<T> {
  final List<Completer<T>> pending = [];

  int get callCount => pending.length;

  /// Records a new pending call and returns the `Future` it will complete.
  Future<T> next() {
    final completer = Completer<T>();
    pending.add(completer);
    return completer.future;
  }

  /// Resolves the call made at [index] (0 = first call made) with [value].
  void resolve(int index, T value) => pending[index].complete(value);

  /// Resolves the call made at [index] with an error.
  void resolveError(int index, Object error, [StackTrace? stackTrace]) =>
      pending[index].completeError(error, stackTrace);
}
