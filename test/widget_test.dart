import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/presentation/controllers/inspection_controller.dart';
import 'package:carcare_service/features/presentation/pages/analytics/analytics_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('analytics renders the upgraded chart for each date range', (
    tester,
  ) async {
    // Keep the chart visible without Firebase or backend initialization.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => InspectionController(),
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AnalyticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final range in {'7 хоног': 7, '1 сар': 30, '3 сар': 90}.entries) {
      await tester.tap(find.text(range.key).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups, hasLength(range.value));
      expect(
        chart.data.barGroups.every((group) => group.barRods.single.toY == 0),
        isTrue,
      );
    }
  });
}
