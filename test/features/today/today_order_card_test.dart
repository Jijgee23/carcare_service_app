import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/today/presentation/widgets/today_order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'today_fixtures.dart';

/// TENANT_UI_UX_PLAN.md fix: the plate must never truncate, even in the
/// ~190dp-wide lane a tablet gets when a detail pane is open at 1280dp
/// (`3 lanes` sharing the list column's ~3/5 share of ~1280*5/7, itself
/// split three ways — see `today_screen_test.dart` for the full-layout math).
void main() {
  Widget harness(Widget child, {required double width}) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );

  testWidgets('a long plate renders in full in a narrow (~190dp) card', (
    tester,
  ) async {
    const plate = '8888УБА1234';
    await tester.pumpWidget(
      harness(
        TodayOrderCard(
          order: todayOrder('w1', plate: plate),
          now: todayNow,
          onTap: () {},
        ),
        width: 190,
      ),
    );
    await tester.pumpAndSettle();

    // Not ellipsized: the exact text is present, just visually scaled down by
    // the plate's own FittedBox rather than clipped by `TextOverflow.ellipsis`.
    expect(find.text(plate), findsOneWidget);
    expect(find.textContaining('…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows service descriptions on the work card', (tester) async {
    await tester.pumpWidget(
      harness(
        TodayOrderCard(
          order: todayOrder(
            'w1',
            servicePreview: const ['Тос солих', 'Дугуй шалгах'],
          ),
          now: todayNow,
          onTap: () {},
        ),
        width: 320,
      ),
    );
    expect(find.text('Тос солих · Дугуй шалгах'), findsOneWidget);
  });

  testWidgets('a long plate also renders in full at a normal 1280dp card width', (
    tester,
  ) async {
    const plate = '8888УБА1234';
    await tester.pumpWidget(
      harness(
        TodayOrderCard(
          order: todayOrder('w1', plate: plate),
          now: todayNow,
          onTap: () {},
        ),
        width: 1280,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(plate), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('in-progress elapsed time formatting', () {
    testWidgets('under an hour shows minutes only', (tester) async {
      await tester.pumpWidget(
        harness(
          TodayOrderCard(
            order: todayOrder(
              'w1',
              status: OrderStatus.IN_PROGRESS,
              startedAt: todayNow.subtract(const Duration(minutes: 45)),
            ),
            now: todayNow,
            onTap: () {},
          ),
          width: 320,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('45 мин'), findsOneWidget);
    });

    testWidgets('under a day shows hours and minutes', (tester) async {
      await tester.pumpWidget(
        harness(
          TodayOrderCard(
            order: todayOrder(
              'w1',
              status: OrderStatus.IN_PROGRESS,
              startedAt: todayNow.subtract(
                const Duration(hours: 3, minutes: 20),
              ),
            ),
            now: todayNow,
            onTap: () {},
          ),
          width: 320,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('3 ц 20 мин'), findsOneWidget);
    });

    testWidgets('over 24h formats as days + hours, not a huge hour count', (
      tester,
    ) async {
      // Regression: an order stuck in IN_PROGRESS for a long time used to
      // render as e.g. "2590 ц 6 мин" instead of a sane "107 хоног 22 ц".
      await tester.pumpWidget(
        harness(
          TodayOrderCard(
            order: todayOrder(
              'w1',
              status: OrderStatus.IN_PROGRESS,
              startedAt: todayNow.subtract(
                const Duration(days: 107, hours: 22, minutes: 6),
              ),
            ),
            now: todayNow,
            onTap: () {},
          ),
          width: 320,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('107 хоног 22 ц'), findsOneWidget);
      expect(find.textContaining('2590 ц'), findsNothing);
    });
  });
}
