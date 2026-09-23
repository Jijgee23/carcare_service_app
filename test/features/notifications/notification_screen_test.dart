import 'package:carcare_service/features/notifications/presentation/screens/notification_screen.dart';
import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_notification_repository.dart';

void main() {
  testWidgets('renders injected notifications without touching the API', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationScreen(repository: FakeNotificationRepository()),
      ),
    );
    await tester.pump();

    expect(find.text('Мэдэгдэл'), findsOneWidget);
    expect(find.text('Мэдэгдэл n-1'), findsOneWidget);
    expect(find.text('Бүгдийг уншсан'), findsOneWidget);
  });

  testWidgets('uses the same screen at tablet width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationScreen(repository: FakeNotificationRepository()),
      ),
    );
    await tester.pump();
    expect(find.text('Мэдэгдэл n-2'), findsOneWidget);
  });

  testWidgets('notification text uses the active light and dark tokens', (
    tester,
  ) async {
    Color? lightTitle;
    Color? darkTitle;

    for (final (theme, capture) in [
      (AppTheme.light, (Color color) => lightTitle = color),
      (AppTheme.dark, (Color color) => darkTitle = color),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          themeAnimationDuration: Duration.zero,
          home: NotificationScreen(repository: FakeNotificationRepository()),
        ),
      );
      await tester.pump();

      final title = tester.widget<Text>(find.text('Мэдэгдэл n-1'));
      capture(title.style!.color!);
      expect(title.style!.color, theme.extension<CarCareTheme>()!.ink);
    }

    expect(lightTitle, isNot(darkTitle));
  });
}
