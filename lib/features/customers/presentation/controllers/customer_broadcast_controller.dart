import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/customers/data/customer_repository.dart';
import 'package:carcare_service/features/customers/domain/customer.dart';
import 'package:carcare_service/features/customers/domain/customers_repository.dart';

/// Owns the recipient-count preview and the send action for the customer
/// broadcast surface — P3-F7.
///
/// Follows the generation-guard convention from `CustomerDetailController`:
/// every request is stamped with a monotonic [_generation] so a stale
/// in-flight response (e.g. a `refresh()` fired while an earlier count load
/// is still pending) can never clobber a newer one or write into a disposed
/// controller.
///
/// [send] additionally guards against a *second kind* of staleness that the
/// read-only loads never faced: overlap. A broadcast is a one-shot mutating
/// call to a real push endpoint with no idempotency key, so — unlike
/// `refresh()` racing itself — a second `send()` while one is in flight must
/// never reach the network. [sending] is checked and set synchronously
/// before the first `await`, so two near-simultaneous calls (e.g. a
/// double-tap the UI's own disabled-button state didn't catch in time)
/// cannot both pass the guard.
class CustomerBroadcastController extends ChangeNotifier {
  CustomerBroadcastController({CustomersRepository? repo})
    : _repo = repo ?? RemoteCustomersRepository();

  final CustomersRepository _repo;

  int _generation = 0;
  bool _disposed = false;

  AsyncValue<int> recipientCountState = const AsyncLoading();

  /// True from the moment [send] accepts a call until its result (success or
  /// failure) has been applied. The confirm UI must disable its button on
  /// this flag, but the flag itself — not the UI — is what actually stops a
  /// second in-flight request.
  bool sending = false;

  AppError? lastError;
  Map<String, String> fieldErrors = const {};

  int? get recipientCount => recipientCountState.valueOrNull;

  /// The documented server wart: a send with zero recipients still consumes
  /// the tenant's daily broadcast allowance. The UI must treat a zero count
  /// as a dead end, not just a low number — this getter is the single place
  /// that decides it.
  bool get canSend => (recipientCount ?? 0) > 0 && !sending;

  Future<void> loadRecipientCount() async {
    final generation = ++_generation;
    recipientCountState = const AsyncLoading();
    notifyListeners();
    final result = await _repo.getBroadcastRecipientCount();
    if (_disposed || generation != _generation) return;
    switch (result) {
      case Ok(:final value):
        recipientCountState = AsyncData(value);
      case Err(:final error):
        recipientCountState = AsyncError(error);
    }
    notifyListeners();
  }

  Future<void> refresh() => loadRecipientCount();

  /// Sends the broadcast. Returns `null` without touching the network if a
  /// send is already in flight or the controller is disposed — callers that
  /// only check the return value (rather than [sending]) still cannot
  /// double-fire.
  Future<Result<CustomerBroadcastResult>?> send({
    required String title,
    required String body,
  }) async {
    if (_disposed || sending) return null;
    sending = true;
    lastError = null;
    fieldErrors = const {};
    notifyListeners();
    final result = await _repo.sendBroadcast(title: title, body: body);
    if (_disposed) return result;
    sending = false;
    switch (result) {
      case Ok():
        break;
      case Err(:final error):
        lastError = error;
        fieldErrors = error.fieldErrors ?? const {};
    }
    notifyListeners();
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
