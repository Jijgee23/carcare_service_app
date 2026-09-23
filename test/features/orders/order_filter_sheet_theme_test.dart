import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/features/orders/presentation/screens/order_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('status filter renders only canonical order statuses', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showOrderFilterSheet(context, OrderFilter.empty),
              child: const Text('Нээх'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Нээх'));
    await tester.pumpAndSettle();

    for (final label in [
      'Товлогдсон',
      'Хийгдэж байна',
      'Дууссан',
      'Цуцлагдсан',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('WAITING_PARTS'), findsNothing);
  });

  testWidgets('order filter sheet follows both theme palettes', (tester) async {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          theme: theme,
          themeAnimationDuration: Duration.zero,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () =>
                      showOrderFilterSheet(context, OrderFilter.empty),
                  child: const Text('Нээх'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Нээх'));
      await tester.pumpAndSettle();

      expect(find.text('Шүүлтүүр'), findsOneWidget);
      final heading = tester.widget<Text>(find.text('Шүүлтүүр'));
      expect(heading.style!.color, theme.extension<CarCareTheme>()!.ink);
      expect(tester.takeException(), isNull);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
    }
  });
}
