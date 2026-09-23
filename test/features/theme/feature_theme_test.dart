import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/diagnostic.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/presentation/feature_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _StatusColors = ({
  Color orderForeground,
  Color orderBackground,
  Color diagnosticForeground,
  Color diagnosticBackground,
});

void main() {
  testWidgets('service and diagnostic status colors follow brightness', (
    tester,
  ) async {
    final values = <Brightness, _StatusColors>{};

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      late _StatusColors captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          themeAnimationDuration: Duration.zero,
          home: Builder(
            builder: (context) {
              captured = (
                orderForeground: context.orderStatusColor(
                  OrderStatus.SCHEDULED,
                ),
                orderBackground: context.orderStatusBackground(
                  OrderStatus.SCHEDULED,
                ),
                diagnosticForeground: context.diagnosticTypeColor(
                  DiagnosticType.INTAKE,
                ),
                diagnosticBackground: context.diagnosticTypeBackground(
                  DiagnosticType.INTAKE,
                ),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();
      values[theme.brightness] = captured;
    }

    final light = values[Brightness.light]!;
    final dark = values[Brightness.dark]!;
    final lightTokens = AppTheme.light.extension<CarCareTheme>()!;
    final darkTokens = AppTheme.dark.extension<CarCareTheme>()!;

    expect(light.orderForeground, lightTokens.warn);
    expect(dark.orderForeground, darkTokens.warn);
    expect(light.orderBackground, lightTokens.warn.withOpacity(0.12));
    expect(dark.orderBackground, darkTokens.warn.withOpacity(0.12));
    expect(light.diagnosticForeground, lightTokens.accent);
    expect(dark.diagnosticForeground, darkTokens.accent);
    expect(light.diagnosticBackground, lightTokens.accent.withOpacity(0.12));
    expect(dark.diagnosticBackground, darkTokens.accent.withOpacity(0.12));

    expect(light.orderForeground, isNot(dark.orderForeground));
    expect(light.orderBackground, isNot(dark.orderBackground));
    expect(light.diagnosticForeground, isNot(dark.diagnosticForeground));
    expect(light.diagnosticBackground, isNot(dark.diagnosticBackground));
  });
}
