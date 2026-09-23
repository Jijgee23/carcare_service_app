import 'package:carcare_service/features/feedback/presentation/controllers/feedback_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_feedback_repository.dart';

void main() {
  group('FeedbackListController', () {
    test('loadFeedback populates tickets and total', () async {
      final repo = FakeFeedbackRepository(
        seed: [
          FakeFeedbackRepository.seedFeedback(id: 'f-1'),
          FakeFeedbackRepository.seedFeedback(id: 'f-2'),
        ],
      );
      final c = FeedbackListController(repo: repo);
      await c.loadFeedback();

      expect(c.tickets.length, 2);
      expect(c.total, 2);
    });

    test('loadMore appends the next page', () async {
      final seed = List.generate(3, (i) => FakeFeedbackRepository.seedFeedback(id: 'f-$i'));
      final repo = FakeFeedbackRepository(seed: seed);
      final c = FeedbackListController(repo: repo, pageSize: 2);
      await c.loadFeedback();
      expect(c.tickets.length, 2);
      expect(c.hasNext, isTrue);

      await c.loadMore();
      expect(c.tickets.length, 3);
      expect(c.hasNext, isFalse);
    });

    test('an empty tenant surfaces an empty list, not an error', () async {
      final repo = FakeFeedbackRepository(seed: const []);
      final c = FeedbackListController(repo: repo);
      await c.loadFeedback();
      expect(c.tickets, isEmpty);
      expect(c.total, 0);
    });
  });
}
