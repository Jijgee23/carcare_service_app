import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/features/profile/data/account_repository.dart';
import 'package:carcare_service/features/profile/domain/account_repository.dart';
import 'package:carcare_service/features/profile/domain/account_session.dart';
import 'package:carcare_service/core/utils/result.dart';

/// Presentation state for the sessions screen — P8-F3. Copies
/// `FeedbackListController`'s generation-guarded load/loadMore shape for
/// the `ended` (history) list; `active` always comes back in full per
/// [AccountRepository.getSessions] and is never paginated.
class SessionsController extends ChangeNotifier {
  SessionsController({AccountRepository? repo, int? pageSize})
    : _repo = repo ?? RemoteAccountRepository(),
      pageSize = pageSize ?? defaultPageSize;

  static const int defaultPageSize = 20;

  final int pageSize;
  final AccountRepository _repo;

  int _generation = 0;
  bool _disposed = false;

  AsyncValue<List<AccountSession>> activeState = const AsyncLoading();
  List<AccountSession> ended = const [];
  int otherActiveCount = 0;

  bool loadingMore = false;
  AppError? loadMoreError;
  bool _hasNext = false;
  int _page = 1;
  int _total = 0;

  bool get hasNext => _hasNext;
  int get total => _total;

  /// A revoke/revoke-others call is in flight — screens use this to
  /// disable the affected action so a second tap can't double-fire.
  bool actionInFlight = false;

  /// Set when the *current device's own* session was just revoked. The
  /// screen watches this and runs the app's normal logout flow, then clears
  /// it via [acknowledgeLogout].
  bool pendingLogout = false;

  /// Surfaces the most recent action's failure to the screen (revoke /
  /// revoke-others), separate from [activeState]'s load error.
  AppError? actionError;

  List<AccountSession> get active => activeState.valueOrNull ?? const [];

  Future<void> load() async {
    final requestGeneration = ++_generation;
    loadingMore = false;
    loadMoreError = null;
    _page = 1;
    _hasNext = false;
    ended = const [];
    activeState = const AsyncLoading();
    notifyListeners();

    final result = await _repo.getSessions(page: 1, pageSize: pageSize);
    if (_disposed || requestGeneration != _generation) return;
    switch (result) {
      case Ok(:final value):
        _page = value.pagination.page;
        _hasNext = value.pagination.hasNext;
        _total = value.pagination.total;
        ended = value.ended;
        otherActiveCount = value.otherActiveCount;
        activeState = AsyncData(value.active);
      case Err(:final error):
        activeState = AsyncError(error);
    }
    notifyListeners();
  }

  Future<void> refresh() => load();

  Future<void> loadMore() async {
    if (_disposed || loadingMore || !_hasNext) return;
    final requestGeneration = _generation;
    final nextPage = _page + 1;
    loadingMore = true;
    loadMoreError = null;
    notifyListeners();

    final result = await _repo.getSessions(page: nextPage, pageSize: pageSize);
    if (_disposed || requestGeneration != _generation) return;
    switch (result) {
      case Ok(:final value):
        _page = value.pagination.page;
        _hasNext = value.pagination.hasNext;
        _total = value.pagination.total;
        ended = [...ended, ...value.ended];
      case Err(:final error):
        loadMoreError = error;
    }
    loadingMore = false;
    notifyListeners();
  }

  /// Revokes one session. On success, removes it from [active] and, when it
  /// was the caller's own device, sets [pendingLogout] so the screen can run
  /// the app's logout flow. Returns `true` on success.
  Future<bool> revoke(AccountSession session) async {
    if (_disposed || actionInFlight) return false;
    actionInFlight = true;
    actionError = null;
    notifyListeners();

    final result = await _repo.revokeSession(
      session.id,
      source: session.source,
      isCurrent: session.current,
    );
    if (_disposed) return false;
    actionInFlight = false;
    switch (result) {
      case Ok(:final value):
        final nextActive = active.where((s) => s.id != session.id).toList();
        activeState = AsyncData(nextActive);
        otherActiveCount = nextActive.where((s) => !s.current).length;
        if (value.loggedOut) pendingLogout = true;
        notifyListeners();
        return true;
      case Err(:final error):
        actionError = error;
        notifyListeners();
        return false;
    }
  }

  /// Revokes every session but the caller's own. Never triggers a logout
  /// (D-180: the server never revokes the caller's own device this way).
  Future<bool> revokeOthers() async {
    if (_disposed || actionInFlight) return false;
    actionInFlight = true;
    actionError = null;
    notifyListeners();

    final result = await _repo.revokeOtherSessions();
    if (_disposed) return false;
    actionInFlight = false;
    switch (result) {
      case Ok():
        final nextActive = active.where((s) => s.current).toList();
        activeState = AsyncData(nextActive);
        otherActiveCount = 0;
        notifyListeners();
        return true;
      case Err(:final error):
        actionError = error;
        notifyListeners();
        return false;
    }
  }

  void acknowledgeLogout() {
    pendingLogout = false;
  }

  void clearActionError() {
    actionError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
