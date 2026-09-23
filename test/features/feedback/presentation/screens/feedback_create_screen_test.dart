import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:carcare_service/features/feedback/presentation/screens/feedback_create_screen.dart';
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

  testWidgets('submitting an empty message shows a validation error and does not call the repo', (
    tester,
  ) async {
    final repo = FakeFeedbackRepository();
    await pumpAt(tester, FeedbackCreateScreen(repository: repo));

    await tester.tap(find.text('Илгээх'));
    await tester.pumpAndSettle();

    expect(repo.createCalls, 0);
    expect(find.text('Мессеж заавал оруулна уу.'), findsOneWidget);
  });

  testWidgets('a valid submit calls createFeedback with the chosen type', (tester) async {
    Feedback? created;
    final repo = FakeFeedbackRepository();
    await pumpAt(
      tester,
      FeedbackCreateScreen(repository: repo, onCreated: (f) => created = f),
    );

    await tester.tap(find.text('Санал'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Илүү хурдан ачаалуулаарай');
    await tester.tap(find.text('Илгээх'));
    await tester.pumpAndSettle();
    // The success toast schedules a 3s auto-dismiss timer; drain it so the
    // test binding doesn't flag a pending timer at teardown.
    await tester.pump(const Duration(seconds: 4));

    expect(repo.createCalls, 1);
    expect(created?.type, FeedbackType.suggestion);
  });

  testWidgets('renders at 375dp without overflow', (tester) async {
    await pumpAt(tester, FeedbackCreateScreen(repository: FakeFeedbackRepository()));
    expect(tester.takeException(), isNull);
  });
}
