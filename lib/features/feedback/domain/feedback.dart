/// Feedback domain model — P7-F1 (staff side only, D-176).
///
/// Measured against `carcare.mn` after `P7-B2`:
/// * `app/api/v1/feedback/route.ts` (`GET`/`POST /api/v1/feedback`),
/// * `app/api/v1/feedback/[id]/route.ts` (`GET /api/v1/feedback/[id]`),
/// * `app/api/v1/feedback/[id]/replies/route.ts`
///   (`POST /api/v1/feedback/[id]/replies`),
/// * `lib/feedback-staff.ts` (`FeedbackDto`, `FeedbackMessageDto`).
///
/// D-176: staff can submit, list, view detail and reply — never set status
/// or author as ADMIN. No status endpoint exists, so this model has no
/// mutator for `status`.
library;

class FeedbackParseException implements Exception {
  const FeedbackParseException(this.message);
  final String message;

  @override
  String toString() => 'FeedbackParseException: $message';
}

/// `Feedback.type` — `BUG`/`SUGGESTION`/`OTHER` (Prisma `FeedbackType`).
enum FeedbackType { bug, suggestion, other }

FeedbackType? _feedbackType(Object? value) => switch (value) {
  'BUG' => FeedbackType.bug,
  'SUGGESTION' => FeedbackType.suggestion,
  'OTHER' => FeedbackType.other,
  _ => null,
};

extension FeedbackTypeWire on FeedbackType {
  /// The wire value the server's `isFeedbackType` guard expects.
  String get wire => switch (this) {
    FeedbackType.bug => 'BUG',
    FeedbackType.suggestion => 'SUGGESTION',
    FeedbackType.other => 'OTHER',
  };
}

/// `Feedback.status` — `NEW`/`IN_REVIEW`/`RESOLVED`/`DISMISSED`. Read-only
/// on the staff side: no client method ever sends this.
enum FeedbackStatus { newTicket, inReview, resolved, dismissed, unknown }

FeedbackStatus _feedbackStatus(Object? value) => switch (value) {
  'NEW' => FeedbackStatus.newTicket,
  'IN_REVIEW' => FeedbackStatus.inReview,
  'RESOLVED' => FeedbackStatus.resolved,
  'DISMISSED' => FeedbackStatus.dismissed,
  _ => FeedbackStatus.unknown,
};

/// `FeedbackMessage.author` — `ADMIN`/`SUBMITTER`.
enum FeedbackAuthor { admin, submitter, unknown }

FeedbackAuthor _feedbackAuthor(Object? value) => switch (value) {
  'ADMIN' => FeedbackAuthor.admin,
  'SUBMITTER' => FeedbackAuthor.submitter,
  _ => FeedbackAuthor.unknown,
};

/// `FeedbackDto` — one ticket row, identical shape for list/detail/create
/// responses.
///
/// Only `id` and `type` are structurally required — a row that fails to
/// parse either throws (see `feedback_dto.dart`); everything else degrades.
class Feedback {
  final String id;
  final FeedbackType type;
  final String? message;
  final String? screenshotUrl;
  final String? pageUrl;
  final FeedbackStatus status;
  final String? adminNote;
  final DateTime? resolvedAt;
  final DateTime? createdAt;

  const Feedback({
    required this.id,
    required this.type,
    this.message,
    this.screenshotUrl,
    this.pageUrl,
    this.status = FeedbackStatus.unknown,
    this.adminNote,
    this.resolvedAt,
    this.createdAt,
  });

  factory Feedback.fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final type = _feedbackType(j['type']);
    if (id is! String || id.trim().isEmpty) {
      throw const FeedbackParseException('id талбар буруу байна.');
    }
    if (type == null) {
      throw const FeedbackParseException('type талбар буруу байна.');
    }
    return Feedback(
      id: id.trim(),
      type: type,
      message: _optString(j['message']),
      screenshotUrl: _optString(j['screenshotUrl']),
      pageUrl: _optString(j['pageUrl']),
      status: _feedbackStatus(j['status']),
      adminNote: _optString(j['adminNote']),
      resolvedAt: _optDate(j['resolvedAt']),
      createdAt: _optDate(j['createdAt']),
    );
  }
}

/// `FeedbackMessageDto` — one thread entry.
class FeedbackMessage {
  final String id;
  final FeedbackAuthor author;
  final String? message;
  final DateTime? createdAt;

  const FeedbackMessage({
    required this.id,
    this.author = FeedbackAuthor.unknown,
    this.message,
    this.createdAt,
  });

  factory FeedbackMessage.fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    if (id is! String || id.trim().isEmpty) {
      throw const FeedbackParseException('id талбар буруу байна.');
    }
    return FeedbackMessage(
      id: id.trim(),
      author: _feedbackAuthor(j['author']),
      message: _optString(j['message']),
      createdAt: _optDate(j['createdAt']),
    );
  }
}

/// `GET /api/v1/feedback/[id]` — the ticket plus its full thread.
class FeedbackDetail {
  final Feedback feedback;
  final List<FeedbackMessage> messages;

  const FeedbackDetail({required this.feedback, this.messages = const []});
}

/// `POST /api/v1/feedback/[id]/replies` — the created reply, plus whether
/// it reopened a resolved/dismissed ticket to `IN_REVIEW`.
class FeedbackReplyResult {
  final FeedbackMessage message;
  final bool reopened;

  const FeedbackReplyResult({required this.message, this.reopened = false});
}

// ─── Parse helpers ─────────────────────────────────────────────────────────

String? _optString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _optDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toLocal();
}
