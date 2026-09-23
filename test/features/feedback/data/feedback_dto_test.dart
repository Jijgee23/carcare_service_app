import 'package:carcare_service/features/feedback/data/feedback_dto.dart';
import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:flutter_test/flutter_test.dart';

const _pagination = {
  'page': 1,
  'pageSize': 20,
  'total': 1,
  'totalPages': 1,
  'hasPrev': false,
  'hasNext': false,
};

void main() {
  group('FeedbackPageDto.fromJson', () {
    test('unwraps items and pagination', () {
      final dto = FeedbackPageDto.fromJson({
        'feedback': [
          {'id': 'f-1', 'type': 'BUG'},
        ],
        'pagination': _pagination,
      });
      expect(dto.value.items.single.id, 'f-1');
      expect(dto.value.pagination.total, 1);
    });

    test('a non-list feedback key throws FeedbackParseException', () {
      expect(
        () => FeedbackPageDto.fromJson({'feedback': 'nope', 'pagination': _pagination}),
        throwsA(isA<FeedbackParseException>()),
      );
    });
  });

  group('FeedbackDto.fromJson', () {
    test('unwraps a single feedback envelope', () {
      final dto = FeedbackDto.fromJson({
        'feedback': {'id': 'f-1', 'type': 'SUGGESTION'},
      });
      expect(dto.value.type, FeedbackType.suggestion);
    });
  });

  group('FeedbackDetailDto.fromJson', () {
    test('unwraps feedback and messages together', () {
      final dto = FeedbackDetailDto.fromJson({
        'feedback': {'id': 'f-1', 'type': 'BUG'},
        'messages': [
          {'id': 'm-1', 'author': 'SUBMITTER'},
        ],
      });
      expect(dto.value.feedback.id, 'f-1');
      expect(dto.value.messages.single.id, 'm-1');
    });

    test('missing messages degrades to an empty list', () {
      final dto = FeedbackDetailDto.fromJson({
        'feedback': {'id': 'f-1', 'type': 'BUG'},
      });
      expect(dto.value.messages, isEmpty);
    });
  });

  group('FeedbackReplyResultDto.fromJson', () {
    test('unwraps message and reopened', () {
      final dto = FeedbackReplyResultDto.fromJson({
        'message': {'id': 'm-1', 'author': 'SUBMITTER'},
        'reopened': true,
      });
      expect(dto.value.message.id, 'm-1');
      expect(dto.value.reopened, isTrue);
    });

    test('a missing reopened key defaults to false', () {
      final dto = FeedbackReplyResultDto.fromJson({
        'message': {'id': 'm-1', 'author': 'SUBMITTER'},
      });
      expect(dto.value.reopened, isFalse);
    });
  });
}
