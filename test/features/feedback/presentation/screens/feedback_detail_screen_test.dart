import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:carcare_service/features/feedback/presentation/screens/feedback_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_feedback_repository.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the ticket and its thread', (tester) async {
    final repo = FakeFeedbackRepository(
      seed: [FakeFeedbackRepository.seedFeedback(id: 'f-1', message: 'Апп унтарч байна')],
    );
    await pumpAt(tester, FeedbackDetailScreen(feedbackId: 'f-1', repository: repo));

    expect(find.text('Апп унтарч байна'), findsOneWidget);
    expect(find.text('Хариу байхгүй байна'), findsOneWidget);
  });

  testWidgets('no status controls render anywhere on this screen', (tester) async {
    final repo = FakeFeedbackRepository(
      seed: [FakeFeedbackRepository.seedFeedback(id: 'f-1')],
    );
    await pumpAt(tester, FeedbackDetailScreen(feedbackId: 'f-1', repository: repo));

    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.textContaining('Шийдэгдсэн болгох'), findsNothing);
  });

  testWidgets('sending a reply appends it to the thread', (tester) async {
    final repo = FakeFeedbackRepository(
      seed: [FakeFeedbackRepository.seedFeedback(id: 'f-1')],
    );
    await pumpAt(tester, FeedbackDetailScreen(feedbackId: 'f-1', repository: repo));

    await tester.enterText(find.byType(TextField), 'Сайн уу, шалгаж байна уу?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Сайн уу, шалгаж байна уу?'), findsOneWidget);
    expect(repo.replyCalls, 1);
  });

  testWidgets('replying to a resolved ticket shows the reopened state', (tester) async {
    final repo = FakeFeedbackRepository(
      seed: [
        FakeFeedbackRepository.seedFeedback(id: 'f-1', status: FeedbackStatus.resolved),
      ],
    );
    await pumpAt(tester, FeedbackDetailScreen(feedbackId: 'f-1', repository: repo));
    expect(find.text('Шийдэгдсэн'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Асуудал дахин гарлаа');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    // The reopened toast schedules a 3s auto-dismiss timer; drain it so the
    // test binding doesn't flag a pending timer at teardown.
    await tester.pump(const Duration(seconds: 4));

    expect(find.text('Хянагдаж байна'), findsOneWidget);
    expect(find.text('Шийдэгдсэн'), findsNothing);
  });

  testWidgets('renders at 375dp without overflow', (tester) async {
    final repo = FakeFeedbackRepository(
      seed: [
        FakeFeedbackRepository.seedFeedback(
          id: 'f-1',
          message: 'Урт мессежийн жишээ бичвэр энд байна маш их урт байж болно давхар',
        ),
      ],
    );
    await pumpAt(tester, FeedbackDetailScreen(feedbackId: 'f-1', repository: repo));
    expect(tester.takeException(), isNull);
  });
}
