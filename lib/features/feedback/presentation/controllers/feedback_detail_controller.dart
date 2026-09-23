import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/feedback/data/feedback_repository.dart';
import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:carcare_service/features/feedback/domain/feedback_repository.dart';

/// Detail + reply thread for one ticket — P7-F3 (D-176). Generation-guarded
/// like every other controller here, so a reply that lands after the
/// screen has already moved to a different ticket never clobbers state.
///
/// [FeedbackRepository.reply]'s `reopened` flag is surfaced through
/// [lastReplyReopened] rather than re-derived from the refreshed status —
/// the server is authoritative about what "reopened" means, this class just
/// relays it for the screen to toast.
class FeedbackDetailController extends ChangeNotifier {
  FeedbackDetailController({required this.feedbackId, FeedbackRepository? repo})
    : _repo = repo ?? RemoteFeedbackRepository();

  final String feedbackId;
  final FeedbackRepository _repo;

  int _generation = 0;
  bool _disposed = false;

  AsyncValue<FeedbackDetail> detailState = const AsyncLoading();
  bool replying = false;
  AppError? replyError;
  bool lastReplyReopened = false;

  Future<void> load() async {
    final requestGeneration = ++_generation;
    detailState = const AsyncLoading();
    notifyListeners();

    final result = await _repo.getFeedback(feedbackId);
    if (_disposed || requestGeneration != _generation) return;
    switch (result) {
      case Ok(:final value):
        detailState = AsyncData(value);
      case Err(:final error):
        detailState = AsyncError(error);
    }
    notifyListeners();
  }

  Future<void> refresh() => load();

  Future<Result<FeedbackReplyResult>> reply(String message) async {
    final trimmed = message.trim();
    replying = true;
    replyError = null;
    notifyListeners();

    final result = await _repo.reply(feedbackId, message: trimmed);
    if (_disposed) return result;
    switch (result) {
      case Ok(:final value):
        lastReplyReopened = value.reopened;
        await load();
      case Err(:final error):
        replyError = error;
    }
    replying = false;
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
