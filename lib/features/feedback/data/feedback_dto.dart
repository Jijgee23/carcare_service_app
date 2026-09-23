/// Envelope parsing for Feedback — P7-F1. Field-level tolerance lives on
/// the domain models (`feedback.dart`); this file only unwraps the
/// top-level response envelopes.
library;

import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/features/feedback/domain/feedback.dart';

typedef JsonMap = Map<String, dynamic>;

JsonMap _map(Object? value, String label) {
  if (value is! Map) throw FeedbackParseException('$label буруу байна.');
  return Map<String, dynamic>.from(value);
}

int _requiredInt(JsonMap json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FeedbackParseException('$key буруу байна.');
}

bool _requiredBool(JsonMap json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FeedbackParseException('$key буруу байна.');
}

PaginationMeta _pagination(Object? raw) {
  final json = _map(raw, 'pagination');
  final page = _requiredInt(json, 'page');
  final pageSize = _requiredInt(json, 'pageSize');
  final total = _requiredInt(json, 'total');
  final totalPages = _requiredInt(json, 'totalPages');
  if (page < 1 || pageSize < 1 || total < 0 || totalPages < 0) {
    throw const FeedbackParseException('Хуудаслалтын мэдээлэл буруу байна.');
  }
  return PaginationMeta(
    page: page,
    pageSize: pageSize,
    total: total,
    totalPages: totalPages,
    hasPrev: _requiredBool(json, 'hasPrev'),
    hasNext: _requiredBool(json, 'hasNext'),
  );
}

/// `GET /api/v1/feedback` — `{feedback:[...], pagination}`.
class FeedbackPageDto {
  const FeedbackPageDto(this.value);
  final PagedResult<Feedback> value;

  factory FeedbackPageDto.fromJson(Object? raw) {
    final json = _map(raw, 'санал хүсэлтийн хариу');
    final list = json['feedback'];
    if (list is! List) {
      throw const FeedbackParseException('Санал хүсэлтийн жагсаалт буруу байна.');
    }
    final items = list
        .whereType<Map>()
        .map((item) => Feedback.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    return FeedbackPageDto(
      PagedResult(items: items, pagination: _pagination(json['pagination'])),
    );
  }
}

/// `GET/POST /api/v1/feedback/[id]`-style detail — `{feedback:{...}}`, and
/// `GET /api/v1/feedback/[id]` additionally has `messages:[...]`.
class FeedbackDto {
  const FeedbackDto(this.value);
  final Feedback value;

  factory FeedbackDto.fromJson(Object? raw) {
    final json = _map(raw, 'feedback хариу');
    return FeedbackDto(Feedback.fromJson(_map(json['feedback'], 'feedback')));
  }
}

/// `GET /api/v1/feedback/[id]` — `{feedback:{...}, messages:[...]}`.
class FeedbackDetailDto {
  const FeedbackDetailDto(this.value);
  final FeedbackDetail value;

  factory FeedbackDetailDto.fromJson(Object? raw) {
    final json = _map(raw, 'feedback дэлгэрэнгүй хариу');
    final rawMessages = json['messages'];
    final messages = rawMessages is List
        ? rawMessages
            .whereType<Map>()
            .map((m) => FeedbackMessage.fromJson(Map<String, dynamic>.from(m)))
            .toList(growable: false)
        : const <FeedbackMessage>[];
    return FeedbackDetailDto(
      FeedbackDetail(
        feedback: Feedback.fromJson(_map(json['feedback'], 'feedback')),
        messages: messages,
      ),
    );
  }
}

/// `POST /api/v1/feedback/[id]/replies` — `{message:{...}, reopened}`.
class FeedbackReplyResultDto {
  const FeedbackReplyResultDto(this.value);
  final FeedbackReplyResult value;

  factory FeedbackReplyResultDto.fromJson(Object? raw) {
    final json = _map(raw, 'хариултын хариу');
    final reopened = json['reopened'];
    return FeedbackReplyResultDto(
      FeedbackReplyResult(
        message: FeedbackMessage.fromJson(_map(json['message'], 'message')),
        reopened: reopened is bool ? reopened : false,
      ),
    );
  }
}
