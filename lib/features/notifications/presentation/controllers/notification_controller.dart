import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/notifications/data/notification_repository.dart';
import 'package:carcare_service/features/notifications/domain/notification_item.dart';
import 'package:carcare_service/features/notifications/domain/notifications_repository.dart';
import 'package:flutter/material.dart';

class NotificationController extends ChangeNotifier {
  NotificationController({NotificationsRepository? repo})
    : _repo = repo ?? NotificationRepository();

  final NotificationsRepository _repo;

  AsyncValue<List<NotificationItem>> listState = const AsyncLoading();
  int unreadCount = 0;
  PaginationMeta? _meta;
  bool _loadingMore = false;
  int _loadRequestId = 0;

  bool get hasMore => _meta?.hasNext ?? false;
  bool get loadingMore => _loadingMore;

  /// Every full load gets a generation. A response from an older generation
  /// is ignored, including its error, so a slow refresh cannot overwrite a
  /// newer reload triggered by a mutation or push.
  Future<void> load() async {
    final requestId = ++_loadRequestId;
    _meta = null;
    _loadingMore = false;
    listState = const AsyncLoading();
    notifyListeners();

    Result<NotificationPage> result;
    try {
      result = await _repo.getList(page: 1);
    } catch (_) {
      result = const Err(
        AppError(ErrorKind.unknown, 'Мэдэгдэл ачаалж чадсангүй'),
      );
    }
    if (requestId != _loadRequestId) return;

    switch (result) {
      case Ok(:final value):
        final items = value.items.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        listState = AsyncData(items);
        _meta = value.pagination;
        unreadCount = value.unreadCount;
      case Err(:final error):
        listState = AsyncError(error);
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !hasMore) return;
    final requestId = _loadRequestId;
    final current = listState.valueOrNull?.toList() ?? <NotificationItem>[];
    final nextPage = (_meta?.page ?? 1) + 1;
    _loadingMore = true;
    notifyListeners();

    Result<NotificationPage> result;
    try {
      result = await _repo.getList(page: nextPage);
    } catch (_) {
      result = const Err(
        AppError(ErrorKind.unknown, 'Мэдэгдэл ачаалж чадсангүй'),
      );
    }
    if (requestId != _loadRequestId) return;

    _loadingMore = false;
    if (result case Ok(:final value)) {
      final appended = [...current, ...value.items];
      appended.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      listState = AsyncData(appended);
      _meta = value.pagination;
      unreadCount = value.unreadCount;
    }
    notifyListeners();
  }

  /// The API is authoritative after a mutation. Reloading instead of
  /// applying a local optimistic edit keeps unread counts and pagination
  /// correct when another device changed the inbox.
  Future<void> markRead(String id) async {
    try {
      await _repo.markRead(id);
      await load();
    } catch (_) {
      // Best effort, matching the existing app behaviour.
    }
  }

  Future<void> markAllRead() async {
    try {
      await _repo.markAllRead();
      await load();
    } catch (_) {
      // Best effort, matching the existing app behaviour.
    }
  }

  /// Push notifications are persisted by the server. Reload the inbox so a
  /// foreground push and a simultaneous manual refresh obey the same guard.
  Future<void> handleIncomingPush({
    String? title,
    String? body,
    Map<String, dynamic> data = const {},
  }) async {
    await load();
  }

  void reset() {
    ++_loadRequestId;
    _meta = null;
    _loadingMore = false;
    unreadCount = 0;
    listState = const AsyncLoading();
    notifyListeners();
  }

  @override
  void dispose() {
    ++_loadRequestId;
    super.dispose();
  }
}
