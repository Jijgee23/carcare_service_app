import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:carcare_service/features/feedback/domain/feedback_repository.dart';

/// Hand-written fake for [FeedbackRepository] — P7-F3 presentation tests
/// (staff side only, D-176: submit/list/detail/reply, never status or an
/// ADMIN-authored message).
class FakeFeedbackRepository implements FeedbackRepository {
  FakeFeedbackRepository({List<Feedback>? seed})
    : _tickets = [...(seed ?? [seedFeedback()])];

  final List<Feedback> _tickets;
  final Map<String, List<FeedbackMessage>> _messages = {};

  int listCalls = 0;
  int createCalls = 0;
  int replyCalls = 0;
  Result<Feedback>? createResult;
  Result<FeedbackReplyResult>? replyResult;
  Result<FeedbackDetail>? detailResult;

  static Feedback seedFeedback({
    String id = 'f-1',
    FeedbackType type = FeedbackType.bug,
    String? message = 'Апп унтарч байна',
    FeedbackStatus status = FeedbackStatus.newTicket,
    DateTime? createdAt,
  }) => Feedback(
    id: id,
    type: type,
    message: message,
    status: status,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );

  AppError _notFound() => const AppError(
    ErrorKind.notFound,
    'Санал хүсэлт олдсонгүй.',
    statusCode: 404,
    code: 'NOT_FOUND',
  );

  @override
  Future<Result<PagedResult<Feedback>>> getFeedbackList({
    int page = 1,
    int pageSize = 20,
  }) async {
    listCalls++;
    final total = _tickets.length;
    final totalPages = (total / pageSize).ceil().clamp(1, 1 << 30);
    final p = page.clamp(1, totalPages);
    final skip = (p - 1) * pageSize;
    final items = _tickets.skip(skip).take(pageSize).toList(growable: false);
    return Ok(
      PagedResult(
        items: items,
        pagination: PaginationMeta(
          page: p,
          pageSize: pageSize,
          total: total,
          totalPages: totalPages,
          hasPrev: p > 1,
          hasNext: p < totalPages,
        ),
      ),
    );
  }

  @override
  Future<Result<FeedbackDetail>> getFeedback(String id) async {
    if (detailResult != null) return detailResult!;
    final ticket = _tickets.where((t) => t.id == id).firstOrNull;
    if (ticket == null) return Err(_notFound());
    return Ok(FeedbackDetail(feedback: ticket, messages: _messages[id] ?? const []));
  }

  @override
  Future<Result<Feedback>> createFeedback({
    required FeedbackType type,
    required String message,
    String? screenshotPath,
  }) async {
    createCalls++;
    if (createResult != null) return createResult!;
    final created = Feedback(
      id: 'f-${_tickets.length + 1}',
      type: type,
      message: message,
      screenshotUrl: screenshotPath == null ? null : 'https://example.test/shot.png',
      status: FeedbackStatus.newTicket,
      createdAt: DateTime(2026, 1, 2),
    );
    _tickets.add(created);
    return Ok(created);
  }

  @override
  Future<Result<FeedbackReplyResult>> reply(String id, {required String message}) async {
    replyCalls++;
    if (replyResult != null) return replyResult!;
    final index = _tickets.indexWhere((t) => t.id == id);
    if (index < 0) return Err(_notFound());
    final current = _tickets[index];
    final wasClosed = current.status == FeedbackStatus.resolved ||
        current.status == FeedbackStatus.dismissed;
    final reply = FeedbackMessage(
      id: 'm-${(_messages[id]?.length ?? 0) + 1}',
      author: FeedbackAuthor.submitter,
      message: message,
      createdAt: DateTime(2026, 1, 3),
    );
    _messages.putIfAbsent(id, () => []).add(reply);
    if (wasClosed) {
      _tickets[index] = Feedback(
        id: current.id,
        type: current.type,
        message: current.message,
        screenshotUrl: current.screenshotUrl,
        pageUrl: current.pageUrl,
        status: FeedbackStatus.inReview,
        adminNote: current.adminNote,
        resolvedAt: current.resolvedAt,
        createdAt: current.createdAt,
      );
    }
    return Ok(FeedbackReplyResult(message: reply, reopened: wasClosed));
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
