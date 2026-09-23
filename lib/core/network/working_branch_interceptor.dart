import 'dart:async';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:carcare_service/core/domain/working_branch_scope.dart';

typedef WorkingBranchInvalidationListener = FutureOr<void> Function();

/// Process-local signal shared by the network layer and the shell controller.
/// Concurrent calls are coalesced into one notification/refetch.
class WorkingBranchInvalidationBus {
  WorkingBranchInvalidationBus();

  static final instance = WorkingBranchInvalidationBus();

  final _listeners = <WorkingBranchInvalidationListener>{};
  bool _signalling = false;

  void addListener(WorkingBranchInvalidationListener listener) =>
      _listeners.add(listener);

  void removeListener(WorkingBranchInvalidationListener listener) =>
      _listeners.remove(listener);

  Future<void> signal() async {
    if (_signalling) return;
    _signalling = true;
    try {
      for (final listener in List.of(_listeners)) {
        await listener();
      }
    } finally {
      _signalling = false;
    }
  }
}

/// Persistence boundary for the working-branch override.
///
/// The interceptor deliberately depends on this small boundary rather than on
/// [Hive] directly. This keeps request tests deterministic and leaves the
/// storage implementation replaceable without changing networking code.
abstract interface class WorkingBranchSelectionStore {
  Future<String?> read();

  Future<void> write(String? selection);

  Future<void> clear() => write(null);
}

/// Stores the override in the device box opened by [DeviceService] during app
/// startup. A missing/corrupt value is treated as no override.
class HiveWorkingBranchSelectionStore implements WorkingBranchSelectionStore {
  static const boxName = 'device';
  static const key = 'working_branch';

  final Box<dynamic> Function() _box;

  HiveWorkingBranchSelectionStore({Box<dynamic> Function()? box})
    : _box = box ?? (() => Hive.box<dynamic>(boxName));

  @override
  Future<String?> read() async {
    try {
      final value = _box().get(key);
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (_) {
      // Storage is best-effort. The server's absent-header fallback remains
      // safer than blocking every request if the local box is unavailable.
      return null;
    }
  }

  @override
  Future<void> write(String? selection) async {
    try {
      final box = _box();
      final trimmed = selection?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        await box.delete(key);
      } else {
        await box.put(key, trimmed);
      }
    } catch (_) {
      // A network request must not fail only because local persistence did.
    }
  }

  @override
  Future<void> clear() => write(null);
}

/// Adds the selected working branch to every request and invalidates a stale
/// selection after the server rejects it.
///
/// A rejected branch request is passed through unchanged. In particular, this
/// interceptor never retries a 403: retrying with the same header would loop,
/// and retrying without it could silently change the server-side scope.
class WorkingBranchInterceptor extends Interceptor {
  final WorkingBranchSelectionStore _store;
  final WorkingBranchInvalidationListener onInvalidBranch;

  // Prevents concurrent 403 responses carrying the same stale value from
  // producing duplicate reload/invalidation notifications.
  String? _lastInvalidatedSelection;

  WorkingBranchInterceptor({
    WorkingBranchSelectionStore? store,
    WorkingBranchInvalidationListener? onInvalidBranch,
  }) : _store = store ?? HiveWorkingBranchSelectionStore(),
       onInvalidBranch =
           onInvalidBranch ?? WorkingBranchInvalidationBus.instance.signal;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final selection = await _store.read();
    final normalized = _normalize(selection);

    // A changed selection starts a fresh invalidation cycle. This also lets a
    // user choose a different valid branch after a stale one was cleared.
    // Keep the marker while the stale value is being cleared. In particular,
    // a second in-flight 403 must not become a second signal merely because
    // the first handler has already removed the persisted value.
    if (normalized != null && normalized != _lastInvalidatedSelection) {
      _lastInvalidatedSelection = null;
    }

    _removeWorkingBranchHeaders(options.headers);
    if (normalized != null) {
      options.headers['X-Working-Branch'] = normalized;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final header = _headerValue(err.requestOptions.headers);
    final invalidMarker = err.response?.headers
        .value('X-Working-Branch-Invalid')
        ?.trim();
    if (status == 403 &&
        header != null &&
        header.isNotEmpty &&
        invalidMarker == '1') {
      if (_lastInvalidatedSelection != header) {
        // Set the guard before awaiting either operation, so simultaneous
        // responses cannot both emit the signal.
        _lastInvalidatedSelection = header;
        await _store.clear();
        try {
          await onInvalidBranch();
        } catch (_) {
          // A refresh listener is not allowed to swallow the original 403.
        }
      }
    }

    // Deliberately reject/pass through the original error. There is no retry.
    handler.next(err);
  }

  static String? _normalize(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _headerValue(Map headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() != 'x-working-branch') continue;
      final raw = entry.value;
      final value = (raw is Iterable && raw.isNotEmpty ? raw.first : raw)
          ?.toString()
          .trim();
      return value == null || value.isEmpty ? null : value;
    }
    return null;
  }

  static void _removeWorkingBranchHeaders(Map<String, dynamic> headers) {
    headers.removeWhere((key, _) => key.toLowerCase() == 'x-working-branch');
  }
}
