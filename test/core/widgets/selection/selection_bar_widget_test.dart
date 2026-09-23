import 'package:carcare_service/core/widgets/selection/selection_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  group('SelectionActionBar', () {
    testWidgets('shows the count and invokes actions/clear', (tester) async {
      var cleared = false;
      var pressedRole = false;
      await pump(
        tester,
        SelectionActionBar(
          count: 3,
          onClear: () => cleared = true,
          actions: [
            SelectionAction(
              label: 'Үүрэг',
              icon: Icons.badge_outlined,
              onPressed: () => pressedRole = true,
            ),
          ],
        ),
      );

      expect(find.text('3 сонгосон'), findsOneWidget);
      await tester.tap(find.text('Үүрэг'));
      expect(pressedRole, isTrue);

      await tester.tap(find.byKey(const ValueKey('selection_bar_clear')));
      expect(cleared, isTrue);
    });

    testWidgets('busy disables clear and action buttons', (tester) async {
      var pressed = false;
      await pump(
        tester,
        SelectionActionBar(
          count: 1,
          busy: true,
          onClear: () {},
          actions: [
            SelectionAction(
              label: 'Салбар',
              icon: Icons.store_outlined,
              onPressed: () => pressed = true,
            ),
          ],
        ),
      );

      final clearButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('selection_bar_clear')),
      );
      expect(clearButton.onPressed, isNull);

      final actionButton = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(actionButton.onPressed, isNull);
      expect(pressed, isFalse);
    });
  });

  group('SelectionResultBanner', () {
    testWidgets('shows success/failure counts and per-row errors', (
      tester,
    ) async {
      await pump(
        tester,
        const SelectionResultBanner(
          succeeded: 2,
          failed: 1,
          errors: ['u-9: Эзэмшигчийг өөрчлөх боломжгүй.'],
        ),
      );

      expect(find.text('2 амжилттай, 1 амжилтгүй'), findsOneWidget);
      expect(
        find.text('• u-9: Эзэмшигчийг өөрчлөх боломжгүй.'),
        findsOneWidget,
      );
    });
  });

  group('SelectableListTile', () {
    testWidgets('shows a checkbox only in selection mode and toggles on tap', (
      tester,
    ) async {
      var tapped = 0;
      await pump(
        tester,
        SelectableListTile(
          selected: false,
          selectionMode: false,
          onTap: () => tapped++,
          onLongPress: () {},
          child: const Text('Row'),
        ),
      );
      expect(find.byType(Checkbox), findsNothing);

      await pump(
        tester,
        SelectableListTile(
          selected: true,
          selectionMode: true,
          onTap: () => tapped++,
          onLongPress: () {},
          child: const Text('Row'),
        ),
      );
      expect(find.byType(Checkbox), findsOneWidget);
      await tester.tap(find.text('Row'));
      expect(tapped, 1);
    });
  });
}
