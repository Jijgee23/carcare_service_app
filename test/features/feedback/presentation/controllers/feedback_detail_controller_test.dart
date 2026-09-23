import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:carcare_service/features/feedback/presentation/controllers/feedback_detail_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_feedback_repository.dart';

void main() {
  group('FeedbackDetailController', () {
    test('load populates the ticket and its thread', () async {
      final repo = FakeFeedbackRepository(
        seed: [FakeFeedbackRepository.seedFeedback(id: 'f-1')],
      );
      final c = FeedbackDetailController(feedbackId: 'f-1', repo: repo);
      await c.load();

      expect(c.detailState.valueOrNull?.feedback.id, 'f-1');
      expect(c.detailState.valueOrNull?.messages, isEmpty);
    });

    test('reply appends to the thread and refreshes the ticket', () async {
      final repo = FakeFeedbackRepository(
        seed: [FakeFeedbackRepository.seedFeedback(id: 'f-1')],
      );
      final c = FeedbackDetailController(feedbackId: 'f-1', repo: repo);
      await c.load();

      final result = await c.reply('Дахин хэзээ гарах вэ?');
      expect(result, isA<Ok<FeedbackReplyResult>>());
      expect(c.detailState.valueOrNull?.messages, hasLength(1));
      expect(c.replying, isFalse);
    });

    test('replying to a resolved ticket reports reopened and updates status', () async {
      final repo = FakeFeedbackRepository(
        seed: [
          FakeFeedbackRepository.seedFeedback(id: 'f-1', status: FeedbackStatus.resolved),
        ],
      );
      final c = FeedbackDetailController(feedbackId: 'f-1', repo: repo);
      await c.load();

      final result = await c.reply('Асуудал дахин гарлаа');
      expect(c.lastReplyReopened, isTrue);
      switch (result) {
        case Ok(:final value):
          expect(value.reopened, isTrue);
        case Err():
          fail('expected Ok');
      }
      expect(c.detailState.valueOrNull?.feedback.status, FeedbackStatus.inReview);
    });

    test('a reply error surfaces via replyError without clearing the thread', () async {
      final repo = FakeFeedbackRepository(
        seed: [FakeFeedbackRepository.seedFeedback(id: 'f-1')],
      );
      repo.replyResult = const Err(
        AppError(ErrorKind.unknown, 'Хариу илгээж чадсангүй', statusCode: 422),
      );
      final c = FeedbackDetailController(feedbackId: 'f-1', repo: repo);
      await c.load();

      final result = await c.reply('Сайн байна уу');
      expect(result, isA<Err<FeedbackReplyResult>>());
      expect(c.replyError, isNotNull);
      expect(c.detailState.valueOrNull?.messages, isEmpty);
    });

    test('load on a missing ticket surfaces AsyncError', () async {
      final repo = FakeFeedbackRepository(seed: const []);
      final c = FeedbackDetailController(feedbackId: 'missing', repo: repo);
      await c.load();
      expect(c.detailState.valueOrNull, isNull);
    });
  });
}
