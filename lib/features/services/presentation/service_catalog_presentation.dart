import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/service_catalog.dart';
import 'package:flutter/material.dart';

/// Presentation-only colors for catalog categories and inventory status.
///
/// The domain enums intentionally carry semantic state only. Keeping these
/// mappings next to the widgets means both light and dark themes use the
/// active Ops Console tokens instead of stale literal colors.
extension ServiceKindPresentation on ServiceKind {
  Color colorFor(BuildContext context) {
    final theme = CarCareTheme.of(context);
    return switch (this) {
      ServiceKind.LABOR => theme.accent,
      ServiceKind.GOODS => theme.ok,
      ServiceKind.DIAGNOSTIC => theme.accentHi,
    };
  }

  Color backgroundFor(BuildContext context) =>
      colorFor(context).withValues(alpha: 0.12);
}

extension StockLevelPresentation on StockLevel {
  Color colorFor(BuildContext context) {
    final theme = CarCareTheme.of(context);
    return switch (this) {
      StockLevel.out => theme.danger,
      StockLevel.low => theme.warn,
      StockLevel.ok => theme.ok,
    };
  }

  Color backgroundFor(BuildContext context) =>
      colorFor(context).withValues(alpha: 0.12);
}
