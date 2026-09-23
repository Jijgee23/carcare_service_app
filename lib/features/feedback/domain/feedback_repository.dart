import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/feedback/domain/feedback.dart';

/// One frozen repository contract for the Feedback feature — P7-F1
/// (staff side only, D-176: submit, list, detail, reply — never status or
/// an ADMIN-authored message).
///
/// Errors a caller must expect:
/// * `400` — bad multipart body (create).
/// * `401` — no code, auth required only.
/// * `404 NOT_FOUND` — no row for this tenant (detail, reply).
/// * `422 VALIDATION` — message length/type validation, carries no
///   `fieldErrors` (the server returns a single flat message for this
///   route, unlike Employees/Schedules).
abstract interface class FeedbackRepository {
  /// `GET /api/v1/feedback` — the caller's own tenant's tickets, newest
  /// first.
  Future<Result<PagedResult<Feedback>>> getFeedbackList({
    int page = 1,
    int pageSize = 20,
  });

  /// `GET /api/v1/feedback/[id]` — with its full reply thread. Tenant
  /// scoped: another tenant's id is `404 NOT_FOUND`, never a cross-tenant
  /// leak.
  Future<Result<FeedbackDetail>> getFeedback(String id);

  /// `POST /api/v1/feedback` — multipart: `type`, `message`, an optional
  /// `screenshot` file path (2MB, PNG/JPG/WEBP/SVG — `lib/storage.ts`'s
  /// existing limits; violating them is a server-side 422, this method does
  /// not pre-validate the file locally).
  Future<Result<Feedback>> createFeedback({
    required FeedbackType type,
    required String message,
    String? screenshotPath,
  });

  /// `POST /api/v1/feedback/[id]/replies` — author is always `SUBMITTER`;
  /// this method has no way to send `ADMIN` or a `status`, matching the
  /// route's contract. Replying to a `RESOLVED`/`DISMISSED` ticket reopens
  /// it to `IN_REVIEW` server-side — [FeedbackReplyResult.reopened] reports
  /// that back so the caller can refresh its status display.
  Future<Result<FeedbackReplyResult>> reply(String id, {required String message});
}
