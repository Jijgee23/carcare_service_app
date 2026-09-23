import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/feedback/data/feedback_repository.dart';
import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:carcare_service/features/feedback/domain/feedback_repository.dart';

/// Presentation state for the caller's own tenant's Feedback tickets —
/// P7-F3 (D-176). Copies `EmployeeListController`'s generation-guarded
/// load/loadMore shape; there is no server-side filter contract for
/// feedback beyond pagination, so this controller has no search/filter
/// fields at all — [FeedbackRepository.getFeedbackList] takes only
/// `page`/`pageSize`.
class FeedbackListController extends ChangeNotifier {
  FeedbackListController({FeedbackRepository? repo, int? pageSize})
    : _repo = repo ?? RemoteFeedbackRepository(),
      pageSize = pageSize ?? defaultPageSize;

  static const int defaultPageSize = 20;

  final int pageSize;
  final FeedbackRepository _repo;

  int _generation = 0;
  bool _disposed = false;

  AsyncValue<List<Feedback>> listState = const AsyncLoading();
  bool loadingMore = false;
  AppError? loadMoreError;
  bool _hasNext = false;
  int _page = 1;
  int _total = 0;

  bool get hasNext => _hasNext;
  int get total => _total;
  int get page => _page;

  List<Feedback> get tickets => listState.valueOrNull ?? const <Feedback>[];

  Future<void> loadFeedback() async {
    final requestGeneration = ++_generation;
    loadingMore = false;
    loadMoreError = null;
    _page = 1;
    _hasNext = false;
    listState = const AsyncLoading();
    notifyListeners();

    final result = await _repo.getFeedbackList(
      page: 1,
      pageSize: pageSize,
    );
    if (_disposed || requestGeneration != _generation) return;
    switch (result) {
      case Ok(:final value):
        _page = value.pagination.page;
        _hasNext = value.pagination.hasNext;
        _total = value.pagination.total;
        listState = AsyncData(value.items);
      case Err(:final error):
        listState = AsyncError(error);
    }
    notifyListeners();
  }

  Future<void> refresh() => loadFeedback();

  Future<void> loadMore() async {
    if (_disposed || loadingMore || !_hasNext) return;
    final requestGeneration = _generation;
    final nextPage = _page + 1;
    loadingMore = true;
    loadMoreError = null;
    notifyListeners();

    final result = await _repo.getFeedbackList(
      page: nextPage,
      pageSize: pageSize,
    );
    if (_disposed || requestGeneration != _generation) return;
    switch (result) {
      case Ok(:final value):
        final current = listState.valueOrNull ?? const <Feedback>[];
        _page = value.pagination.page;
        _hasNext = value.pagination.hasNext;
        _total = value.pagination.total;
        listState = AsyncData([...current, ...value.items]);
      case Err(:final error):
        loadMoreError = error;
    }
    loadingMore = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
