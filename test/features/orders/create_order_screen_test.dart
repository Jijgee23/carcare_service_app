import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/features/orders/presentation/screens/create_order_screen.dart';

import '../../fakes/fake_order_repository.dart';
import '../../support/hive_test_setup.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: CreateOrderScreen(repository: FakeOrderRepository()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  setUpAll(openTestHiveBoxes);

  testWidgets('cancelling the duration dialog leaves the duration unset', (
    tester,
  ) async {
    await _pump(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('create_order_duration_row')),
    );
    await tester.tap(find.byKey(const ValueKey('create_order_duration_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('create_order_duration_input')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('create_order_duration_input')),
      '90',
    );
    await tester.tap(find.text('Болих'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('90 мин'), findsNothing);
    expect(find.text('Хугацаа сонгоно уу'), findsOneWidget);
  });

  testWidgets('confirming the duration dialog sets the estimated duration', (
    tester,
  ) async {
    await _pump(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('create_order_duration_row')),
    );
    await tester.tap(find.byKey(const ValueKey('create_order_duration_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.byKey(const ValueKey('create_order_duration_input')),
      '90',
    );
    await tester.tap(find.text('Сонгох'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('90 мин'), findsOneWidget);

    // No lingering "disposed TextEditingController" assertion after the
    // dialog's exit transition finishes — pump past it explicitly.
    await tester.pump(const Duration(milliseconds: 300));
  });
}
