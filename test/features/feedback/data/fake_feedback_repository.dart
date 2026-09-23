import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:carcare_service/features/feedback/domain/feedback_repository.dart';

/// Hand-written fake for [FeedbackRepository] — P7-F1, for later widget
/// tests (`P7-F3`). Staff-side only (D-176): no status mutator exists here
/// either.
class FakeFeedbackRepository implements FeedbackRepository {
  FakeFeedbackRepository({List<Feedback>? seed})
    : _tickets = [...(seed ?? [_seedTicket()])];

  final List<Feedback> _tickets;
  final Map<String, List<FeedbackMessage>> _messages = {};
  int _nextId = 2;

  static Feedback _seedTicket({String id = 'f-1'}) => Feedback(
    id: id,
    type: FeedbackType.bug,
    message: 'Анхны алдаа',
    status: FeedbackStatus.newTicket,
    createdAt: DateTime(2026, 9, 20),
  );

  @override
  Future<Result<PagedResult<Feedback>>> getFeedbackList({
    int page = 1,
    int pageSize = 20,
  }) async {
    final total = _tickets.length;
    return Ok(
      PagedResult(
        items: _tickets,
        pagination: PaginationMeta(
          page: page,
          pageSize: pageSize,
          total: total,
          totalPages: (total / pageSize).ceil().clamp(1, 1 << 30),
          hasPrev: page > 1,
          hasNext: false,
        ),
      ),
    );
  }

  @override
  Future<Result<FeedbackDetail>> getFeedback(String id) async {
    final feedback = _tickets.where((f) => f.id == id).firstOrNull;
    if (feedback == null) {
      return const Err(
        AppError(ErrorKind.notFound, 'Олдсонгүй', statusCode: 404, code: 'NOT_FOUND'),
      );
    }
    return Ok(
      FeedbackDetail(feedback: feedback, messages: _messages[id] ?? const []),
    );
  }

  @override
  Future<Result<Feedback>> createFeedback({
    required FeedbackType type,
    required String message,
    String? screenshotPath,
  }) async {
    if (message.length < 5 || message.length > 2000) {
      return const Err(
        AppError(
          ErrorKind.unknown,
          'Мессеж 5-2000 тэмдэгт байх ёстой.',
          statusCode: 422,
          code: 'VALIDATION',
        ),
      );
    }
    final created = Feedback(
      id: 'f-${_nextId++}',
      type: type,
      message: message,
      screenshotUrl: screenshotPath != null ? '/uploads/feedback/mock.png' : null,
      status: FeedbackStatus.newTicket,
      createdAt: DateTime.now(),
    );
    _tickets.insert(0, created);
    return Ok(created);
  }

  @override
  Future<Result<FeedbackReplyResult>> reply(
    String id, {
    required String message,
  }) async {
    final index = _tickets.indexWhere((f) => f.id == id);
    if (index < 0) {
      return const Err(
        AppError(ErrorKind.notFound, 'Олдсонгүй', statusCode: 404, code: 'NOT_FOUND'),
      );
    }
    if (message.trim().length < 2 || message.trim().length > 2000) {
      return const Err(
        AppError(
          ErrorKind.unknown,
          'Хариу 2-2000 тэмдэгт байх ёстой.',
          statusCode: 422,
          code: 'VALIDATION',
        ),
      );
    }
    final current = _tickets[index];
    final reopened =
        current.status == FeedbackStatus.resolved ||
        current.status == FeedbackStatus.dismissed;
    if (reopened) {
      _tickets[index] = Feedback(
        id: current.id,
        type: current.type,
        message: current.message,
        screenshotUrl: current.screenshotUrl,
        pageUrl: current.pageUrl,
        status: FeedbackStatus.inReview,
        adminNote: current.adminNote,
        resolvedAt: null,
        createdAt: current.createdAt,
      );
    }
    final reply = FeedbackMessage(
      id: 'm-${(_messages[id]?.length ?? 0) + 1}',
      author: FeedbackAuthor.submitter,
      message: message.trim(),
      createdAt: DateTime.now(),
    );
    _messages.putIfAbsent(id, () => []).add(reply);
    return Ok(FeedbackReplyResult(message: reply, reopened: reopened));
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
