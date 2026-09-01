import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/models/notification_item.dart';
import 'package:carcare_service/features/models/pagination.dart';
import 'package:carcare_service/features/presentation/data/repository/notification_repository.dart';
import 'package:flutter/material.dart';

class NotificationController extends ChangeNotifier {
  NotificationController({NotificationRepository? repo})
      : _repo = repo ?? NotificationRepository();

  final NotificationRepository _repo;

  AsyncValue<List<NotificationItem>> listState = const AsyncLoading();
  int unreadCount = 0;
  PaginationMeta? _meta;
  bool _loadingMore = false;

  bool get hasMore => _meta != null && _meta!.hasNext;
  bool get loadingMore => _loadingMore;

  Future<void> load() async {
    listState = const AsyncLoading();
    _meta = null;
    notifyListeners();
    final result = await _repo.getList(page: 1);
    switch (result) {
      case Ok(:final value):
        listState = AsyncData(value.items);
        _meta = value.pagination;
        unreadCount = value.unreadCount;
      case Err(:final error):
        listState = AsyncError(error);
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !hasMore) return;
    final current = listState.valueOrNull ?? [];
    final nextPage = (_meta?.page ?? 1) + 1;
    _loadingMore = true;
    notifyListeners();
    final result = await _repo.getList(page: nextPage);
    _loadingMore = false;
    if (result case Ok(:final value)) {
      listState = AsyncData([...current, ...value.items]);
      _meta = value.pagination;
      unreadCount = value.unreadCount;
    }
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    try {
      await _repo.markRead(id);
      final current = listState.valueOrNull ?? [];
      listState = AsyncData(
        current.map((n) => n.id == id ? _markReadLocal(n) : n).toList(),
      );
      if (unreadCount > 0) unreadCount--;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _repo.markAllRead();
      final current = listState.valueOrNull ?? [];
      listState = AsyncData(current.map(_markReadLocal).toList());
      unreadCount = 0;
      notifyListeners();
    } catch (_) {}
  }

  NotificationItem _markReadLocal(NotificationItem n) => NotificationItem(
        id: n.id,
        type: n.type,
        title: n.title,
        body: n.body,
        data: n.data,
        readAt: n.readAt ?? DateTime.now(),
        createdAt: n.createdAt,
      );
}
