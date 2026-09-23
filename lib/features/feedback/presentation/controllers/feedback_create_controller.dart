import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/feedback/data/feedback_repository.dart';
import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:carcare_service/features/feedback/domain/feedback_repository.dart';

/// The screen-level validation this controller enforces before ever calling
/// the server — matches the server's own 422 for an empty/whitespace-only
/// message (`lib/feedback-staff.ts` validation, measured at P7-B2), so a
/// caller gets the same complaint instantly instead of round-tripping.
class FeedbackCreateValidation {
  const FeedbackCreateValidation({this.message});
  final String? message;
  bool get isValid => message == null;
}

/// Create-ticket submission — P7-F3 (D-176). Screenshot is optional; when
/// given it is a local file path handed straight to
/// [FeedbackRepository.createFeedback], which multiparts it. This
/// controller never inspects the file itself (size/type limits are
/// `lib/storage.ts`'s server-side job, per that method's doc comment).
class FeedbackCreateController extends ChangeNotifier {
  FeedbackCreateController({FeedbackRepository? repo})
    : _repo = repo ?? RemoteFeedbackRepository();

  final FeedbackRepository _repo;
  bool submitting = false;

  static const int minMessageLength = 3;

  FeedbackCreateValidation validate(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return const FeedbackCreateValidation(message: 'Мессеж заавал оруулна уу.');
    }
    if (trimmed.length < minMessageLength) {
      return const FeedbackCreateValidation(
        message: 'Мессеж хэт богино байна.',
      );
    }
    return const FeedbackCreateValidation();
  }

  Future<Result<Feedback>> submit({
    required FeedbackType type,
    required String message,
    String? screenshotPath,
  }) async {
    submitting = true;
    notifyListeners();
    final result = await _repo.createFeedback(
      type: type,
      message: message.trim(),
      screenshotPath: screenshotPath,
    );
    submitting = false;
    notifyListeners();
    return result;
  }
}
