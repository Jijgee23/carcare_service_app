import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:carcare_service/features/feedback/presentation/controllers/feedback_create_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_feedback_repository.dart';

void main() {
  group('FeedbackCreateController', () {
    test('validate rejects an empty message', () {
      final c = FeedbackCreateController(repo: FakeFeedbackRepository());
      final v = c.validate('   ');
      expect(v.isValid, isFalse);
      expect(v.message, isNotNull);
    });

    test('validate rejects a too-short message', () {
      final c = FeedbackCreateController(repo: FakeFeedbackRepository());
      final v = c.validate('hi');
      expect(v.isValid, isFalse);
    });

    test('validate accepts a real message', () {
      final c = FeedbackCreateController(repo: FakeFeedbackRepository());
      final v = c.validate('Апп нээгдэхгүй байна');
      expect(v.isValid, isTrue);
      expect(v.message, isNull);
    });

    test('submit posts type/message/screenshot and returns the created ticket', () async {
      final repo = FakeFeedbackRepository();
      final c = FeedbackCreateController(repo: repo);

      final result = await c.submit(
        type: FeedbackType.suggestion,
        message: 'Илүү хурдан ачаалуулаарай',
        screenshotPath: '/tmp/shot.png',
      );

      expect(repo.createCalls, 1);
      switch (result) {
        case Ok(:final value):
          expect(value.type, FeedbackType.suggestion);
          expect(value.screenshotUrl, isNotNull);
        case Err():
          fail('expected Ok');
      }
    });

    test('submit surfaces a server error without throwing', () async {
      final repo = FakeFeedbackRepository();
      repo.createResult = const Err(
        AppError(ErrorKind.unknown, 'Мессеж хэт урт байна', statusCode: 422, code: 'VALIDATION'),
      );
      final c = FeedbackCreateController(repo: repo);

      final result = await c.submit(type: FeedbackType.bug, message: 'Алдаа гарлаа');
      expect(result, isA<Err<Feedback>>());
      expect(c.submitting, isFalse);
    });
  });
}
