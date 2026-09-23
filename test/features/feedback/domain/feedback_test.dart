import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Feedback.fromJson', () {
    test('parses a full ticket row', () {
      final feedback = Feedback.fromJson({
        'id': 'f-1',
        'type': 'BUG',
        'message': 'Алдаа гарлаа',
        'screenshotUrl': '/uploads/feedback/1.png',
        'pageUrl': '/dashboard',
        'status': 'IN_REVIEW',
        'adminNote': null,
        'resolvedAt': null,
        'createdAt': '2026-09-20T00:00:00.000Z',
      });
      expect(feedback.id, 'f-1');
      expect(feedback.type, FeedbackType.bug);
      expect(feedback.status, FeedbackStatus.inReview);
      expect(feedback.resolvedAt, isNull);
    });

    test('a missing id throws FeedbackParseException', () {
      expect(
        () => Feedback.fromJson({'type': 'BUG'}),
        throwsA(isA<FeedbackParseException>()),
      );
    });

    test('a missing/unknown type throws FeedbackParseException', () {
      expect(
        () => Feedback.fromJson({'id': 'f-1'}),
        throwsA(isA<FeedbackParseException>()),
      );
      expect(
        () => Feedback.fromJson({'id': 'f-1', 'type': 'NOT_A_TYPE'}),
        throwsA(isA<FeedbackParseException>()),
      );
    });

    test('an unrecognized status degrades to unknown, not a throw', () {
      final feedback = Feedback.fromJson({
        'id': 'f-1',
        'type': 'OTHER',
        'status': 'SOMETHING_NEW',
      });
      expect(feedback.status, FeedbackStatus.unknown);
    });
  });

  group('FeedbackTypeWire', () {
    test('round-trips the three wire values', () {
      expect(FeedbackType.bug.wire, 'BUG');
      expect(FeedbackType.suggestion.wire, 'SUGGESTION');
      expect(FeedbackType.other.wire, 'OTHER');
    });
  });

  group('FeedbackMessage.fromJson', () {
    test('parses author and message', () {
      final message = FeedbackMessage.fromJson({
        'id': 'm-1',
        'author': 'SUBMITTER',
        'message': 'Нэмэлт мэдээлэл',
        'createdAt': '2026-09-20T00:00:00.000Z',
      });
      expect(message.author, FeedbackAuthor.submitter);
      expect(message.message, 'Нэмэлт мэдээлэл');
    });

    test('a missing id throws FeedbackParseException', () {
      expect(
        () => FeedbackMessage.fromJson({'author': 'ADMIN'}),
        throwsA(isA<FeedbackParseException>()),
      );
    });
  });
}
