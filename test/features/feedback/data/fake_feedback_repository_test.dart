import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_feedback_repository.dart';

void main() {
  test('getFeedbackList returns the seeded ticket', () async {
    final repo = FakeFeedbackRepository();
    final result = await repo.getFeedbackList();
    expect((result as Ok).value.items.single.id, 'f-1');
  });

  test('createFeedback rejects a too-short message', () async {
    final repo = FakeFeedbackRepository();
    final result = await repo.createFeedback(type: FeedbackType.bug, message: 'a');
    expect((result as Err).error.code, 'VALIDATION');
  });

  test('reply to an unknown id is NOT_FOUND', () async {
    final repo = FakeFeedbackRepository();
    final result = await repo.reply('missing', message: 'ok reply');
    expect((result as Err).error.code, 'NOT_FOUND');
  });

  test('reply never sets author to ADMIN — always SUBMITTER', () async {
    final repo = FakeFeedbackRepository();
    final result = await repo.reply('f-1', message: 'Нэмэлт тайлбар');
    final value = (result as Ok).value;
    expect(value.message.author, FeedbackAuthor.submitter);
    expect(value.reopened, isFalse);
  });
}
