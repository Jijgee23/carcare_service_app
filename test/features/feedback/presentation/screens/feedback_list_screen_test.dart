import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:carcare_service/features/feedback/presentation/screens/feedback_list_screen.dart';
import 'package:flutter/material.dart' hide Feedback;
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_feedback_repository.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('no permission gate: any authenticated user sees the list', (tester) async {
    await pumpAt(
      tester,
      FeedbackListScreen(
        repository: FakeFeedbackRepository(
          seed: [FakeFeedbackRepository.seedFeedback(id: 'f-1')],
        ),
      ),
    );
    expect(find.text('Санал хүсэлт'), findsOneWidget);
  });

  testWidgets('status badges render per ticket', (tester) async {
    await pumpAt(
      tester,
      FeedbackListScreen(
        repository: FakeFeedbackRepository(
          seed: [
            FakeFeedbackRepository.seedFeedback(id: 'f-1', status: FeedbackStatus.newTicket),
            FakeFeedbackRepository.seedFeedback(id: 'f-2', status: FeedbackStatus.inReview),
            FakeFeedbackRepository.seedFeedback(id: 'f-3', status: FeedbackStatus.resolved),
            FakeFeedbackRepository.seedFeedback(id: 'f-4', status: FeedbackStatus.dismissed),
          ],
        ),
      ),
    );
    expect(find.text('Шинэ'), findsOneWidget);
    expect(find.text('Хянагдаж байна'), findsOneWidget);
    expect(find.text('Шийдэгдсэн'), findsOneWidget);
    expect(find.text('Хаагдсан'), findsOneWidget);
  });

  testWidgets('renders at 375dp without overflow', (tester) async {
    await pumpAt(
      tester,
      FeedbackListScreen(
        repository: FakeFeedbackRepository(
          seed: List.generate(
            4,
            (i) => FakeFeedbackRepository.seedFeedback(
              id: 'f-$i',
              message: 'Урт мессежийн жишээ бичвэр энд байна маш их урт байж болно',
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a ticket invokes onTapTicket', (tester) async {
    Feedback? tapped;
    await pumpAt(
      tester,
      FeedbackListScreen(
        repository: FakeFeedbackRepository(
          seed: [FakeFeedbackRepository.seedFeedback(id: 'f-1')],
        ),
        onTapTicket: (f) => tapped = f,
      ),
    );
    await tester.tap(find.text('Алдаа'));
    expect(tapped?.id, 'f-1');
  });

  testWidgets('create FAB only renders with the onCreate hook', (tester) async {
    await pumpAt(
      tester,
      FeedbackListScreen(repository: FakeFeedbackRepository()),
    );
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('empty tenant shows the empty state', (tester) async {
    await pumpAt(
      tester,
      FeedbackListScreen(repository: FakeFeedbackRepository(seed: const [])),
    );
    expect(find.text('Санал хүсэлт бүртгэгдээгүй байна'), findsOneWidget);
  });
}
